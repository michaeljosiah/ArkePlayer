import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../add_file/presentation/add_flow.dart';
import '../../library/presentation/item_menu.dart';
import '../../parts/application/parts.dart';
import '../../production/domain/production_kind.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_widgets.dart';

/// What is on the phone (P6a, before an account): the space Arke Player takes against the rest and
/// what is free, then under Worlds a world's update (P12e) and a world's new chapters arriving or
/// waiting for Wi-Fi (P15k, SPEC-058 R-51), then everything added: a world installing with its line
/// (P9 rule 4), installed worlds, then files largest first, each with ⋯ to remove it.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final volume = ref.watch(volumeProvider).value;
    final worlds = ref.watch(libraryWorldsProvider).value ?? const [];
    final running = [
      for (final world in ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[])
        if (ref.watch(installProvider(world.id)) case final Installing state) (world: world, state: state),
    ];
    // A world updating is listed under Worlds (P12e); one installing under Added, as before.
    final updating = running.where((run) => run.state.updating).toList();
    final installing = running.where((run) => !run.state.updating).toList();
    final updatingIds = {
      for (final run in updating) ...[run.world.id, ...run.world.replaces],
    };
    final arriving = ref.watch(partsProvider);
    final used = bytesUsed(items, worlds);
    final rows = items.where((item) => item.worldId == null).toList()..sort((a, b) => b.byteLength.compareTo(a.byteLength));
    final empty = rows.isEmpty && worlds.isEmpty && installing.isEmpty;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShelfHeader(title: 'Downloads'),
          if (!empty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _SpaceBar(used: used, free: volume?.free, total: volume?.total),
            ),
          Expanded(
            child: empty
                ? EmptyShelf(onAdd: () => addFiles(context, ref))
                : ListView(
                    padding: EdgeInsets.only(bottom: 24 + footRoom(context)),
                    children: [
                      if (updating.isNotEmpty || arriving.isNotEmpty) const SectionHead('Worlds'),
                      for (final MapEntry(key: worldId, value: arrival) in arriving.entries)
                        _WorldRow(
                          name: arrival.world.name,
                          line: arrival.line(
                            episodes: switch (arrival.world.productions.where((production) => production.id == arrival.part.production).firstOrNull) {
                              final production? => const {ProductionKind.microDrama, ProductionKind.series}.contains(ProductionKind.ofLine(production.kind)),
                              null => false,
                            },
                          ),
                          picture: libraryPicture(store, worlds.where((installed) => installed.id == worldId).firstOrNull?.keyArt),
                          progress: arrival.fraction,
                          onOpen: () => context.go(Routes.libraryWorld(worldId)),
                          end: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(arrival.waiting ? Icons.wifi_off_rounded : Icons.downloading_rounded, color: context.surface.mutedForeground),
                          ),
                        ),
                      if (updating.isNotEmpty) ...[
                        for (final (:world, :state) in updating)
                          _WorldRow(
                            name: world.name,
                            line: state.short,
                            picture: libraryPicture(store, worlds.where((installed) => world.covers(installed.id)).firstOrNull?.keyArt),
                            progress: state.fraction,
                            onOpen: () => context.push(Routes.world(world.id)),
                            end: IconButton(
                              onPressed: () => ref.read(installProvider(world.id).notifier).cancel(),
                              tooltip: 'Cancel',
                              icon: Icon(Icons.close_rounded, color: context.surface.mutedForeground),
                            ),
                          ),
                      ],
                      if (installing.isNotEmpty || worlds.any((installed) => !updatingIds.contains(installed.id)) || rows.isNotEmpty)
                        const SectionHead('Added'),
                      for (final (:world, :state) in installing)
                        _WorldRow(
                          name: world.name,
                          line: state.short,
                          picture: ref.keyArtOf(world),
                          progress: state.fraction,
                          onOpen: () => context.push(Routes.world(world.id)),
                          end: IconButton(
                            onPressed: () => ref.read(installProvider(world.id).notifier).cancel(),
                            tooltip: 'Cancel',
                            icon: Icon(Icons.close_rounded, color: context.surface.mutedForeground),
                          ),
                        ),
                      for (final world in worlds.where((installed) => !updatingIds.contains(installed.id)))
                        _WorldRow(
                          name: world.name,
                          line: '${productionCount(world.productions.length)} · ${formatBytes(world.byteLength)}',
                          picture: libraryPicture(store, world.keyArt),
                          onOpen: () => context.go(Routes.libraryWorld(world.id)),
                          end: IconButton(
                            onPressed: () => showWorldMenu(context, ref, world),
                            tooltip: 'More',
                            icon: Icon(Icons.more_horiz, color: context.surface.mutedForeground),
                          ),
                        ),
                      for (final item in rows)
                        FileRow(item: item, cover: coverOf(store, item), onOpen: () => openItem(context, item), onMore: () => showItemMenu(context, ref, item)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Arke Player's share of the volume, the rest, and what is free (P6a).
class _SpaceBar extends StatelessWidget {
  const _SpaceBar({required this.used, required this.free, required this.total});

  final int used;
  final int? free;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final text = Theme.of(context).textTheme.labelSmall?.copyWith(color: surface.mutedForeground);
    final whole = total ?? (used + (free ?? 0));
    final other = whole - used - (free ?? 0);
    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: text)),
      ],
    );
    final otherColor = surface.foreground.withValues(alpha: 0.24);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Widths are worked out from the bar's own width: a row of flexes inside a loose column
        // collapsed to nothing, leaving only the legend.
        LayoutBuilder(
          builder: (context, box) {
            double share(int bytes) => whole <= 0 || bytes <= 0 ? 0 : (box.maxWidth * bytes / whole).clamp(4, box.maxWidth);
            return ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 10,
                width: box.maxWidth,
                color: surface.secondary,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: share(used), color: surface.foreground),
                    if (other > 0) Container(width: share(other), color: otherColor),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            legend(surface.foreground, 'Arke Player ${formatBytes(used)}'),
            if (other > 0) legend(otherColor, 'Other ${formatBytes(other)}'),
            if (free != null) legend(surface.secondary, '${formatBytes(free!)} free'),
          ],
        ),
      ],
    );
  }
}

/// A world's row (P6a's Added): its key art at 52, its name, its size or its install as data.
class _WorldRow extends StatelessWidget {
  const _WorldRow({required this.name, required this.line, required this.picture, required this.onOpen, required this.end, this.progress});

  final String name;
  final String line;
  final ImageProvider? picture;
  final VoidCallback onOpen;
  final Widget end;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ArkeRadius.md),
              child: SizedBox(
                width: 52,
                height: 52,
                child: picture == null ? ColoredBox(color: surface.secondary) : Image(image: picture!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: surface.mutedForeground),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ArkeRadius.pill),
                      child: LinearProgressIndicator(value: progress, minHeight: 3, backgroundColor: surface.secondary, color: surface.foreground),
                    ),
                  ],
                ],
              ),
            ),
            end,
          ],
        ),
      ),
    );
  }
}
