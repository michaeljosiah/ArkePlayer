import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Stands in for a screen until it is built, naming the design master frames it must match
/// (`design/Arke Player.dc.html`). Delete it from a screen when the screen is
/// drawn for real; a build ships none.
class FramePlaceholder extends StatelessWidget {
  const FramePlaceholder({required this.title, required this.frames, this.media = false, this.actions = const [], super.key});

  final String title;

  /// The frames this screen implements, e.g. `['P1b', 'P6d']`.
  final List<String> frames;

  /// A player or a hero: always on the media overlay colours, whatever the theme.
  final bool media;

  /// Presses the screen leads to, so the route map can be walked before the screens exist.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = media ? ArkeColors.mediaOverlayForeground : theme.colorScheme.onSurface;
    return ColoredBox(
      color: media ? ArkeColors.mediaOverlayBackground : theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineLarge?.copyWith(color: foreground)),
              const SizedBox(height: 6),
              Text(frames.join(' · '), style: theme.textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.6))),
              const SizedBox(height: 20),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}
