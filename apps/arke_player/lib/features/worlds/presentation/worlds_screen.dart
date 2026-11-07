import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'world_shelf.dart';
import 'world_widgets.dart';

/// Every genre a listed world has, in the list's order: Worlds' chips and Search's cards (P22 rule 8).
List<String> genresOf(Iterable<CatalogueWorld> worlds) => {for (final world in worlds) ...world.genres}.toList();

/// Worlds (P22d, P26d, P26t), the second tab: every world as a card, its people on it. Under `All` and
/// a chip per genre the list names, so a chip with no world cannot be drawn (call 41). One across on a
/// phone; a tablet's grid is two upright and three sideways.
class WorldsScreen extends ConsumerStatefulWidget {
  const WorldsScreen({this.genre, super.key});

  /// A genre by name: Search's cards open it here.
  final String? genre;

  @override
  ConsumerState<WorldsScreen> createState() => _WorldsScreenState();
}

class _WorldsScreenState extends ConsumerState<WorldsScreen> {
  late String? _genre = widget.genre;

  @override
  void didUpdateWidget(WorldsScreen old) {
    super.didUpdateWidget(old);
    if (widget.genre != old.genre) _genre = widget.genre;
  }

  @override
  Widget build(BuildContext context) {
    // Opening Worlds asks Arke's address for its list, at most once a day (P12 rule 1).
    ref.watch(catalogueRefreshProvider);
    final catalogue = (ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[]).where((world) => world.package != null).toList();
    final genres = genresOf(catalogue);
    final genre = genres.contains(_genre) ? _genre : null;
    final shown = catalogue.where((world) => genre == null || world.genres.contains(genre)).toList();
    final width = MediaQuery.sizeOf(context).width;
    final across = width >= WindowBands.wide
        ? 3
        : width >= WindowBands.fold
        ? 2
        : 1;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShelfHeader(
            title: 'Worlds',
            trailing: RoundPress(icon: Icons.search_rounded, label: 'Search', onPressed: () => context.go(Routes.search)),
          ),
          if (genres.isNotEmpty)
            LabelChips<String>(options: [for (final genre in genres) (genre, genre)], selected: genre, onSelect: (value) => setState(() => _genre = value)),
          Expanded(
            child: across == 1
                ? ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + footRoom(context)),
                    children: [
                      for (final world in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _Card(world: world),
                        ),
                    ],
                  )
                : GridView.count(
                    crossAxisCount: across,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 16 / 9,
                    padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + footRoom(context)),
                    children: [for (final world in shown) _Card(world: world, grid: true)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.world, this.grid = false});

  final CatalogueWorld world;
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(guideFetchProvider(world.id));
    final installed = ref.watch(libraryWorldsProvider).value ?? const <LibraryWorld>[];
    final held = installed.where((candidate) => world.covers(candidate.id)).firstOrNull;
    final update = held == null ? null : ref.watch(worldUpdateProvider(held.id));
    final state = ref.watch(installProvider(update?.id ?? world.id));
    final people = ref.watch(worldGuideProvider(held?.id ?? world.id)).value?.guide.characters.length;
    return WorldShelfCard(
      worldId: held?.id ?? world.id,
      name: world.name,
      line: state is Installing
          ? state.short
          : [...world.genres.take(1), titleCount(world.productions.length), if (people != null && people > 0) characterCount(people)].join(' · '),
      picture: ref.keyArtOf(world) ?? libraryPicture(ref.watch(libraryStoreProvider).value, held?.keyArt),
      age: world.age,
      tag: update != null && state is! Installing ? 'Update' : null,
      progress: state is Installing ? state.fraction : null,
      grid: grid,
      onOpen: () => context.push(Routes.worldsWorld(held?.id ?? world.id)),
    );
  }
}
