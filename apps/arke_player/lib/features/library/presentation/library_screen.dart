import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../add_file/presentation/add_flow.dart';
import 'item_menu.dart';

/// Library with files only (P8c; on a Fold, two columns, P8e): `All · Listen · Read · Watch`
/// when two or more kinds are present, the rows newest first, `+` in the head.
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
            child: items.isEmpty
                ? EmptyShelf(onAdd: () => addFiles(context, ref))
                : wide
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 68, crossAxisSpacing: 8),
                    itemCount: rows.length,
                    itemBuilder: (context, index) => row(rows[index]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    itemCount: rows.length,
                    itemBuilder: (context, index) => row(rows[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
