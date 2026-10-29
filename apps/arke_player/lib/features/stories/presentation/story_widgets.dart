import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../players/presentation/chrome.dart';
import '../application/stories.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// The design's shadow-lg, under a choice and the novel's box.
const _shadowLg = [
  BoxShadow(color: Color(0x1A000000), offset: Offset(0, 10), blurRadius: 15, spreadRadius: -3),
  BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -4),
];

/// The labels in their type: a choice is h3, 18 semibold, a little tight.
const _choiceType = TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeLg, fontWeight: FontWeight.w600, height: 1.375, letterSpacing: -0.18);

/// One choice (P18 rules 2 and 3; P18b – P18d): 58 high, glass, its number in a small box; the first
/// open one in focus, in the overlay's ink. A closed one keeps its place, dashed and dimmed, a dash
/// for its number and the author's reason under its label.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({required this.option, required this.number, required this.onChoose, this.focus = false, super.key});

  final StoryOption option;

  /// Its number among the open ones; null for a closed one.
  final int? number;
  final bool focus;
  final VoidCallback? onChoose;

  static const height = 58.0;

  @override
  Widget build(BuildContext context) {
    final closed = !option.open;
    final ink = closed ? _fg.withValues(alpha: 0.58) : (focus ? _bg : _fg);
    final key = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: closed ? Colors.transparent : (focus ? _bg.withValues(alpha: 0.32) : _fg.withValues(alpha: 0.36))),
      ),
      child: Text(
        closed ? '–' : '$number',
        style: TextStyle(
          fontFamily: ArkeType.family,
          fontSize: ArkeType.sizeXs,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final label = Text(
      option.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _choiceType.copyWith(color: ink),
    );
    final card = Container(
      constraints: const BoxConstraints(minHeight: height),
      padding: EdgeInsets.fromLTRB(18, closed ? 11 : 0, 18, closed ? 11 : 0),
      child: Row(
        crossAxisAlignment: closed ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          key,
          const SizedBox(width: 14),
          Expanded(
            child: closed
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label,
                      const SizedBox(height: 3),
                      Text(
                        option.reason!,
                        style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.size2xs, height: 1.4, color: ink),
                      ),
                    ],
                  )
                : label,
          ),
        ],
      ),
    );
    final radius = BorderRadius.circular(ArkeRadius.xl);
    final Widget face;
    if (closed) {
      face = CustomPaint(
        painter: DashedBorder(color: _fg.withValues(alpha: 0.22), radius: ArkeRadius.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(color: _bg.withValues(alpha: 0.28), borderRadius: radius),
          child: card,
        ),
      );
    } else if (focus) {
      face = Stack(
        clipBehavior: Clip.none,
        children: [
          // The focus ring, 2 wide and 4 out, as the outline is drawn.
          Positioned(
            left: -6,
            top: -6,
            right: -6,
            bottom: -6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ArkeRadius.xl + 6),
                border: Border.all(color: _fg.withValues(alpha: 0.55), width: 2),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(color: _fg, borderRadius: radius, boxShadow: _shadowLg),
            child: card,
          ),
        ],
      );
    } else {
      face = DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: _shadowLg),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _bg.withValues(alpha: 0.46),
                borderRadius: radius,
                border: Border.all(color: _fg.withValues(alpha: 0.22)),
              ),
              child: card,
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: !closed,
      enabled: !closed,
      label: [if (!closed) '$number', option.label, ?option.reason].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: closed ? null : onChoose, child: face),
      ),
    );
  }
}

/// A step's choices in the author's order (R-84, R-85): the open ones numbered 1, 2, 3 around the
/// closed ones, the first open one in focus. Two sit side by side only when [across] — turned, or on a
/// Fold — and three or more are always one list (SPEC-063 R-26).
class StoryChoices extends StatelessWidget {
  const StoryChoices({required this.options, required this.onChoose, this.across = false, super.key});

  final List<StoryOption> options;
  final ValueChanged<StoryChoice> onChoose;
  final bool across;

  @override
  Widget build(BuildContext context) {
    var number = 0;
    var focused = false;
    final cards = <Widget>[];
    for (final option in options) {
      final focus = option.open && !focused;
      if (focus) focused = true;
      cards.add(ChoiceCard(option: option, number: option.open ? ++number : null, focus: focus, onChoose: () => onChoose(option.choice)));
    }
    if (across && cards.length == 2) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in cards.indexed) ...[if (i > 0) const SizedBox(height: 10), card],
      ],
    );
  }
}

/// `Replay scene`, quiet, under the choices; a visual novel's `Log` beside it (P19e). A movie has no
/// log (P19 call 27).
class ReplayScene extends StatelessWidget {
  const ReplayScene({required this.onPressed, this.onLog, super.key});
  final VoidCallback onPressed;
  final VoidCallback? onLog;

  @override
  Widget build(BuildContext context) {
    Widget press(IconData icon, String label, VoidCallback onPressed) => TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: _fg.withValues(alpha: 0.82),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
      ),
    );
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          press(Icons.replay_rounded, 'Replay scene', onPressed),
          if (onLog case final onLog?) ...[const SizedBox(width: 4), press(Icons.format_list_bulleted_rounded, 'Log', onLog)],
        ],
      ),
    );
  }
}

/// Narration, a labelled switch under a visual novel's top where the story has voices (P19b, P19
/// rule 5): glass, 44 high, the word and a small switch, on in full ink.
class NarrationSwitch extends StatelessWidget {
  const NarrationSwitch({required this.on, required this.onPressed, super.key});
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ArkeRadius.pill);
    return Semantics(
      button: true,
      toggled: on,
      label: 'Narration',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: ArkeSizes.press,
                padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                decoration: BoxDecoration(
                  color: _bg.withValues(alpha: 0.42),
                  borderRadius: radius,
                  border: Border.all(color: _fg.withValues(alpha: 0.16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Narration',
                      style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w500, height: 1.4, color: _fg),
                    ),
                    const SizedBox(width: 10),
                    // The design's small switch: 38 × 22, its knob 16, in full ink when on.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 38,
                      height: 22,
                      padding: const EdgeInsets.all(3),
                      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                      decoration: BoxDecoration(color: on ? _fg : _fg.withValues(alpha: 0.26), borderRadius: radius),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: on ? _bg : _fg, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle's border drawn in dashes, as a closed choice's is.
class DashedBorder extends CustomPainter {
  const DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.5));
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 6) {
        canvas.drawPath(metric.extractPath(at, math.min(at + 3, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorder old) => old.color != color || old.radius != radius;
}

/// The design's route glyph: a branch, a line and two rings.
class RouteGlyph extends StatelessWidget {
  const RouteGlyph({this.size = 20, this.color = _fg, super.key});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _RoutePainter(color)),
  );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(6 * s, 3 * s), Offset(6 * s, 15 * s), paint)
      ..drawCircle(Offset(18 * s, 6 * s), 3 * s, paint)
      ..drawCircle(Offset(6 * s, 18 * s), 3 * s, paint)
      ..drawPath(
        Path()
          ..moveTo(18 * s, 9 * s)
          ..arcToPoint(Offset(9 * s, 18 * s), radius: Radius.circular(9 * s)),
        paint,
      );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.color != color;
}

/// The route's press on a player's top.
class RoutePress extends StatelessWidget {
  const RoutePress({required this.onPressed, super.key});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: 'Route',
    style: IconButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: _fg),
    icon: const RouteGlyph(),
  );
}

/// A scene's still at the story's shape (P18 rule 4): 96 × 54 for 16:9, 40 × 72 for 9:16; ringed
/// where the route is now.
class StoryStill extends ConsumerWidget {
  const StoryStill({required this.story, required this.scene, this.now = false, this.ring = _fg, this.small = false, super.key});

  final LoadedStory story;
  final String scene;
  final bool now;
  final Color ring;

  /// The ending's strip: 64 × 36, or 36 × 64.
  final bool small;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tall = story.tallShape;
    final size = small ? (tall ? const Size(36, 64) : const Size(64, 36)) : (tall ? const Size(40, 72) : const Size(96, 54));
    final picture = ref.watch(storyStillProvider((story.worldId, story.production.id, scene))).value;
    final still = ClipRRect(
      borderRadius: BorderRadius.circular(ArkeRadius.md),
      child: SizedBox.fromSize(
        size: size,
        child: ColoredBox(
          color: _bg,
          child: picture == null ? null : Image(image: picture, fit: BoxFit.cover),
        ),
      ),
    );
    if (!now) return still;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ArkeRadius.md + 4),
        border: Border.all(color: ring, width: 2),
      ),
      child: still,
    );
  }
}

/// A route, scene by scene (P18 rule 4; P18a, P18e): each scene's still, title and length, and the
/// choice taken after it with `Choose again`; the last scene is `now`. A lone way taken leaves no row,
/// so the two scenes it joins sit one after the other (P19h). More than five scenes fold their middle
/// into `N more scenes`, which opens them; the fold keeps the last two scenes, and the one before them
/// too when the last choice was made there (P19h). [onMedia] draws it on the glass sheet; else on the
/// page's theme.
class RouteRows extends StatefulWidget {
  const RouteRows({required this.story, required this.path, required this.onChooseAgain, this.onMedia = true, super.key});

  final LoadedStory story;

  /// Every step of the route ([storyPath]), the start first.
  final List<StoryStep> path;

  /// `Choose again` at the route's choice of this index.
  final ValueChanged<int> onChooseAgain;
  final bool onMedia;

  @override
  State<RouteRows> createState() => _RouteRowsState();
}

class _RouteRowsState extends State<RouteRows> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final path = widget.path;
    final document = story.document;
    final ink = widget.onMedia ? _fg : context.surface.foreground;
    final tall = story.tallShape;
    // The taken row and the fold sit under the still's middle.
    final indent = tall ? 36.0 : 60.0;
    final made = storyChoicesMade(path);
    final folds = path.length > 5 && !_open;
    // The scene the fold ends at: the second last, or the third last where the last choice was made.
    final kept = math.max(path.length - 3, math.min(path.length - 2, made.lastOrNull ?? path.length));
    final rows = <Widget>[];

    Widget scene(int i) {
      final step = path[i];
      final now = i == path.length - 1;
      final length = sceneLength(document, step);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            StoryStill(story: story, scene: step.scene, now: now, ring: ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.scenes[step.scene]!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500, height: 1.4, color: ink),
                  ),
                  if (now || length > Duration.zero)
                    Text(
                      now ? 'now' : formatClock(length),
                      style: TextStyle(
                        fontFamily: ArkeType.family,
                        fontSize: ArkeType.size2xs,
                        height: 1.4,
                        color: ink.withValues(alpha: 0.62),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget taken(int i) {
      final choice = document.choice(path[i + 1].route[i])!;
      return Padding(
        padding: EdgeInsets.fromLTRB(indent, 2, 16, 2),
        child: Row(
          children: [
            Icon(Icons.chevron_right_rounded, size: 16, color: ink.withValues(alpha: 0.86)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                choice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ArkeType.family,
                  fontSize: ArkeType.sizeSm,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: ink.withValues(alpha: 0.86),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => widget.onChooseAgain(i),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                fixedSize: const Size.fromHeight(32),
                // 32 as drawn: the row is the press's height, not a padded target's.
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: widget.onMedia ? _fg.withValues(alpha: 0.16) : context.surface.secondary,
                foregroundColor: ink,
                textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w500),
              ),
              child: const Text('Choose again'),
            ),
          ],
        ),
      );
    }

    for (var i = 0; i < path.length; i++) {
      if (folds && i == 1) {
        final hidden = kept - 1;
        rows.add(
          Semantics(
            button: true,
            child: InkWell(
              onTap: () => setState(() => _open = true),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: EdgeInsets.fromLTRB(indent, 0, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: ink.withValues(alpha: 0.62)),
                    const SizedBox(width: 8),
                    Text(
                      '$hidden more scenes',
                      style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.size2xs, height: 1.4, color: ink.withValues(alpha: 0.62)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        i = kept - 1;
        continue;
      }
      rows.add(scene(i));
      if (made.contains(i)) rows.add(taken(i));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// The route sheet over a player (P18e, P4b): glass, `Route` and its count of scenes, the route,
/// then `Start over`.
Future<void> showRouteSheet(
  BuildContext context, {
  required LoadedStory story,
  required List<StoryStep> path,
  required ValueChanged<int> onChooseAgain,
  required VoidCallback onStartOver,
}) => showPlayerSheet<void>(
  context,
  title: 'Route',
  count: sceneCount(path.length),
  builder: (sheet) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RouteRows(
          story: story,
          path: path,
          onChooseAgain: (index) {
            Navigator.of(sheet).pop();
            onChooseAgain(index);
          },
        ),
        Padding(
          // Clear of the home indicator, as the drawn sheet's foot is.
          padding: EdgeInsets.fromLTRB(16, 16, 16, math.max(0, MediaQuery.paddingOf(sheet).bottom - 16)),
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(sheet).pop();
              onStartOver();
            },
            icon: const Icon(Icons.replay_rounded, size: 16),
            label: const Text('Start over'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(ArkeSizes.widePress),
              backgroundColor: _fg.withValues(alpha: 0.16),
              foregroundColor: _fg,
              textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    ),
  ),
);

/// An ending (P4c, upright-safe): `Ending`, the variant's title and text, the route's last stills,
/// the choices made, never a lone way taken (P19 rule 4), then `Start again` and `Back to last
/// choice`.
class StoryEndingCard extends StatelessWidget {
  const StoryEndingCard({required this.story, required this.step, required this.onStartAgain, required this.onBack, super.key});

  final LoadedStory story;
  final StoryStep step;
  final VoidCallback onStartAgain;

  /// Null when nothing was chosen.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ending = step.ending!;
    final document = story.document;
    final path = storyPath(document, step.route);
    final scenes = [for (final s in path) s.scene];
    final shown = scenes.length > 4 ? scenes.sublist(scenes.length - 4) : scenes;
    final taken = [for (final index in storyChoicesMade(path)) document.choice(step.route[index])!.label];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ENDING',
          style: TextStyle(
            fontFamily: ArkeType.family,
            fontSize: ArkeType.size2xs,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.55,
            color: _fg.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            ending.title,
            style: const TextStyle(
              fontFamily: ArkeType.family,
              fontSize: ArkeType.size4xl,
              fontWeight: FontWeight.w700,
              height: 1.08,
              letterSpacing: -0.9,
              color: _fg,
            ),
          ),
        ),
        if (ending.text case final text? when text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeMd, height: 1.5, color: _fg.withValues(alpha: 0.86)),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            for (final (i, scene) in shown.indexed) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(Icons.chevron_right_rounded, size: 14, color: _fg.withValues(alpha: 0.7)),
                ),
              StoryStill(story: story, scene: scene, small: true, now: i == shown.length - 1),
            ],
          ],
        ),
        if (taken.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            taken.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.size2xs, height: 1.4, color: _fg.withValues(alpha: 0.62)),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onStartAgain,
          icon: const Icon(Icons.replay_rounded, size: 16),
          label: const Text('Start again'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(ArkeSizes.widePress),
            backgroundColor: _fg,
            foregroundColor: _bg,
            textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
          ),
        ),
        if (onBack != null) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onBack,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(ArkeSizes.widePress),
              backgroundColor: _fg.withValues(alpha: 0.16),
              foregroundColor: _fg,
              textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
            ),
            child: const Text('Back to last choice'),
          ),
        ],
      ],
    );
  }
}
