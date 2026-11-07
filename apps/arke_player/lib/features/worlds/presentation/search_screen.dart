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
import '../application/search.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';
import 'row_widgets.dart';
import 'world_widgets.dart';
import 'worlds_screen.dart';

/// Search (P22f, P22g, P26f, P26g, call 43): a field over Arke's list and each world's guide, read on the
/// phone with no account. Empty, its genres and characters. Typed, what it found by kind: down a phone,
/// a column for each kind on a tablet sideways.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = (ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[]).where((world) => world.package != null).toList();
    final guides = <String, SearchGuide>{};
    final pictures = <String, WorldGuide>{};
    final installed = ref.watch(libraryWorldsProvider).value ?? const <LibraryWorld>[];
    for (final world in catalogue) {
      ref.watch(guideFetchProvider(world.id));
      final id = installed.where((held) => world.covers(held.id)).firstOrNull?.id ?? world.id;
      if (ref.watch(worldGuideProvider(id)).value case final guide?) {
        guides[world.id] = (guide: guide.guide, reach: ref.watch(guideReachProvider(id)).value ?? GuideReach.none);
        pictures[world.id] = guide;
      }
    }
    final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};
    final chapters = <SearchChapter>[
      for (final held in installed)
        if (listedFor(catalogue, held.id) case final world?)
          for (final production in held.productions)
            for (final (index, chapter) in (items[production.narration]?.chapters ?? const <Chapter>[]).indexed)
              (world: world, production: production.id, productionTitle: production.title, number: index + 1, title: chapter.title),
    ];
    final hits = searchWorlds(_field.text, catalogue, guides, chapters: chapters);
    final typed = _field.text.trim().isNotEmpty;
    final store = ref.watch(libraryStoreProvider).value;

    ImageProvider? pictureOf(SearchHit hit) {
      final guide = pictures[hit.world.id];
      if (hit.entry case final entry? when guide != null) return guidePicture(guide, entry);
      if (hit.kind == SearchKind.title) {
        return ref.tallOf(hit.world.productions.where((production) => production.id == hit.production).firstOrNull) ?? ref.keyArtOf(hit.world);
      }
      final held = installed.where((candidate) => hit.world.covers(candidate.id)).firstOrNull;
      return ref.keyArtOf(hit.world) ?? libraryPicture(store, held?.keyArt);
    }

    void open(SearchHit hit) {
      final id = installed.where((held) => hit.world.covers(held.id)).firstOrNull?.id ?? hit.world.id;
      final page = Routes.worldsWorld(id);
      if (hit.entry case final entry?) {
        context.push(Routes.guideEntry(page, entry.id));
      } else {
        context.push(page);
      }
    }

    final groups = {
      for (final kind in SearchKind.values)
        if (hits.any((hit) => hit.kind == kind)) kind: hits.where((hit) => hit.kind == kind).toList(),
    };
    Widget group(SearchKind kind, List<SearchHit> found) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(kind.heading),
        for (final hit in found) _HitRow(hit: hit, picture: pictureOf(hit), onOpen: () => open(hit)),
      ],
    );
    final sideways = MediaQuery.sizeOf(context).width >= WindowBands.wide;
    final bottom = 24 + footRoom(context);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                if (context.canPop()) ...[
                  RoundPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextField(
                    controller: _field,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      isDense: true,
                      filled: true,
                      fillColor: context.surface.secondary,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: typed
                          ? IconButton(onPressed: () => setState(_field.clear), tooltip: 'Clear', icon: const Icon(Icons.close_rounded, size: 18))
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ArkeRadius.pill), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: !typed
                ? _Empty(catalogue: catalogue, guides: pictures, bottom: bottom)
                : hits.isEmpty
                ? Align(
                    alignment: const Alignment(0, -0.5),
                    child: Text('Nothing found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.surface.mutedForeground)),
                  )
                : ListView(
                    padding: EdgeInsets.only(bottom: bottom),
                    children: sideways
                        ? [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final MapEntry(key: kind, value: found) in groups.entries) Expanded(child: group(kind, found)),
                                for (var i = groups.length; i < 3; i++) const Spacer(),
                              ],
                            ),
                          ]
                        : [for (final MapEntry(key: kind, value: found) in groups.entries) group(kind, found)],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A hit: its picture, its name, a line of data.
class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.picture, required this.onOpen});

  final SearchHit hit;
  final ImageProvider? picture;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ArkeRadius.md),
              child: SizedBox(
                width: 48,
                height: 60,
                child: picture == null
                    ? ColoredBox(color: surface.secondary)
                    : Image(
                        image: picture!,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.6),
                        errorBuilder: (context, error, stack) => ColoredBox(color: surface.secondary),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hit.line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: surface.mutedForeground),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: surface.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// Nothing typed yet (P22f): the genres as cards, then characters from across the worlds, none of whom
/// waits for a chapter.
class _Empty extends ConsumerWidget {
  const _Empty({required this.catalogue, required this.guides, required this.bottom});

  final List<CatalogueWorld> catalogue;
  final Map<String, WorldGuide> guides;
  final double bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres = genresOf(catalogue);
    final installed = ref.watch(libraryWorldsProvider).value ?? const <LibraryWorld>[];
    final width = MediaQuery.sizeOf(context).width;
    final across = width >= WindowBands.fold ? 4 : 2;
    final characters = [
      for (final world in catalogue)
        if (guides[world.id] case final guide?)
          for (final character in guide.guide.characters.where((character) => character.after == null && character.portrait != null).take(2))
            (world: world, guide: guide, character: character),
    ];
    return ListView(
      padding: EdgeInsets.only(bottom: bottom),
      children: [
        if (genres.isNotEmpty) ...[
          const SectionHead('Genres'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: across,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 173 / 96,
              children: [
                for (final genre in genres)
                  _GenreCard(
                    genre: genre,
                    worlds: catalogue.where((world) => world.genres.contains(genre)).toList(),
                    onOpen: () => context.go(Uri(path: Routes.worlds, queryParameters: {'genre': genre}).toString()),
                  ),
              ],
            ),
          ),
        ],
        if (characters.isNotEmpty) ...[
          const SectionHead('Characters'),
          TileRow(
            children: [
              for (final (:world, :guide, :character) in characters)
                PosterTile(
                  title: character.name,
                  kind: world.name,
                  tall: guidePicture(guide, character),
                  pictureAlignment: const Alignment(0, -0.6),
                  width: RowSizes.small(context),
                  onOpen: () => context.push(
                    Routes.guideEntry(Routes.worldsWorld(installed.where((held) => world.covers(held.id)).firstOrNull?.id ?? world.id), character.id),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GenreCard extends ConsumerWidget {
  const _GenreCard({required this.genre, required this.worlds, required this.onOpen});

  final String genre;
  final List<CatalogueWorld> worlds;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fg = ArkeColors.mediaOverlayForeground;
    final text = Theme.of(context).textTheme;
    final picture = ref.keyArtOf(worlds.first);
    return Semantics(
      button: true,
      label: '$genre, ${worlds.length}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ArkeRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (picture != null)
                  Image(image: picture, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const SizedBox.shrink())
                else
                  const ColoredBox(color: ArkeColors.neutral800),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xE00A0A0A), Color(0x000A0A0A)],
                      stops: [0, 0.8],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(genre, style: text.titleMedium?.copyWith(color: fg)),
                      Text(worlds.length == 1 ? '1 world' : '${worlds.length} worlds', style: text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.78))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
