import 'dart:math' show max;

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../comics/application/comics.dart';
import '../../players/application/music.dart';
import '../../production/domain/production_kind.dart';
import '../../stories/application/stories.dart';
import '../application/found.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';
import 'production_screen.dart';
import 'row_widgets.dart';
import 'world_shelf.dart';
import 'world_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// A world's tabs (P22 rule 11).
enum WorldTab {
  story('Story'),
  people('People'),
  places('Places'),
  lore('Lore');

  const WorldTab(this.label);
  final String label;
}

/// A world's page (P22h – P22k, P22o). It leads with the world: its key art melting into its own blur,
/// its name, three of its people, its genre and titles, its age, its logline in two lines, one press
/// (P22 rule 3), and `Story · People · Places · Lore`, counted, an empty one absent. A world of one
/// title shows its chapters at once, because its page and that title's page are one (call 44). A newer
/// edition in Arke's list puts `Update` where the press was, with what it brings and the space it needs
/// (P12b – P12f). Space and the edition are in ⋯.
///
/// [location] is this page's own path, which a production's page and the guide's pages are pushed under.
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({required this.worldId, required this.location, super.key});

  final String worldId;
  final String location;

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  WorldTab _tab = WorldTab.story;

  @override
  Widget build(BuildContext context) {
    final worldId = widget.worldId;
    final location = widget.location;
    final installed = ref.watch(installedWorldProvider(worldId));
    // A world updated to a new id while its page was open (SPEC-058 R-30), or opened from an old
    // link: the page moves to the world's own address. Under the old one, a production opened from
    // here looked for a world that had gone and said Removed.
    if (installed != null && installed.id != worldId && location.endsWith('/$worldId')) {
      final moved = '${location.substring(0, location.length - worldId.length)}${installed.id}';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.replace(moved);
      });
    }
    // Opening a world's page asks Arke's address for its list, at most once a day (P12 rule 1), and
    // fetches its guide alone (SPEC-059 R-18).
    ref.watch(catalogueRefreshProvider);
    final id = installed?.id ?? worldId;
    ref.watch(guideFetchProvider(id));
    final catalogue = ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[];
    final listed = listedFor(catalogue, id) ?? catalogue.where((world) => world.id == worldId).firstOrNull;
    if (installed == null && listed == null) return const Scaffold(body: _Gone());
    final store = ref.watch(libraryStoreProvider).value;
    final name = installed?.name ?? listed!.name;
    // What the world holds, with what is still on its way (R-72), or what is here that the list no longer names.
    final titles = max(installed?.productions.length ?? 0, listed?.productions.length ?? 0);
    final picture = installed != null ? libraryPicture(store, installed.keyArt) : ref.keyArtOf(listed!);
    final guide = ref.watch(worldGuideProvider(id)).value?.guide;
    // What the reader has found, once the world is here and something in it waits (P23 rule 6).
    final reach = installed != null && guide != null && hasWaiting(guide) ? ref.watch(guideReachProvider(id)).value ?? GuideReach.none : null;
    final tabs = [
      (WorldTab.story, null),
      if (guide != null && guide.characters.isNotEmpty) (WorldTab.people, _countOf(guide.characters, reach)),
      if (guide != null && guide.places.isNotEmpty) (WorldTab.places, _countOf(guide.places, reach)),
      if (guide != null && guide.lore.isNotEmpty) (WorldTab.lore, _countOf(guide.lore, reach)),
    ];
    final tab = tabs.any((entry) => entry.$1 == _tab) ? _tab : WorldTab.story;
    final update = installed == null ? null : ref.watch(worldUpdateProvider(installed.id));
    final newer = update?.package;
    final updating = ref.watch(installProvider(update?.id ?? id));
    ref.listen(installProvider(update?.id ?? id), (previous, next) {
      if (next is InstallFailed && previous is! InstallFailed && update != null) showInstallRefusal(context, ref, update, next.refusal, updating: true);
    });
    final data = [...?listed?.genres.take(1), titleCount(titles)].join(' · ');

    void more() {
      if (installed != null) {
        showWorldMenu(context, ref, installed);
      } else {
        _showSpace(context, listed!);
      }
    }

    final header = _WorldHeader(
      worldId: id,
      name: name,
      data: data,
      age: listed?.age,
      logline: installed?.logline ?? listed?.logline,
      picture: picture,
      onMore: more,
      press: switch (updating) {
        Installing() when update != null => InstallProgress(state: updating, onCancel: () => ref.read(installProvider(update.id).notifier).cancel()),
        _ when update != null && newer != null => HeroPress(
          icon: Icons.download_rounded,
          label: 'Update',
          detail: formatBytes(newer.byteLength),
          onPressed: () async {
            if (!await mayOpen(context, ref, update, press: 'Update') || !context.mounted) return;
            await ref.read(installProvider(update.id).notifier).start(update);
          },
        ),
        _ => WorldPress(worldId: id, top: 12),
      },
      found: reach == null ? null : FoundLine(found: foundIn(entriesOf(guide!), reach), ink: _fg, top: 12),
    );
    void onTab(WorldTab value) => setState(() => _tab = value);
    final held = <Widget>[
      if (installed != null && newer != null) ...[const SizedBox(height: 16), _NewEdition(world: installed, newer: newer)],
      switch (tab) {
        WorldTab.story => installed != null ? _StoryHere(world: installed, location: location) : _StoryListed(world: listed!, location: location),
        WorldTab.people => PeoplePanel(worldId: id, location: location),
        WorldTab.places => PlacesPanel(worldId: id, location: location),
        WorldTab.lore => LorePanel(worldId: id, location: location),
      },
    ];
    // A tablet sideways: the world stays at the left, so Start and Continue never leave the screen on
    // any tab, and its tabs and what they hold scroll at the right (P26h, call 52).
    if (MediaQuery.sizeOf(context).width >= WindowBands.wide) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: WorldPane.width, child: header.asPane()),
            Expanded(
              child: SafeArea(
                left: false,
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WorldTabs(tabs: tabs, selected: tab, onSelect: onTab, ink: context.surface.foreground),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.only(bottom: footRoom(context)),
                        children: held,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: ScrolledHead(
        title: name,
        onMore: more,
        child: ListView(
          padding: EdgeInsets.only(bottom: footRoom(context)),
          children: [
            header.withTabs(_WorldTabs(tabs: tabs, selected: tab, onSelect: onTab)),
            ...held,
          ],
        ),
      ),
    );
  }
}

/// A tab's count: `14`, or `8 of 14` once there is something to find.
String _countOf(Iterable<GuideEntry> entries, GuideReach? reach) {
  if (reach == null) return '${entries.length}';
  final found = foundIn(entries, reach);
  return '${found.got} of ${found.of}';
}

/// Space and what it needs, in ⋯ before a world is here (P22 rule 11).
Future<void> _showSpace(BuildContext context, CatalogueWorld world) {
  final size = formatBytes(worldBytes(world));
  return showArkeSheet<void>(
    context,
    title: world.name,
    // Watched: nothing on a world's page has asked for the volume yet, so a read here finds it loading.
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final free = ref.watch(volumeProvider).value?.free;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GroupRow(label: 'Space', value: free == null ? size : '$size of ${formatBytes(free)} free'),
        );
      },
    ),
  );
}

/// What a newer edition brings (P12b): its date and size, and the space it needs.
class _NewEdition extends ConsumerWidget {
  const _NewEdition({required this.world, required this.newer});

  final LibraryWorld world;
  final CataloguePackage newer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final free = ref.watch(volumeProvider).value?.free;
    return GroupRows(
      rows: [
        (label: 'New edition', value: [if (newer.edition != null) editionLabel(newer.edition!), formatBytes(newer.byteLength)].join(' · ')),
        if (free != null)
          (
            label: 'Space',
            value:
                '${newer.byteLength >= world.byteLength ? '+' : '−'}${formatBytes((newer.byteLength - world.byteLength).abs())} of ${formatBytes(free)} free',
          ),
      ],
    );
  }
}

/// The top of a world's page (P22h, P22o): the key art melts into its own blur, and the tabs sit on that
/// blur, on the media colours whatever the theme. On a Fold or upright tablet the art is taller and the
/// words keep to the left, 560 wide.
class _WorldHeader extends StatelessWidget {
  const _WorldHeader({
    required this.worldId,
    required this.name,
    required this.data,
    required this.picture,
    required this.press,
    required this.onMore,
    this.tabs,
    this.age,
    this.logline,
    this.found,
  });

  final String worldId;
  final String name;
  final String data;
  final String? age;
  final String? logline;
  final ImageProvider? picture;
  final Widget press;
  final Widget? tabs;
  final VoidCallback onMore;
  final Widget? found;

  _WorldHeader withTabs(Widget tabs) => _WorldHeader(
    worldId: worldId,
    name: name,
    data: data,
    picture: picture,
    press: press,
    onMore: onMore,
    tabs: tabs,
    age: age,
    logline: logline,
    found: found,
  );

  /// Its picture and words at the left of a tablet sideways (P26h).
  Widget asPane() => Builder(
    builder: (context) => WorldPane(picture: picture, onMore: onMore, child: _words(context)),
  );

  Widget _words(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(name, style: text.headlineLarge?.copyWith(color: _fg)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            WorldFaces(worldId: worldId, gap: 8),
            Expanded(
              child: Text(
                data,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.84)),
              ),
            ),
            if (age != null) AgeTag(age!, color: _fg),
          ],
        ),
        if (logline != null) ...[
          const SizedBox(height: 9),
          Text(
            logline!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLarge?.copyWith(color: _fg.withValues(alpha: 0.88)),
          ),
        ],
        press,
        ?found,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    final artHeight = wide ? 520.0 : 300.0;
    return ColoredBox(
      color: _bg,
      child: Stack(
        children: [
          if (picture != null) Positioned.fill(child: BlurOf(picture: picture!)),
          if (picture != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: artHeight,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.52, 1],
                  colors: [Colors.black, Colors.transparent],
                ).createShader(bounds),
                child: Image(
                  image: picture!,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.2, 0),
                  errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 28 : 16, (wide ? 300.0 : 204.0).clamp(top + 110, double.infinity), wide ? 28 : 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 504 : double.infinity),
                    child: _words(context),
                  ),
                ),
              ),
              ?tabs,
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: top + 8,
            child: Row(
              children: [
                if (context.canPop()) GlassPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()),
                const Spacer(),
                GlassPress(icon: Icons.more_horiz, label: 'More', onPressed: onMore),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `Story · People · Places · Lore`, each with its count, an empty one absent (P22 rule 11).
class _WorldTabs extends StatelessWidget {
  const _WorldTabs({required this.tabs, required this.selected, required this.onSelect, this.ink = _fg});

  /// On a world's blur, the media colours; on a tablet's right pane, the theme's.
  final Color ink;

  final List<(WorldTab, String?)> tabs;
  final WorldTab selected;
  final ValueChanged<WorldTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ink.withValues(alpha: 0.14))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (tab, count) in tabs) ...[
              Semantics(
                button: true,
                selected: tab == selected,
                label: [tab.label, ?count].join(' '),
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: () => onSelect(tab),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: tab == selected ? ink : Colors.transparent, width: 2)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            tab.label,
                            style: text.bodyMedium?.copyWith(
                              fontSize: ArkeType.sizeBase,
                              fontWeight: tab == selected ? FontWeight.w600 : FontWeight.w500,
                              color: ink.withValues(alpha: tab == selected ? 1 : 0.68),
                            ),
                          ),
                          if (count != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              count,
                              style: text.labelSmall?.copyWith(color: ink.withValues(alpha: 0.6), fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// The shape a title's tile takes (P16 rule 1: a row is one shape).
enum _Shape { poster, wide, square }

/// More titles than this and they group as `Listen · Music · Watch · Play · Read` (P22 rule 12).
const _ungrouped = 6;

/// A world's titles under Story, before it is here: posters, each with its kind. Nothing opens before it
/// is here (P9 rule 3), but a graphic novel opens its own page, with Get (P21 call 35).
class _StoryListed extends ConsumerWidget {
  const _StoryListed({required this.world, required this.location});

  final CatalogueWorld world;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(CatalogueProduction production, double width, _Shape shape) {
      // A story this Player cannot play is shown, and never fetched (R-82), whichever row it is in.
      final tag = production.needsNewerApp ? 'Update app' : null;
      final picture = ref.pictureOf(world, production);
      return switch (shape) {
        _Shape.poster => PosterTile(
          title: production.title,
          kind: production.kind,
          tall: ref.tallOf(production),
          wide: picture,
          width: width,
          tag: tag,
          onOpen: tag == null && production.comic != null && production.alone != null && production.id != null
              ? () => context.push(Routes.production(location, production.id!))
              : null,
        ),
        _Shape.square => SquareTile(title: production.title, kind: production.kind, picture: picture, width: width, tag: tag, onOpen: null),
        _Shape.wide => ProductionTile(title: production.title, kind: production.kind, picture: picture, width: width, tag: tag, onOpen: null),
      };
    }

    return _Titles<CatalogueProduction>(
      titles: world.productions,
      kindOf: (production) => production.music != null ? ProductionKind.ofMusic(production.music!.name) : ProductionKind.ofLine(production.kind),
      tile: tile,
    );
  }
}

/// A world's titles under Story, once it is here: a world of one title its chapters at once (call 44),
/// else posters, each opening its page, one with a chapter not yet opened marked `New` (R-52).
class _StoryHere extends ConsumerWidget {
  const _StoryHere({required this.world, required this.location});

  final LibraryWorld world;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(libraryStoreProvider).value;
    final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};
    final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], world.id);
    // A production published on its own and not on the phone yet still shows, opening nothing until
    // it arrives (SPEC-058 R-72, R-73, R-83); so does a story this Player cannot play, with `Update
    // app`, never fetched (R-82).
    final coming = [
      if (listed != null) ...missingProductions(listed, world).where((production) => installedProduction(production, world) == null),
      for (final production in listed?.productions ?? const <CatalogueProduction>[])
        if (production.needsNewerApp && installedProduction(production, world) == null) production,
    ];
    final titles = <Object>[...world.productions, ...coming];
    // On the phone alone: a world whose one title is still on its way has nothing of it to show yet.
    if (titles.length == 1 &&
        world.productions.length == 1 &&
        world.productions.single.story == null &&
        world.productions.single.comic == null &&
        world.productions.single.music == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: ProductionContents(world: world, production: world.productions.single, worldLocation: location),
      );
    }

    Widget tile(Object entry, double width, _Shape shape) {
      // Whatever a title is, its row's shape draws it (P16 rule 1). The package carries no Tall cover yet:
      // the list's, fetched with it or bundled with the app, is the one there is.
      Widget drawn(String title, String kind, ImageProvider? picture, {ImageProvider? tall, String? tag, bool fresh = false, VoidCallback? onOpen}) =>
          switch (shape) {
            _Shape.poster => PosterTile(title: title, kind: kind, tall: tall, wide: picture, width: width, tag: tag, fresh: fresh, onOpen: onOpen),
            _Shape.square => SquareTile(title: title, kind: kind, picture: picture, width: width, tag: tag, onOpen: onOpen),
            _Shape.wide => ProductionTile(title: title, kind: kind, picture: picture, width: width, tag: tag, fresh: fresh, onOpen: onOpen),
          };
      if (entry is CatalogueProduction) {
        return drawn(
          entry.title,
          entry.kind,
          listed == null ? null : ref.pictureOf(listed, entry),
          tall: ref.tallOf(entry),
          tag: entry.needsNewerApp ? 'Update app' : null,
        );
      }
      final production = entry as LibraryProduction;
      void open() => context.push(Routes.production(location, production.id));
      final inList = listed?.productions.where((candidate) => candidate.id == production.id || candidate.title == production.title).firstOrNull;
      final picture = libraryPicture(store, production.picture ?? world.keyArt);
      String? update() => ref.watch(productionUpdateProvider((world.id, production.id))) != null ? 'Update' : null;
      if (production.story case final story?) {
        return drawn(production.title, storyTileKind(story), picture, tall: ref.tallOf(inList), tag: update(), onOpen: open);
      }
      if (production.comic case final comic?) {
        final tall = ref.tallOf(inList) ?? ref.watch(comicFirstPageProvider((world.id, production.id)));
        return drawn(production.title, comicTileKind(comic), picture, tall: tall, tag: update(), onOpen: open);
      }
      if (production.music case final music?) {
        return drawn(
          production.title,
          musicTileKind(music.kind, tracks: music.tracks, length: music.duration),
          picture,
          tag: update(),
          onOpen: open,
        );
      }
      final narration = items[production.narration];
      return drawn(
        production.title,
        productionKind(book: production.book != null, narration: production.narration != null, length: narration?.duration),
        libraryPicture(store, production.picture ?? narration?.cover ?? items[production.book]?.cover ?? world.keyArt),
        tall: ref.tallOf(inList),
        fresh: newChapters(world, production.id, narration).isNotEmpty,
        onOpen: open,
      );
    }

    return _Titles<Object>(
      titles: titles,
      kindOf: (production) => switch (production) {
        CatalogueProduction(:final music?) => ProductionKind.ofMusic(music.name),
        CatalogueProduction(:final kind) => ProductionKind.ofLine(kind),
        LibraryProduction(:final music?) => ProductionKind.ofMusic(music.kind),
        LibraryProduction(story: LibraryStory(kind: 'novel')) => ProductionKind.visualNovel,
        LibraryProduction(story: _?) => ProductionKind.interactiveMovie,
        LibraryProduction(comic: _?) => ProductionKind.graphicNovel,
        LibraryProduction(:final narration) => narration != null ? ProductionKind.audiobook : ProductionKind.book,
        _ => ProductionKind.book,
      },
      tile: tile,
    );
  }
}

/// A world's titles (P22 rule 12): up to six in one row of posters, music as squares; past that, under
/// `Listen · Music · Watch · Play · Read`, each head with its count (P15 rule 3, P17 rule 2).
class _Titles<T> extends StatelessWidget {
  const _Titles({required this.titles, required this.kindOf, required this.tile});

  final List<T> titles;
  final ProductionKind Function(T) kindOf;
  final Widget Function(T production, double width, _Shape shape) tile;

  @override
  Widget build(BuildContext context) {
    if (titles.length <= _ungrouped) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        child: TileRow(
          children: [
            for (final title in titles)
              kindOf(title).takenAs == TakenAs.music
                  ? tile(title, RowSizes.square(context), _Shape.square)
                  : tile(title, RowSizes.poster(context), _Shape.poster),
          ],
        ),
      );
    }
    final groups = groupByTakenAs(titles, kindOf);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final MapEntry(key: takenAs, value: productions) in groups.entries) ...[
            CountHead(title: takenAs.label, count: productions.length),
            if (takenAs == TakenAs.listen || takenAs == TakenAs.read)
              TileRow(children: [for (final production in productions) tile(production, RowSizes.poster(context), _Shape.poster)])
            else if (takenAs == TakenAs.music)
              TileRow(children: [for (final production in productions) tile(production, RowSizes.square(context), _Shape.square)])
            else
              TileRow(children: [for (final production in productions) tile(production, rowTileWidth(context), _Shape.wide)]),
          ],
        ],
      ),
    );
  }
}

/// Once the hero has scrolled away, a head in the shelf's colours with back, the world's name and
/// ⋯ (P11c, P11i), so the guide never runs under the status bar.
class ScrolledHead extends StatefulWidget {
  const ScrolledHead({required this.title, required this.child, this.onMore, super.key});

  final String title;
  final VoidCallback? onMore;
  final Widget child;

  @override
  State<ScrolledHead> createState() => _ScrolledHeadState();
}

class _ScrolledHeadState extends State<ScrolledHead> {
  /// About where the hero's title passes under the head.
  static const _after = 240.0;
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Stack(
      children: [
        NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            final shown = notification.depth == 0 && notification.metrics.axis == Axis.vertical && notification.metrics.pixels > _after;
            if (notification.depth == 0 && notification.metrics.axis == Axis.vertical && shown != _shown) setState(() => _shown = shown);
            return false;
          },
          child: widget.child,
        ),
        if (_shown)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ColoredBox(
              color: surface.background,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Row(
                    children: [
                      if (context.canPop()) RoundPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (widget.onMore != null) RoundPress(icon: Icons.more_horiz, label: 'More', onPressed: widget.onMore!),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The world is in neither the library nor the list: removed, or a link from an older build.
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (context.canPop()) IconButton(onPressed: () => context.pop(), tooltip: 'Back', icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Center(
            child: Text('Not available', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.surface.mutedForeground)),
          ),
        ),
      ],
    ),
  );
}
