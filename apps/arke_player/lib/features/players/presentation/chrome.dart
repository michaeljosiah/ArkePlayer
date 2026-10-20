import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

const _fg = ArkeColors.mediaOverlayForeground;

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
      textStyle: const TextStyle(fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w500),
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

/// A glass sheet over a player (P5b, P5c, P3e).
Future<T?> showPlayerSheet<T>(BuildContext context, {required String title, String? count, required WidgetBuilder builder}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const Color(0xCC0A0A0A),
  barrierColor: const Color(0x4D0A0A0A),
  builder: (context) => Theme(
    data: ThemeData.dark(useMaterial3: true).copyWith(
      textTheme: Theme.of(context).textTheme.apply(bodyColor: _fg, displayColor: _fg),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: _fg, fontSize: ArkeType.sizeLg, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (count != null)
                    Text(
                      count,
                      style: TextStyle(color: _fg.withValues(alpha: 0.6), fontSize: ArkeType.sizeSm),
                    ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), tooltip: 'Close', color: _fg, icon: const Icon(Icons.close, size: 18)),
                ],
              ),
            ),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  ),
);
