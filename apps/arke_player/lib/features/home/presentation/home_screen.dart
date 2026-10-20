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
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/available_screen.dart';
import '../../worlds/presentation/world_widgets.dart';

/// Home before an account (P8b, P8d, P9g): Continue, then Added, then installed Worlds, then
/// Available; with nothing added, the state line and Add a file, Available under them (P9 rule 2).
/// No picture in the head: there is no account to show (P8 rule 1).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final worlds = ref.watch(libraryWorldsProvider).value ?? const [];
    final available = ref.watch(availableProvider);
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
                      if (available.isNotEmpty) ...[_availableRow(context, available), const SizedBox(height: 24)],
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
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
                              onOpen: () => openItem(context, going[index]),
                            ),
                          ),
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
                              onOpen: () => context.push(Routes.world(world.id)),
                            ),
                        ]),
                      ],
                      if (available.isNotEmpty) _availableRow(context, available),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Available at the end of Home (P9g): 240 × 135 cards, each showing its install while one runs.
  static Widget _availableRow(BuildContext context, List<CatalogueWorld> available) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHead('Available'),
      _row([for (final world in available) AvailableCard(world: world, mini: true, onOpen: () => context.push(Routes.world(world.id)))]),
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
