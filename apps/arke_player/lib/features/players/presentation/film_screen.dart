import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/theme/tokens.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/device_settings.dart';
import '../application/players.dart';
import 'chrome.dart';

const _fg = ArkeColors.mediaOverlayForeground;

/// A film in the film player (P3a held upright, P3b turned, P3e captions). The picture is the page:
/// letterboxed, never cropped, on the overlay colours. The chrome is type and icons over two
/// scrims; it rests after 2.5 s while playing and never while paused (Studio 156). The scrubber
/// runs across the whole film, since a film has a length (P3 rule 2).
class FilmScreen extends ConsumerStatefulWidget {
  const FilmScreen({required this.item, required this.store, super.key});

  final LibraryItem item;
  final LibraryStore store;

  @override
  ConsumerState<FilmScreen> createState() => _FilmScreenState();
}

class _FilmScreenState extends ConsumerState<FilmScreen> {
  late final VideoPlayerController _video;
  bool _ready = false;
  bool _failed = false;
  bool _chrome = true;
  bool _fullScreen = false;
  Timer? _rest;
  DateTime _lastKept = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final captions = widget.item.captions;
    _video = VideoPlayerController.file(
      File(widget.store.resolve(widget.item.file)),
      closedCaptionFile: captions == null ? null : _loadCaptions(widget.store.resolve(captions)),
    );
    _video.addListener(_onTick);
    _video.initialize().then((_) async {
      final kept = widget.item.finished ? null : widget.item.place?.position;
      if (kept != null) await _video.seekTo(kept);
      await _video.play();
      await WakelockPlus.enable();
      if (mounted) setState(() => _ready = true);
      _scheduleRest();
    }, onError: (Object _) => mounted ? setState(() => _failed = true) : null);
  }

  static Future<ClosedCaptionFile> _loadCaptions(String path) async {
    final text = utf8.decode(await File(path).readAsBytes(), allowMalformed: true);
    return path.toLowerCase().endsWith('.vtt') ? WebVTTCaptionFile(text) : SubRipCaptionFile(text);
  }

  void _onTick() {
    final value = _video.value;
    if (!value.isInitialized) return;
    final finished = value.position >= value.duration - const Duration(milliseconds: 500) && !value.isPlaying;
    if (finished || DateTime.now().difference(_lastKept) > const Duration(seconds: 5)) _keep(finished: finished);
    if (mounted) setState(() {});
  }

  void _keep({bool finished = false}) {
    final value = _video.value;
    if (!value.isInitialized) return;
    _lastKept = DateTime.now();
    final total = value.duration.inMilliseconds;
    ref.read(placeKeeperProvider)(
      widget.item.id,
      Place(position: value.position, progress: total == 0 ? 0 : (value.position.inMilliseconds / total).clamp(0, 1), updatedAt: DateTime.now().toUtc()),
      finished: finished,
    );
  }

  /// The chrome rests after 2.5 s of stillness while playing, and never while paused.
  void _scheduleRest() {
    _rest?.cancel();
    if (_video.value.isPlaying) _rest = Timer(ArkeSizes.chromeRest, () => mounted ? setState(() => _chrome = false) : null);
  }

  void _wake() {
    setState(() => _chrome = true);
    _scheduleRest();
  }

  Future<void> _toggle() async {
    _video.value.isPlaying ? await _video.pause() : await _video.play();
    _video.value.isPlaying ? await WakelockPlus.enable() : await WakelockPlus.disable();
    _wake();
  }

  Future<void> _seekBy(int seconds) async {
    final target = _video.value.position + Duration(seconds: seconds);
    await _video.seekTo(target < Duration.zero ? Duration.zero : target);
    _wake();
  }

  /// Full screen turns the phone and hides the system's bars; leaving it gives both back.
  Future<void> _toggleFullScreen() async {
    _fullScreen = !_fullScreen;
    if (_fullScreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await _restoreSystem();
    }
    _wake();
  }

  static Future<void> _restoreSystem() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const []);
  }

  @override
  void dispose() {
    _rest?.cancel();
    _keep();
    _video.removeListener(_onTick);
    _video.dispose();
    WakelockPlus.disable();
    if (_fullScreen) _restoreSystem();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
    final value = _video.value;
    final caption = settings.captions ? value.caption.text.trim() : '';
    final turned = MediaQuery.orientationOf(context) == Orientation.landscape;
    final hasCaptions = widget.item.captions != null;

    return Scaffold(
      backgroundColor: ArkeColors.mediaOverlayBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _chrome ? setState(() => _chrome = false) : _wake(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: _failed
                  ? const Text('Can’t open this file', style: TextStyle(color: _fg))
                  : _ready
                  ? AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(_video))
                  : const CircularProgressIndicator(color: _fg),
            ),
            if (caption.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: _chrome ? (turned ? 104 : 196) : 40,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0x9E0A0A0A), borderRadius: BorderRadius.circular(ArkeRadius.md)),
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _fg, fontSize: settings.captionSize.points, height: 1.35),
                    ),
                  ),
                ),
              ),
            IgnorePointer(
              ignoring: !_chrome,
              child: AnimatedOpacity(
                opacity: _chrome ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const _Scrims(),
                    SafeArea(
                      child: Column(
                        children: [
                          PlayerTop(
                            eyebrow: widget.item.author ?? widget.item.format.label,
                            title: widget.item.title,
                            actions: [
                              if (turned && hasCaptions)
                                PlayerPress(icon: Icons.closed_caption_outlined, label: 'Captions', on: settings.captions, onPressed: () => _captions(context)),
                            ],
                          ),
                          const Spacer(),
                          Padding(
                            padding: EdgeInsets.fromLTRB(turned ? 40 : 20, 0, turned ? 40 : 20, 12),
                            child: Column(
                              children: [
                                Scrubber(
                                  position: value.position,
                                  length: value.duration,
                                  onSeek: (position) {
                                    _video.seekTo(position);
                                    _wake();
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    PlayerPress(
                                      icon: Icons.closed_caption_outlined,
                                      label: 'Captions',
                                      on: settings.captions,
                                      onPressed: hasCaptions ? () => _captions(context) : null,
                                    ),
                                    PlayerPress(icon: Icons.replay_10, label: 'Back 10 seconds', onPressed: () => _seekBy(-10), size: 26),
                                    PlayPause(playing: value.isPlaying, onPressed: _toggle, small: turned),
                                    PlayerPress(icon: Icons.forward_10, label: 'Forward 10 seconds', onPressed: () => _seekBy(10), size: 26),
                                    PlayerPress(
                                      icon: _fullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                      label: _fullScreen ? 'Leave full screen' : 'Full screen',
                                      onPressed: _toggleFullScreen,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Captions (P3e): Off or On for the film's own track, and the size, kept on the device.
  Future<void> _captions(BuildContext context) => showPlayerSheet<void>(
    context,
    title: 'Captions',
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
        final controller = ref.read(settingsProvider.notifier);
        return ListView(
          shrinkWrap: true,
          children: [
            for (final on in [false, true])
              ListTile(
                title: Text(on ? 'On' : 'Off', style: const TextStyle(color: _fg)),
                trailing: settings.captions == on ? const Icon(Icons.check, color: _fg) : null,
                onTap: () => controller.change((current) => current.copyWith(captions: on)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'Size',
                style: TextStyle(color: _fg.withValues(alpha: 0.7), fontSize: ArkeType.sizeBase),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<CaptionSize>(
                segments: [for (final size in CaptionSize.values) ButtonSegment(value: size, label: Text(size.label))],
                selected: {settings.captionSize},
                showSelectedIcon: false,
                onSelectionChanged: (value) => controller.change((current) => current.copyWith(captionSize: value.first)),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The two scrims the chrome sits on: 168 at the top, 300 at the foot (Studio 156).
class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      SizedBox(
        height: 168,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xBD0A0A0A), Color(0x000A0A0A)]),
          ),
        ),
      ),
      Spacer(),
      SizedBox(
        height: 300,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xE60A0A0A), Color(0x000A0A0A)], stops: [0.12, 1]),
          ),
        ),
      ),
    ],
  );
}
