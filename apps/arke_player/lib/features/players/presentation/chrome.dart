import 'dart:ui' show ImageFilter;

import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// What a player's menus are made of (P24e, P24f, P27f): what plays shows through, blurred and a little
/// richer, under a light tint of the media colour. The owner, 8 November 2026, asked for them
/// translucent: they had been 80% black, with nothing behind them blurred.
final playerGlass = ImageFilter.compose(
  // Saturation 1.4, as the design's `saturate(140%)`, so the blur keeps the picture's colour.
  outer: const ColorFilter.matrix([
    1.31496, -0.28608, -0.02888, 0, 0, //
    -0.08504, 1.11392, -0.02888, 0, 0, //
    -0.08504, -0.28608, 1.37112, 0, 0, //
    0, 0, 0, 1, 0,
  ]),
  inner: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
);

/// Glass in a shape: the blur clipped to it, then the tint and an edge of light.
class PlayerGlass extends StatelessWidget {
  const PlayerGlass({required this.borderRadius, required this.child, this.border, super.key});

  final BorderRadius borderRadius;
  final BoxBorder? border;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: playerGlass,
      child: DecoratedBox(
        decoration: BoxDecoration(color: _bg.withValues(alpha: 0.46), borderRadius: borderRadius, border: border),
        child: child,
      ),
    ),
  );
}

/// A menu's count, in a pill beside its name.
class CountPill extends StatelessWidget {
  const CountPill(this.count, {super.key});

  final String count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: _fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(ArkeRadius.pill)),
    child: Text(
      count,
      style: TextStyle(
        color: _fg.withValues(alpha: 0.82),
        fontSize: ArkeType.sizeSm,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// A round press on glass: a menu's close, its bell.
class GlassRoundPress extends StatelessWidget {
  const GlassRoundPress({required this.icon, required this.tooltip, required this.onPressed, this.on = false, super.key});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool on;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    style: IconButton.styleFrom(backgroundColor: on ? _fg : _fg.withValues(alpha: 0.12), fixedSize: const Size.square(36), minimumSize: const Size.square(36)),
    icon: Icon(icon, size: 18, color: on ? _bg : _fg),
  );
}

/// A player's top (Studio 156): ⌄ to close, the eyebrow over the title, then the player's own
/// presses. Always on the media overlay colours.
class PlayerTop extends StatelessWidget {
  const PlayerTop({required this.eyebrow, required this.title, this.actions = const [], super.key});

  final String eyebrow;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.of(context).maybePop(), tooltip: 'Close', color: _fg, icon: const Icon(Icons.keyboard_arrow_down, size: 28)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: _fg.withValues(alpha: 0.68), letterSpacing: 0.55, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _fg, fontSize: ArkeType.sizeMd, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A press on a player: 44 round, in the overlay's ink.
class PlayerPress extends StatelessWidget {
  const PlayerPress({required this.icon, required this.label, required this.onPressed, this.on = false, this.size = 22, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: label,
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: _fg,
      backgroundColor: on ? _fg.withValues(alpha: 0.18) : Colors.transparent,
      disabledForegroundColor: _fg.withValues(alpha: 0.3),
    ),
    icon: Icon(icon, size: size),
  );
}

/// The big round play or pause, 64 (52 when [small]).
class PlayPause extends StatelessWidget {
  const PlayPause({required this.playing, required this.onPressed, this.small = false, super.key});

  final bool playing;
  final VoidCallback onPressed;
  final bool small;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: playing ? 'Pause' : 'Play',
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: small ? 52 : 64,
        child: Material(
          color: _fg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: ArkeColors.mediaOverlayBackground, size: small ? 26 : 30),
          ),
        ),
      ),
    ),
  );
}

/// A labelled press on a player, e.g. `1.0×` or `End of chapter`.
class PlayerLabelPress extends StatelessWidget {
  const PlayerLabelPress({required this.label, required this.onPressed, this.icon, this.on = false, super.key});

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool on;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
    label: Text(label),
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: _fg,
      backgroundColor: on ? _fg.withValues(alpha: 0.18) : Colors.transparent,
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w500),
      padding: EdgeInsets.fromLTRB(icon == null ? 14 : 12, 0, 14, 0),
    ),
  );
}

/// The scrubber and its two times (Studio 156): played in full ink, the knob 14.
class Scrubber extends StatelessWidget {
  const Scrubber({required this.position, required this.length, required this.onSeek, this.trailing, super.key});

  final Duration position;
  final Duration length;
  final ValueChanged<Duration> onSeek;

  /// What the right-hand time shows; the length by default.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final total = length.inMilliseconds;
    final value = total == 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
    final time = Theme.of(context).textTheme.labelSmall?.copyWith(color: _fg.withValues(alpha: 0.74), fontFeatures: const [FontFeature.tabularFigures()]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: _fg,
            inactiveTrackColor: _fg.withValues(alpha: 0.22),
            thumbColor: _fg,
            overlayColor: _fg.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            trackShape: const RectangularSliderTrackShape(),
            padding: EdgeInsets.zero,
          ),
          child: Slider(
            value: value,
            onChanged: total == 0 ? null : (fraction) => onSeek(Duration(milliseconds: (fraction * total).round())),
            semanticFormatterCallback: (_) => '${formatClock(position)} of ${formatClock(length)}',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatClock(position), style: time),
            Text(trailing ?? formatClock(length), style: time),
          ],
        ),
      ],
    );
  }
}

/// A glass sheet over a player (P5b, P5c, P3e): rounded, with its grip, its name and count, and a round
/// close. The barrier is light, so what plays stays in view behind the glass.
Future<T?> showPlayerSheet<T>(BuildContext context, {required String title, String? count, required WidgetBuilder builder}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  backgroundColor: Colors.transparent,
  elevation: 0,
  barrierColor: const Color(0x260A0A0A),
  builder: (context) => Theme(
    data: ThemeData.dark(useMaterial3: true).copyWith(
      textTheme: Theme.of(context).textTheme.apply(bodyColor: _fg, displayColor: _fg),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: PlayerGlass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _fg.withValues(alpha: 0.16))),
        child: Padding(
          padding: EdgeInsets.only(bottom: 12 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(color: _fg.withValues(alpha: 0.32), borderRadius: BorderRadius.circular(ArkeRadius.pill)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _fg, fontSize: ArkeType.sizeXl, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (count != null) ...[const SizedBox(width: 10), CountPill(count)],
                    const Spacer(),
                    GlassRoundPress(icon: Icons.close_rounded, tooltip: 'Close', onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Flexible(child: builder(context)),
            ],
          ),
        ),
      ),
    ),
  ),
);
