import 'dart:async';

import 'package:arke_library/arke_library.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../settings/domain/device_settings.dart';

/// Plays an audio file with the phone's media session around it: the lock screen, a headset's
/// buttons and the notification drive it, and it keeps playing with the screen locked (docs/mvp.md
/// acceptance 4; ADR 0004). Skip back and forward move by 15 and 30 seconds (Studio 186); previous
/// and next move by the file's chapters.
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
  void Function(Place place, {bool? finished})? _keep;
  SleepTimer _sleep = SleepTimer.off;
  Timer? _sleepTimer;
  int? _sleepChapter;
  DateTime _lastKept = DateTime.fromMillisecondsSinceEpoch(0);

  LibraryItem? get item => _item;
  Stream<Duration> get position => _player.positionStream;
  Stream<bool> get playingStream => _player.playingStream;
  bool get playing => _player.playing;
  Duration get now => _player.position;
  Duration get length => _player.duration ?? _item?.duration ?? Duration.zero;
  double get speed => _player.speed;
  SleepTimer get sleep => _sleep;

  /// Opens [item] at its kept place (else the start) and plays it.
  Future<void> open(
    LibraryItem item, {
    required String path,
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
    _keep = keep;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    mediaItem.add(
      MediaItem(
        id: item.id,
        title: item.title,
        artist: item.author,
        album: item.author,
        duration: item.duration,
        artUri: artPath == null ? null : Uri.file(artPath),
      ),
    );
    final start = item.finished ? Duration.zero : (item.place?.position ?? Duration.zero);
    await _player.setFilePath(path, initialPosition: start);
    await _player.setSpeed(speed);
    await play();
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
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> rewind() => _player.seek(_clamp(_player.position - const Duration(seconds: 15)));

  @override
  Future<void> fastForward() => _player.seek(_clamp(_player.position + const Duration(seconds: 30)));

  /// Previous: the start of this chapter, or the one before when within its first three seconds.
  @override
  Future<void> skipToPrevious() async {
    final chapters = _item?.chapters ?? const [];
    if (chapters.length < 2) return _player.seek(Duration.zero);
    final index = chapterAt(_player.position);
    final startOfThis = chapters[index].start;
    final target = _player.position - startOfThis < const Duration(seconds: 3) && index > 0 ? chapters[index - 1].start : startOfThis;
    await _player.seek(target);
  }

  @override
  Future<void> skipToNext() async {
    final chapters = _item?.chapters ?? const [];
    final index = chapterAt(_player.position);
    if (chapters.length < 2 || index + 1 >= chapters.length) return;
    await _player.seek(chapters[index + 1].start);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed.clamp(0.8, 2.0));

  /// The sleep choice (P5c): end of chapter stops at the chapter's end, a time stops after it.
  void setSleep(SleepTimer sleep) {
    _sleep = sleep;
    _sleepTimer?.cancel();
    _sleepChapter = null;
    if (sleep.after != null) _sleepTimer = Timer(sleep.after!, pause);
    if (sleep == SleepTimer.endOfChapter) _sleepChapter = chapterAt(_player.position);
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

  void _onPosition(Duration position) {
    if (_sleepChapter != null && chapterAt(position) != _sleepChapter) {
      _sleepChapter = null;
      _sleep = SleepTimer.off;
      pause();
    }
    if (DateTime.now().difference(_lastKept) > const Duration(seconds: 5)) _keepPlace();
  }

  Future<void> _keepPlace({bool finished = false}) async {
    final item = _item;
    final keep = _keep;
    if (item == null || keep == null) return;
    _lastKept = DateTime.now();
    final total = length.inMilliseconds;
    final position = finished ? length : _player.position;
    keep(
      Place(position: position, progress: total == 0 ? 0 : (position.inMilliseconds / total).clamp(0, 1), updatedAt: DateTime.now().toUtc()),
      finished: finished,
    );
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
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }
}
