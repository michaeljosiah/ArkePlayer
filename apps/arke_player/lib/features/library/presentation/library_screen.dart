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
import '../../downloads/presentation/downloads_screen.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_shelf.dart';
import '../../worlds/presentation/world_widgets.dart';
import 'item_menu.dart';

/// What Library's chips show (P22l).
enum LibrarySection {
  worlds('Worlds'),
  files('Files'),
  downloads('Downloads');

  const LibrarySection(this.label);
  final String label;
}

/// What is on the phone (P22l, P22m, P25f): under `Worlds · Files · Downloads`, with `+` in the head for
/// Add a file. Worlds are cards with `New` or `Update`; an empty Worlds says so with a press to the
/// Worlds tab. Files are rows, two across on a Fold (P8e); an empty Files is `Nothing added` with Add a
/// file. Downloads is P6a's.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({this.show, super.key});

  /// A section by name: You's `On this phone` opens Downloads.
  final String? show;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late LibrarySection _section = _named(widget.show) ?? LibrarySection.worlds;

  static LibrarySection? _named(String? name) => LibrarySection.values.where((section) => section.name == name).firstOrNull;

  @override
  void didUpdateWidget(LibraryScreen old) {
    super.didUpdateWidget(old);
    final named = _named(widget.show);
    if (named != null && widget.show != old.show) _section = named;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfHeader(
            title: 'Library',
            trailing: RoundPress(icon: Icons.add, label: 'Add a file', onPressed: () => addFiles(context, ref)),
          ),
          LabelChips<LibrarySection>(
            all: false,
            options: [for (final section in LibrarySection.values) (section, section.label)],
            selected: _section,
            onSelect: (value) => setState(() => _section = value ?? _section),
          ),
          Expanded(
            child: switch (_section) {
              LibrarySection.worlds => const _Worlds(),
              LibrarySection.files => const _Files(),
              LibrarySection.downloads => const DownloadsPane(),
            },
          ),
        ],
      ),
    );
  }
}

class _Worlds extends ConsumerWidget {
  const _Worlds();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final worlds = ref.watch(libraryWorldsProvider).value ?? const [];
    if (worlds.isEmpty) {
      return Align(
        alignment: const Alignment(0, -0.16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No worlds yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.surface.mutedForeground)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go(Routes.worlds),
              icon: const Icon(Icons.public, size: 18),
              label: const Text('Worlds'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 18)),
            ),
          ],
        ),
      );
    }
    final byId = {for (final item in items) item.id: item};
    final catalogue = ref.watch(catalogueProvider).value ?? const [];
    Widget card(LibraryWorld world, {bool grid = false}) {
      final where = worldStart(world, listedFor(catalogue, world.id), byId)?.where;
      return WorldShelfCard(
        worldId: world.id,
        name: world.name,
        line: [?where, formatBytes(world.byteLength)].join(' · '),
        picture: libraryPicture(store, world.keyArt),
        age: listedFor(catalogue, world.id)?.age,
        fresh: worldHasNew(world, items),
        tag: ref.watch(worldUpdateProvider(world.id)) != null ? 'Update' : null,
        grid: grid,
        onOpen: () => context.push(Routes.libraryWorld(world.id)),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final bottom = 24 + footRoom(context);
    if (width >= WindowBands.fold) {
      return GridView.count(
        crossAxisCount: width >= WindowBands.wide ? 3 : 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 16 / 9,
        padding: EdgeInsets.fromLTRB(24, 14, 24, bottom),
        children: [for (final world in worlds) card(world, grid: true)],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
      children: [for (final world in worlds) Padding(padding: const EdgeInsets.only(bottom: 12), child: card(world))],
    );
  }
}

class _Files extends ConsumerWidget {
  const _Files();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final rows = libraryRows(items);
    if (rows.isEmpty) return EmptyShelf(onAdd: () => addFiles(context, ref));
    Widget row(LibraryItem item) =>
        FileRow(item: item, cover: coverOf(store, item), onOpen: () => openItem(context, item), onMore: () => showItemMenu(context, ref, item));
    final bottom = 24 + footRoom(context);
    if (MediaQuery.sizeOf(context).width >= WindowBands.fold) {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(8, 12, 8, bottom),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 68, crossAxisSpacing: 8),
        itemCount: rows.length,
        itemBuilder: (context, index) => row(rows[index]),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(top: 12, bottom: bottom),
      itemCount: rows.length,
      itemBuilder: (context, index) => row(rows[index]),
    );
  }
}
