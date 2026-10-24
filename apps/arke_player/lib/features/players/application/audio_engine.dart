import 'dart:async';

import 'package:arke_library/arke_library.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../settings/domain/device_settings.dart';
import 'listening_plan.dart';

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
class AudioEngine extends BaseAudioHandler with SeekHandler {
  AudioEngine() {
    _player.playbackEventStream.listen((_) => _broadcast(), onError: (Object _) => _broadcast());
    _player.playingStream.listen((_) => _broadcast());
    _player.positionStream.listen(_onPosition);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _keepPlace(finished: true);
    });
  }

  final _player = AudioPlayer();

  LibraryItem? _item;
  ListeningPlan? _plan;
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
  Stream<Duration> get position => _player.positionStream.map(_book);
  Stream<bool> get playingStream => _player.playingStream;
  bool get playing => _player.playing;
  Duration get now => _book(_player.position);
  Duration get length => _plan?.document.duration ?? _player.duration ?? _item?.duration ?? Duration.zero;
  double get speed => _player.speed;
  SleepTimer get sleep => _sleep;

  /// The player's own position, on the book's clock.
  Duration _book(Duration local) {
    final plan = _plan;
    if (plan == null) return local;
    final index = (_player.currentIndex ?? 0).clamp(0, plan.starts.length - 1);
    return plan.starts[index] + local;
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
    _keep = keep;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
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
    artwork.value = null;
    await super.stop();
  }

  /// Seeks to [position] on the book's clock.
  @override
  Future<void> seek(Duration position) {
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
  @override
  Future<void> skipToPrevious() async {
    final chapters = _item?.chapters ?? const [];
    if (chapters.length < 2) return seek(Duration.zero);
    final at = now;
    final index = chapterAt(at);
    final startOfThis = chapters[index].start;
    await seek(at - startOfThis < const Duration(seconds: 3) && index > 0 ? chapters[index - 1].start : startOfThis);
  }

  @override
  Future<void> skipToNext() async {
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
    if (item == null || keep == null) return;
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
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [1, 2, 3],
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
