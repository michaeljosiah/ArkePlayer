import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../add_file/presentation/add_flow.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_widgets.dart';
import 'item_menu.dart';

/// Library (P8c; on a Fold, two columns, P8e): `All · Listen · Read · Watch` when two or more kinds
/// of file are present, the rows newest first, `+` in the head. Installed worlds come first under
/// All, as cards, with the files under `Files` after them (P7b, P9 rule 6); the chips filter files.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryKind? _kind;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final kinds = kindsPresent(items);
    final kind = kinds.contains(_kind) ? _kind : null;
    final rows = libraryRows(items, kind: kind);
    final worlds = ref.watch(libraryWorldsProvider).value ?? const [];
    final showWorlds = kind == null && worlds.isNotEmpty;
    final empty = worlds.isEmpty && libraryRows(items).isEmpty;
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
          if (kinds.length > 1) KindChips(kinds: kinds, selected: kind, onSelect: (value) => setState(() => _kind = value)),
          Expanded(
            child: empty
                ? EmptyShelf(onAdd: () => addFiles(context, ref))
                : CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      if (showWorlds)
                        SliverList.list(
                          children: [
                            for (final world in worlds)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: WorldCard(
                                  name: world.name,
                                  meta: 'Installed · ${productionCount(world.productions.length)} · ${formatBytes(world.byteLength)}',
                                  picture: libraryPicture(store, world.keyArt),
                                  onOpen: () => context.push(Routes.libraryWorld(world.id)),
                                ),
                              ),
                          ],
                        ),
                      if (showWorlds && rows.isNotEmpty) const SliverToBoxAdapter(child: SectionHead('Files')),
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
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
