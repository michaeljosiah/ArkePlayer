import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../add_file/presentation/add_flow.dart';
import '../../production/domain/production_kind.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_widgets.dart';
import 'item_menu.dart';

/// How a file is taken, as Discover's chips name it (P15 rule 1).
TakenAs takenAsOf(LibraryKind kind) => switch (kind) {
  LibraryKind.listen => TakenAs.listen,
  LibraryKind.read => TakenAs.read,
  LibraryKind.watch => TakenAs.watch,
};

/// What is on the phone (P8c, P15h; on a Fold, two columns, P8e): installed worlds first as cards,
/// each with `New` or `Update` (P15 rule 1), under `Worlds`, then the files added under `Added`,
/// newest first, `+` in the head. Discover's chips, `All · Listen · Watch · Play · Read`, show when
/// two or more of them are present and filter both.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  TakenAs? _kind;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final allWorlds = ref.watch(libraryWorldsProvider).value ?? const [];
    // A world's music is heard: it is under Listen (P17 rule 2).
    Set<TakenAs> takenIn(LibraryWorld world) => {
      for (final production in world.productions) production.narration != null || production.music != null ? TakenAs.listen : TakenAs.read,
    };
    final present = {for (final kind in kindsPresent(items)) takenAsOf(kind), for (final world in allWorlds) ...takenIn(world)};
    final kinds = [
      for (final taken in TakenAs.chips)
        if (present.contains(taken)) taken,
    ];
    final kind = kinds.length > 1 && kinds.contains(_kind) ? _kind : null;
    final rows = libraryRows(items).where((item) => kind == null || takenAsOf(item.kind) == kind).toList();
    final worlds = allWorlds.where((world) => kind == null || takenIn(world).contains(kind)).toList();
    final showWorlds = worlds.isNotEmpty;
    final empty = allWorlds.isEmpty && libraryRows(items).isEmpty;
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;

    Widget row(LibraryItem item) =>
        FileRow(item: item, cover: coverOf(store, item), onOpen: () => openItem(context, item), onMore: () => showItemMenu(context, ref, item));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfHeader(
            title: 'Library',
            trailing: RoundPress(icon: Icons.add, label: 'Add a file', onPressed: () => addFiles(context, ref)),
          ),
          if (kinds.length > 1)
            LabelChips<TakenAs>(
              options: [for (final taken in TakenAs.chips) (taken, taken.label)],
              selected: kind,
              onSelect: (value) => setState(() => _kind = value),
            ),
          Expanded(
            child: empty
                ? EmptyShelf(onAdd: () => addFiles(context, ref))
                : CustomScrollView(
                    slivers: [
                      if (showWorlds) ...[
                        const SliverToBoxAdapter(child: SectionHead('Worlds')),
                        SliverList.list(
                          children: [
                            for (final world in worlds)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: WorldCard(
                                  name: world.name,
                                  meta: 'Installed · ${productionCount(world.productions.length)} · ${formatBytes(world.byteLength)}',
                                  picture: libraryPicture(store, world.keyArt),
                                  fresh: worldHasNew(world, items),
                                  tag: ref.watch(worldUpdateProvider(world.id)) != null ? 'Update' : null,
                                  onOpen: () => context.push(Routes.libraryWorld(world.id)),
                                ),
                              ),
                          ],
                        ),
                      ] else
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      if (showWorlds && rows.isNotEmpty) const SliverToBoxAdapter(child: SectionHead('Added')),
                      if (wide)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          sliver: SliverGrid.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 68, crossAxisSpacing: 8),
                            itemCount: rows.length,
                            itemBuilder: (context, index) => row(rows[index]),
                          ),
                        )
                      else
                        SliverList.builder(itemCount: rows.length, itemBuilder: (context, index) => row(rows[index])),
                      SliverToBoxAdapter(child: SizedBox(height: 24 + footRoom(context))),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
