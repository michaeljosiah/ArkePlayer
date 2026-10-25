import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/music.dart';
import '../application/players.dart';

/// Opens the production a track is heard in at its chapter and moment (SPEC-058 R-77): the place
/// is the chapter's, by its id where the narration keeps one (R-26), as a chapter's row opens it.
/// From a player the narration takes the player's place; elsewhere it opens over the page.
Future<void> openHeard(BuildContext context, WidgetRef ref, HeardPlace place, {bool replace = false}) async {
  final narration = place.narration;
  final chapter = place.chapter;
  if (narration == null || chapter == null) return;
  final at = chapter.start + place.heard.at;
  final total = narration.duration?.inMilliseconds ?? 0;
  await ref
      .read(placeKeeperProvider)
      .call(
        narration.id,
        Place(
          locator: chapter.id,
          position: chapter.id == null ? at : place.heard.at,
          progress: total <= 0 ? 0 : (at.inMilliseconds / total).clamp(0.0, 1.0),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
  if (!context.mounted) return;
  if (replace) {
    context.pushReplacement(Routes.open(narration.id));
  } else {
    await context.push(Routes.open(narration.id));
  }
}

/// A track of an album's page (P17c, P17h): its number, or bars while it plays; its title and at
/// most one line, whose theme it is or where it is heard; its length; ⋯.
class TrackRow extends StatelessWidget {
  const TrackRow({required this.number, required this.title, required this.length, required this.onPlay, this.line, this.now = false, this.onMore, super.key});

  final int number;
  final String title;
  final String? line;
  final Duration length;
  final bool now;
  final VoidCallback onPlay;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    final muted = surface.mutedForeground;
    const numbers = [FontFeature.tabularFigures()];
    return Semantics(
      button: true,
      selected: now,
      label: [title, ?line, formatClock(length), if (now) 'Playing'].join(', '),
      child: InkWell(
        onTap: onPlay,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: ExcludeSemantics(
                    child: now
                        ? Icon(Icons.graphic_eq_rounded, size: 18, color: surface.foreground)
                        : Text(
                            '$number',
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(color: muted, fontFeatures: numbers),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, fontWeight: now ? FontWeight.w600 : null),
                        ),
                        if (line != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            line!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: Text(
                    formatClock(length),
                    style: text.labelSmall?.copyWith(color: muted, fontFeatures: numbers),
                  ),
                ),
                if (onMore != null)
                  IconButton(
                    onPressed: onMore,
                    tooltip: 'More',
                    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_horiz, size: 18, color: muted),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A song where it belongs elsewhere (P17f, P17g): its square cover, its title over one line of
/// data, and a round play when it can play. A row's own press opens what [onOpen] says.
class SongRow extends StatelessWidget {
  const SongRow({required this.title, required this.line, this.cover, this.onPlay, this.onOpen, super.key});

  final String title;
  final String line;
  final ImageProvider? cover;
  final VoidCallback? onPlay;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ArkeRadius.md),
            child: SizedBox.square(
              dimension: 52,
              child: cover == null
                  ? ColoredBox(
                      color: surface.secondary,
                      child: Icon(Icons.music_note_rounded, size: 22, color: surface.mutedForeground),
                    )
                  : Image(image: cover!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: surface.mutedForeground, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
          ),
          if (onPlay != null) ...[
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: onPlay,
              tooltip: 'Play $title',
              style: IconButton.styleFrom(backgroundColor: surface.secondary, foregroundColor: surface.foreground, fixedSize: const Size.square(40)),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: onOpen != null,
      label: [title, line].join(', '),
      child: onOpen == null ? row : InkWell(onTap: onOpen, child: row),
    );
  }
}
