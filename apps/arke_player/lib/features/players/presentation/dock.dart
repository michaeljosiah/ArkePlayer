import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/players.dart';

/// The dock (P1 rule 8): audio that plays while its player is closed sits above the tabs — 60
/// high, a 2-high line of progress on its top edge, the picture, the title over where, back 15 and
/// play or pause. A press opens the player. Video never docks. Over the tabs' pill it floats as
/// glass, rounded as the pill's neighbour (P16i); otherwise it is inset 8.
class Dock extends ConsumerWidget {
  const Dock({this.floating = false, super.key});

  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(audioEngineProvider);
    if (engine == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: engine.playingStream,
      initialData: engine.playing,
      builder: (context, playing) {
        final item = engine.item;
        if (item == null) return const SizedBox.shrink();
        final store = ref.watch(libraryStoreProvider).value;
        final kept = item.cover == null || store == null ? null : File(store.resolve(item.cover!));
        final surface = context.surface;
        final text = Theme.of(context).textTheme;
        return StreamBuilder<Duration>(
          stream: engine.position,
          builder: (context, position) {
            final now = position.data ?? engine.now;
            // An illustrated narration's dock shows the picture of the moment, as the lock screen does.
            final art = engine.artwork.value;
            final cover = art == null ? kept : File(art);
            final total = engine.length.inMilliseconds;
            final chapter = item.chapters.length > 1 ? 'Chapter ${engine.chapterAt(now) + 1} · ' : '';
            return Padding(
              padding: floating ? EdgeInsets.zero : const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Material(
                color: floating ? surface.card.withValues(alpha: 0.92) : surface.card,
                elevation: floating ? 8 : 3,
                shadowColor: floating ? Colors.black38 : Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(floating ? ArkeRadius.xxl : ArkeRadius.xl),
                  side: BorderSide(color: floating ? surface.foreground.withValues(alpha: 0.11) : surface.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push(Routes.open(item.id)),
                  child: SizedBox(
                    height: ArkeSizes.dock,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 2,
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : now.inMilliseconds / total,
                            minHeight: 2,
                            color: surface.foreground,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
                          child: Row(
                            children: [
                              FileThumb(item: item, cover: cover, width: 44, height: 44),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                                    Text('$chapter${formatClock(now)}', style: text.labelSmall?.copyWith(color: surface.mutedForeground)),
                                  ],
                                ),
                              ),
                              IconButton(onPressed: engine.rewind, tooltip: 'Back 15 seconds', icon: const Icon(Icons.replay)),
                              IconButton(
                                onPressed: () => (playing.data ?? false) ? engine.pause() : engine.play(),
                                tooltip: (playing.data ?? false) ? 'Pause' : 'Play',
                                icon: Icon((playing.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
