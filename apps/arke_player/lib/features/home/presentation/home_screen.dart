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
import '../../worlds/application/discover.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_widgets.dart';

/// Home before an account (P8b, P8d, P9g, P15g): Continue — a chapter that came after the one
/// before it finished leads with `New` — then the installed worlds' New chapters of the last 14
/// days, Added, installed Worlds, and Discover, the worlds not installed; with nothing added, the
/// state line and Add a file, Discover under them (P9 rule 2). No picture in the head: there is no
/// account to show (P8 rule 1).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final worlds = ref.watch(libraryWorldsProvider).value ?? const [];
    final available = ref.watch(availableProvider);
    final catalogue = ref.watch(catalogueProvider).value ?? const [];
    final fresh = freshParts(catalogue, ref.watch(clockProvider)(), only: (world) => worlds.any((held) => world.covers(held.id)));
    final now = ref.watch(clockProvider)();
    final width = rowTileWidth(context);
    final going = continueShelf(items);
    final added = addedShelf(items);
    final cardWidth = MediaQuery.sizeOf(context).width >= WindowBands.fold ? 420.0 : 300.0;
    // The Added row is as tall as a square and its two lines at the reader's text size (acceptance 9).
    final scaler = MediaQuery.textScalerOf(context);
    final addedHeight = 120 + 7 + scaler.scale(ArkeType.sizeSm) * 1.4 + scaler.scale(ArkeType.size2xs) * 1.4 + 6;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShelfHeader(title: 'Home'),
          Expanded(
            child: added.isEmpty && worlds.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: EmptyShelf(onAdd: () => addFiles(context, ref))),
                      if (available.isNotEmpty) ...[_availableRow(context, available, width), const SizedBox(height: 24)],
                    ],
                  )
                : ListView(
                    padding: EdgeInsets.only(bottom: 24 + footRoom(context)),
                    children: [
                      if (going.isNotEmpty) ...[
                        const SectionHead('Continue'),
                        SizedBox(
                          height: cardWidth * 9 / 16,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: going.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) => ContinueCard(
                              item: going[index],
                              cover: coverOf(store, going[index]),
                              width: cardWidth,
                              fresh: worlds.where((world) => world.id == going[index].worldId).any((world) => placeIsNew(world, going[index])),
                              onOpen: () => openItem(context, going[index]),
                            ),
                          ),
                        ),
                      ],
                      if (fresh.isNotEmpty) ...[
                        const SectionHead('New chapters'),
                        TileRow(
                          children: [
                            for (final item in fresh)
                              ProductionTile(
                                title: item.production?.title ?? item.world.name,
                                kind: '${chaptersLabel(item.part.chapters, episodes: item.episodes)} · ${item.world.name}',
                                picture: bundledPicture(item.production?.picture ?? item.world.keyArt),
                                fresh: releasedThisWeek(item.part, now),
                                width: width,
                                onOpen: () {
                                  final held = worlds.where((world) => item.world.covers(world.id)).first;
                                  final there = held.productions.any((production) => production.id == item.part.production);
                                  context.push(there ? Routes.production(Routes.world(held.id), item.part.production) : Routes.world(held.id));
                                },
                              ),
                          ],
                        ),
                      ],
                      if (added.isNotEmpty) ...[
                        const SectionHead('Added'),
                        SizedBox(
                          height: addedHeight,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: added.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) =>
                                AddedSquare(item: added[index], cover: coverOf(store, added[index]), onOpen: () => openItem(context, added[index])),
                          ),
                        ),
                      ],
                      if (worlds.isNotEmpty) ...[
                        const SectionHead('Worlds'),
                        _row([
                          for (final world in worlds)
                            WorldCard(
                              name: world.name,
                              meta: productionCount(world.productions.length),
                              picture: libraryPicture(store, world.keyArt),
                              mini: true,
                              width: width,
                              fresh: worldHasNew(world, items),
                              onOpen: () => context.push(Routes.world(world.id)),
                            ),
                        ]),
                      ],
                      if (available.isNotEmpty) _availableRow(context, available, width),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Discover at the end of Home (P9g, P15g): the worlds not installed, in the row's tile, each
  /// showing its install while one runs.
  static Widget _availableRow(BuildContext context, List<CatalogueWorld> available, double width) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHead('Discover'),
      _row([for (final world in available) AvailableCard(world: world, mini: true, width: width, onOpen: () => context.push(Routes.world(world.id)))]),
    ],
  );

  static Widget _row(List<Widget> cards) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final (i, card) in cards.indexed) ...[if (i > 0) const SizedBox(width: 12), card],
      ],
    ),
  );
}
