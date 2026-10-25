import 'dart:async';

import 'package:arke_library/arke_library.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../settings/domain/device_settings.dart';
import 'listening_plan.dart';
import 'music.dart';

/// Plays an audio file with the phone's media session around it: the lock screen, a headset's
/// buttons and the notification drive it, and it keeps playing with the screen locked (docs/mvp.md
/// acceptance 4; ADR 0004). Skip back and forward move by 15 and 30 seconds (Studio 186); previous
/// and next move by the file's chapters.
///
/// An illustrated narration (SPEC-058 R-26) is a file a chapter. The engine plays them as one queue
/// but speaks only the book's clock — the chapters back to back, as the item's chapters are — so
/// seeking, skipping, sleep and the scrubber are the same for both. Its place is kept by chapter
/// and offset, which a later edition of the world can still find, and the lock screen's artwork
/// follows the picture of the moment (R-27).
///
/// A world's music (SPEC-058 R-75, P17d) is an album played as one queue too, on the album's clock,
/// with shuffle and repeat; previous and next move by tracks, the lock screen names the track and its
/// album, and a song keeps no place (P17 call 20).
class AudioEngine extends BaseAudioHandler with SeekHandler {
  AudioEngine() {
    _player.playbackEventStream.listen((_) => _broadcast(), onError: (Object _) => _broadcast());
    _player.playingStream.listen((_) => _broadcast());
    _player.positionStream.listen(_onPosition);
    _player.currentIndexStream.listen((_) => _announceTrack());
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _keepPlace(finished: true);
    });
  }

  final _player = AudioPlayer();

  LibraryItem? _item;
  ListeningPlan? _plan;
  MusicAlbum? _music;
  MusicRepeat _repeat = MusicRepeat.off;
  void Function(Place place, {bool? finished})? _keep;
  SleepTimer _sleep = SleepTimer.off;
  Timer? _sleepTimer;
  int? _sleepChapter;
  DateTime _lastKept = DateTime.fromMillisecondsSinceEpoch(0);

  /// The picture the lock screen and the dock show: the cover, or an illustrated narration's
  /// picture of the moment.
  final artwork = ValueNotifier<String?>(null);

  LibraryItem? get item => _item;
  ListeningPlan? get plan => _plan;

  /// The album playing, when what plays is a world's music.
  MusicAlbum? get music => _music;

  /// The track playing, by its place in the album.
  int get track => (_player.currentIndex ?? 0).clamp(0, (_music?.tracks.length ?? 1) - 1);
  Stream<int?> get trackStream => _player.currentIndexStream;
  bool get shuffling => _player.shuffleModeEnabled;
  Stream<bool> get shuffleStream => _player.shuffleModeEnabledStream;
  MusicRepeat get repeat => _repeat;
  Stream<LoopMode> get repeatStream => _player.loopModeStream;
  Stream<Duration> get position => _player.positionStream.map(_book);
  Stream<bool> get playingStream => _player.playingStream;
  bool get playing => _player.playing;
  Duration get now => _book(_player.position);
  Duration get length => _music?.length ?? _plan?.document.duration ?? _player.duration ?? _item?.duration ?? Duration.zero;
  double get speed => _player.speed;
  SleepTimer get sleep => _sleep;

  /// The player's own position, on the book's clock, or the album's.
  Duration _book(Duration local) {
    final starts = _music?.starts ?? _plan?.starts;
    if (starts == null) return local;
    final index = (_player.currentIndex ?? 0).clamp(0, starts.length - 1);
    return starts[index] + local;
  }

  /// Plays [album] from the start of track [index], back to back with no gap of the Player's own: the
  /// Studio's export rendered the album's gaps and crossfades into its files (SPEC-060 R-16). With
  /// [shuffle] true it plays in a new shuffled order from that order's first track, false in order
  /// (Play all), and null as it was (a track pressed). Nothing is kept: a song keeps no place and
  /// starts from its beginning (P17 call 20).
  Future<void> openMusic(MusicAlbum album, {int index = 0, bool? shuffle}) async {
    if (_music?.id == album.id && shuffle == null) {
      await _player.seek(Duration.zero, index: index);
      _announceTrack();
      await play();
      return;
    }
    await _keepPlace();
    _music = album;
    _plan = null;
    _keep = null;
    _item = album.asItem;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _player.setLoopMode(_loopOf(_repeat));
    await _player.setShuffleModeEnabled(false);
    await _player.setAudioSources([for (var i = 0; i < album.tracks.length; i++) AudioSource.file(album.trackPath(i))], initialIndex: index);
    if (shuffle ?? false) {
      await _player.setShuffleModeEnabled(true);
      await _player.shuffle();
      final first = _player.effectiveIndices.firstOrNull;
      if (first != null) await _player.seek(Duration.zero, index: first);
    }
    _announceTrack();
    await _player.setSpeed(1);
    await play();
  }

  /// Shuffle on or off for the album playing (P17d).
  Future<void> toggleShuffle() async {
    if (_music == null) return;
    final on = !_player.shuffleModeEnabled;
    if (on) await _player.shuffle();
    await _player.setShuffleModeEnabled(on);
    _broadcast();
  }

  /// Repeat's next state: off, the album, the one track.
  Future<void> cycleRepeat() async {
    _repeat = _repeat.next;
    await _player.setLoopMode(_loopOf(_repeat));
    _broadcast();
  }

  static LoopMode _loopOf(MusicRepeat mode) => switch (mode) {
    MusicRepeat.off => LoopMode.off,
    MusicRepeat.all => LoopMode.all,
    MusicRepeat.one => LoopMode.one,
  };

  /// The lock screen and the dock name the track and its album (R-75).
  void _announceTrack() {
    final album = _music;
    if (album == null) return;
    final track = album.tracks[this.track];
    artwork.value = album.cover;
    mediaItem.add(
      MediaItem(
        id: '${album.id}#${track.id}',
        title: track.title,
        album: album.title,
        artist: album.worldName,
        duration: track.duration,
        artUri: album.cover == null ? null : Uri.file(album.cover!),
      ),
    );
  }

  /// Opens [item] at its kept place (else the start) and plays it. An illustrated narration comes
  /// with its [plan]; a file with its [path].
  Future<void> open(
    LibraryItem item, {
    String? path,
    ListeningPlan? plan,
    String? artPath,
    required double speed,
    required void Function(Place place, {bool? finished}) keep,
  }) async {
    if (_item?.id == item.id) {
      if (!_player.playing) await play();
      return;
    }
    await _keepPlace();
    _item = item;
    _plan = plan;
    _music = null;
    _keep = keep;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // An album's shuffle and repeat are its own: a book plays in order, once.
    await _player.setShuffleModeEnabled(false);
    await _player.setLoopMode(LoopMode.off);
    final place = item.finished ? null : item.place;
    if (plan != null) {
      final (index, offset) = plan.locate(plan.timeOf(place?.locator, place?.position ?? Duration.zero));
      final art = plan.shownAt(plan.starts[index] + offset)?.path ?? artPath;
      _announce(item, art);
      await _player.setAudioSources(
        [for (final (i, chapter) in plan.chapters.indexed) AudioSource.file(plan.pathIn(i, chapter.audio))],
        initialIndex: index,
        initialPosition: offset,
      );
    } else {
      _announce(item, artPath);
      await _player.setFilePath(path!, initialPosition: place?.position ?? Duration.zero);
    }
    await _player.setSpeed(speed);
    await play();
  }

  void _announce(LibraryItem item, String? art) {
    artwork.value = art;
    mediaItem.add(
      MediaItem(id: item.id, title: item.title, artist: item.author, album: item.author, duration: length, artUri: art == null ? null : Uri.file(art)),
    );
  }

  @override
  Future<void> play() async {
    if (await AudioSession.instance.then((session) => session.setActive(true))) unawaited(_player.play());
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await _keepPlace();
  }

  @override
  Future<void> stop() async {
    await _keepPlace();
    await _player.stop();
    _item = null;
    _plan = null;
    _music = null;
    artwork.value = null;
    await super.stop();
  }

  /// Seeks to [position] on the book's clock, or the album's.
  @override
  Future<void> seek(Duration position) {
    if (_music case final album?) {
      final (index, offset) = album.locate(position);
      return _player.seek(offset, index: index);
    }
    final plan = _plan;
    if (plan == null) return _player.seek(position);
    final (index, offset) = plan.locate(position);
    return _player.seek(offset, index: index);
  }

  @override
  Future<void> rewind() => seek(_clamp(now - const Duration(seconds: 15)));

  @override
  Future<void> fastForward() => seek(_clamp(now + const Duration(seconds: 30)));

  /// Previous: the start of this chapter, or the one before when within its first three seconds.
  /// An album's goes by its tracks in the order they play, shuffled or not.
  @override
  Future<void> skipToPrevious() async {
    if (_music != null) {
      final into = _player.position;
      if (into > const Duration(seconds: 3) || !_player.hasPrevious) return _player.seek(Duration.zero);
      return _player.seekToPrevious();
    }
    final chapters = _item?.chapters ?? const [];
    if (chapters.length < 2) return seek(Duration.zero);
    final at = now;
    final index = chapterAt(at);
    final startOfThis = chapters[index].start;
    await seek(at - startOfThis < const Duration(seconds: 3) && index > 0 ? chapters[index - 1].start : startOfThis);
  }

  @override
  Future<void> skipToNext() async {
    if (_music != null) {
      if (_player.hasNext) await _player.seekToNext();
      return;
    }
    final chapters = _item?.chapters ?? const [];
    final index = chapterAt(now);
    if (chapters.length < 2 || index + 1 >= chapters.length) return;
    await seek(chapters[index + 1].start);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed.clamp(0.8, 2.0));

  /// The sleep choice (P5c): end of chapter stops at the chapter's end, a time stops after it.
  void setSleep(SleepTimer sleep) {
    _sleep = sleep;
    _sleepTimer?.cancel();
    _sleepChapter = null;
    if (sleep.after != null) _sleepTimer = Timer(sleep.after!, pause);
    if (sleep == SleepTimer.endOfChapter) _sleepChapter = chapterAt(now);
  }

  /// The chapter playing at [position]: the last whose start has passed.
  int chapterAt(Duration position) {
    final chapters = _item?.chapters ?? const [];
    final index = chapters.lastIndexWhere((chapter) => chapter.start <= position);
    return index < 0 ? 0 : index;
  }

  /// Where the chapter playing at [position] starts and ends.
  (Duration start, Duration end) chapterBounds(Duration position) {
    final chapters = _item?.chapters ?? const [];
    if (chapters.length < 2) return (Duration.zero, length);
    final index = chapterAt(position);
    return (chapters[index].start, index + 1 < chapters.length ? chapters[index + 1].start : length);
  }

  Duration _clamp(Duration position) => position < Duration.zero ? Duration.zero : (position > length ? length : position);

  void _onPosition(Duration local) {
    final position = _book(local);
    if (_sleepChapter != null && chapterAt(position) != _sleepChapter) {
      _sleepChapter = null;
      _sleep = SleepTimer.off;
      pause();
    }
    final plan = _plan;
    if (plan != null) {
      final art = plan.shownAt(position)?.path;
      if (art != null && art != artwork.value) {
        artwork.value = art;
        final current = mediaItem.value;
        if (current != null) mediaItem.add(current.copyWith(artUri: Uri.file(art)));
      }
    }
    if (DateTime.now().difference(_lastKept) > const Duration(seconds: 5)) _keepPlace();
  }

  Future<void> _keepPlace({bool finished = false}) async {
    final item = _item;
    final keep = _keep;
    // A song keeps no place (P17 call 20).
    if (item == null || keep == null || _music != null) return;
    _lastKept = DateTime.now();
    final total = length.inMilliseconds;
    final position = finished ? length : now;
    final progress = total == 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
    final plan = _plan;
    if (plan != null) {
      final (index, offset) = plan.locate(position);
      keep(
        Place(locator: plan.chapters[index].id, position: offset, progress: progress, updatedAt: DateTime.now().toUtc()),
        finished: finished,
      );
    } else {
      keep(
        Place(position: position, progress: progress, updatedAt: DateTime.now().toUtc()),
        finished: finished,
      );
    }
  }

  void _broadcast() {
    final playing = _player.playing;
    final music = _music != null;
    playbackState.add(
      playbackState.value.copyWith(
        // A song moves by tracks: Next where a chapter has back and forward (R-75).
        controls: [
          MediaControl.skipToPrevious,
          if (!music) MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          if (!music) MediaControl.fastForward,
          MediaControl.skipToNext,
        ],
        systemActions: music ? const {MediaAction.seek} : const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: music ? const [0, 1, 2] : const [1, 2, 3],
        shuffleMode: music && _player.shuffleModeEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
        repeatMode: switch (_repeat) {
          _ when !music => AudioServiceRepeatMode.none,
          MusicRepeat.off => AudioServiceRepeatMode.none,
          MusicRepeat.all => AudioServiceRepeatMode.all,
          MusicRepeat.one => AudioServiceRepeatMode.one,
        },
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: now,
        bufferedPosition: _book(_player.bufferedPosition),
        speed: _player.speed,
      ),
    );
  }
}
