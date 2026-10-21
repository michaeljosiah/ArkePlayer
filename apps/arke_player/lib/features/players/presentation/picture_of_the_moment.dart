import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/tokens.dart';
import '../application/listening_plan.dart';

/// The picture of the moment (Player P5a; SPEC-058 R-22 – R-25): each picture crossfades over a
/// second at its time, letterboxed in its place, and with Slow push moves 6% closer over its hold
/// about its focus, starting again at each crossfade (SPEC-047 R-75, R-136). Only the push crops it.
/// A picture with motion plays its loop, muted, over its still once the loop is ready.
class PictureOfTheMoment extends StatelessWidget {
  const PictureOfTheMoment({required this.shown, required this.position, required this.playing, required this.speed, required this.push, super.key});

  final ShownPicture? shown;
  final Duration position;
  final bool playing;
  final double speed;
  final bool push;

  @override
  Widget build(BuildContext context) {
    final shown = this.shown;
    return AnimatedSwitcher(
      duration: const Duration(seconds: 1),
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: shown == null
          ? const ColoredBox(key: ValueKey('none'), color: ArkeColors.mediaOverlayBackground)
          : _Pushed(key: ValueKey('${shown.path}@${shown.start.inMilliseconds}'), shown: shown, position: position, playing: playing, speed: speed, push: push),
    );
  }
}

/// One picture across its hold. The push is an animation re-anchored to the playing position at
/// each update, so it pauses with the audio and keeps to the speed rather than the wall clock.
class _Pushed extends StatefulWidget {
  const _Pushed({required this.shown, required this.position, required this.playing, required this.speed, required this.push, super.key});

  final ShownPicture shown;
  final Duration position;
  final bool playing;
  final double speed;
  final bool push;

  @override
  State<_Pushed> createState() => _PushedState();
}

class _PushedState extends State<_Pushed> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, value: widget.shown.progressAt(widget.position));

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(covariant _Pushed old) {
    super.didUpdateWidget(old);
    _follow();
  }

  bool get _pushing => widget.push && widget.shown.pushes;

  void _follow() {
    final shown = widget.shown;
    final at = shown.progressAt(widget.position);
    // Re-anchor only when the animation has drifted, so a steady play is one smooth move.
    if ((at - _progress.value).abs() > 0.01 || !_progress.isAnimating) _progress.value = at;
    final left = shown.end - widget.position;
    if (widget.playing && _pushing && left > Duration.zero && at < 1) {
      _progress.animateTo(1, duration: Duration(microseconds: (left.inMicroseconds / widget.speed).round()));
    } else {
      _progress.stop();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = widget.shown.focus;
    final alignment = focus == null ? Alignment.center : Alignment(focus.x * 2 - 1, focus.y * 2 - 1);
    // The picture at its own size, pushed about its focus and clipped to itself, then letterboxed
    // whole: the push is measured on the picture, so the focus holds still and the window never
    // leaves it (R-23).
    final still = Image.file(File(widget.shown.path), gaplessPlayback: true);
    final motion = widget.shown.motionPath;
    return FittedBox(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, child) => Transform.scale(scale: _pushing ? 1 + 0.06 * _progress.value : 1, alignment: alignment, child: child),
          child: motion == null ? still : _Motion(path: motion, repeats: widget.shown.motionRepeats, playing: widget.playing, still: still),
        ),
      ),
    );
  }
}

/// A picture's loop, muted, over its still; the still shows until the loop is ready, and stays if
/// the phone cannot play it (SPEC-058 R-25).
class _Motion extends StatefulWidget {
  const _Motion({required this.path, required this.repeats, required this.playing, required this.still});

  final String path;
  final bool repeats;
  final bool playing;
  final Widget still;

  @override
  State<_Motion> createState() => _MotionState();
}

class _MotionState extends State<_Motion> {
  late final VideoPlayerController _video = VideoPlayerController.file(File(widget.path), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _video
        .initialize()
        .then((_) async {
          await _video.setVolume(0);
          await _video.setLooping(widget.repeats);
          if (widget.playing) await _video.play();
          if (mounted) setState(() => _ready = true);
        })
        .catchError((Object _) {});
  }

  @override
  void didUpdateWidget(covariant _Motion old) {
    super.didUpdateWidget(old);
    if (!_ready || old.playing == widget.playing) return;
    widget.playing ? _video.play() : _video.pause();
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.still,
      // The loop is made from its still, so it covers the still's place exactly.
      if (_ready)
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: _video.value.size.width, height: _video.value.size.height, child: VideoPlayer(_video)),
          ),
        ),
    ],
  );
}
