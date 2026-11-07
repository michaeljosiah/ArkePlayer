import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/app/widgets/shelf.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/search.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/guide_screens.dart';
import 'package:arke_player/features/worlds/presentation/row_widgets.dart';
import 'package:arke_player/features/worlds/presentation/search_screen.dart';
import 'package:arke_player/features/worlds/presentation/world_shelf.dart';
import 'package:arke_player/features/worlds/presentation/worlds_screen.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// P22 rule 10, call 43: Search runs on the phone over Arke's list and each world's guide, with no
// account, and never finds what still waits for a chapter.

const _ledger = 'the-ledger-of-nights';
const _sixth = GuideAfter(production: _ledger, chapter: 'ch6', number: 6);

const _guide = Guide(
  productions: [
    GuideProduction(
      id: _ledger,
      title: 'The Ledger of Nights',
      chapters: [
        GuideChapter(id: 'ch1', number: 1),
        GuideChapter(id: 'ch6', number: 6),
      ],
    ),
  ],
  characters: [
    GuideCharacter(id: 'adeyemi', name: 'Ola Adeyemi', role: 'Clerk', portrait: 'char-maren.jpg', sections: []),
    GuideCharacter(id: 'the-chorister', name: 'The Chorister', portrait: 'char-chorister.jpg', after: _sixth, sections: []),
  ],
  places: [
    GuidePlace(id: 'ades-house', name: 'Ade’s House', role: 'Lodging', sections: []),
    GuidePlace(id: 'the-arcade', name: 'The Arcade', sections: []),
    GuidePlace(id: 'the-weir', name: 'The Weir', after: _sixth, sections: []),
  ],
  lore: [
    GuideLore(id: 'canon-1', kind: LoreKind.lore, title: 'The Drowned God', text: 'Still singing.'),
    GuideLore(id: 'canon-2', kind: LoreKind.timeline, title: 'The Long Neap', text: 'A year.', after: _sixth),
  ],
);

final _package = CataloguePackage(url: Uri.parse('https://example.org/world.zip'), byteLength: 386000000, sha256: 'a' * 64);

final _undersong = CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  genres: const ['Horror', 'Mystery'],
  age: '16+',
  productions: const [CatalogueProduction(id: _ledger, title: 'The Ledger of Nights', kind: 'Audiobook · Book · 2 h 03 m')],
  package: _package,
);

final _dumah = CatalogueWorld(
  id: 'legend-of-dumah',
  name: 'Legend of Dumah',
  genres: const ['Mystery'],
  productions: const [CatalogueProduction(id: 'whispers', title: 'Whispers from the Void', kind: 'Audiobook · 4 chapters')],
  package: _package,
);

SearchChapter _chapter(int number, String title) =>
    (world: _undersong, production: _ledger, productionTitle: 'The Ledger of Nights', number: number, title: title);

List<String> _found(List<SearchHit> hits) => [for (final hit in hits) hit.title];

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  List<CatalogueWorld>? catalogue,
  List<LibraryWorld> worlds = const [],
  List<LibraryItem> items = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // A test may pump twice: each pump is a fresh app.
      key: UniqueKey(),
      overrides: [
        libraryItemsProvider.overrideWith((ref) => Stream.value(items)),
        libraryWorldsProvider.overrideWith((ref) => Stream.value(worlds)),
        catalogueProvider.overrideWith((ref) async => catalogue ?? [_undersong, _dumah]),
        catalogueRefreshProvider.overrideWith((ref) async {}),
        worldGuideProvider.overrideWith((ref, worldId) async => worldId == 'undersong' ? WorldGuide(guide: _guide, pathOf: (asset) => 'missing/$asset') : null),
        guideFetchProvider.overrideWith((ref, worldId) async {}),
        guideReachProvider.overrideWith((ref, worldId) async => GuideReach.none),
      ],
      child: MaterialApp.router(
        theme: arkeTheme(Brightness.light),
        routerConfig: buildRouter(initialLocation: location),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
}

void main() {
  group('searchWorlds', () {
    final guides = <String, SearchGuide>{'undersong': (guide: _guide, reach: GuideReach.none)};

    test('a word of a name has to begin with what is typed: ade finds Adeyemi and Ade’s House, never Arcade', () {
      expect(_found(searchWorlds('ade', [_undersong], guides)), ['Ola Adeyemi', 'Ade’s House']);
      expect(_found(searchWorlds('ADE', [_undersong], guides)), ['Ola Adeyemi', 'Ade’s House'], reason: 'whatever its case');
      expect(_found(searchWorlds('  ade ', [_undersong], guides)), ['Ola Adeyemi', 'Ade’s House'], reason: 'with the spaces around it gone');
      expect(_found(searchWorlds('arc', [_undersong], guides)), ['The Arcade']);
    });

    test('what is typed is read as words, never as a pattern', () {
      expect(searchWorlds('ad.', [_undersong], guides), isEmpty);
      expect(searchWorlds('(', [_undersong], guides), isEmpty);
      expect(searchWorlds('[a', [_undersong], guides), isEmpty);
    });

    test('nothing typed finds nothing', () {
      expect(searchWorlds('', [_undersong], guides), isEmpty);
      expect(searchWorlds('   ', [_undersong], guides), isEmpty);
    });

    test('an entry waiting for a chapter is not found until it is reached or revealed', () {
      List<String> found(GuideReach reach) => [
        for (final query in ['chorister', 'weir', 'neap']) ..._found(searchWorlds(query, [_undersong], {'undersong': (guide: _guide, reach: reach)})),
      ];
      expect(found(GuideReach.none), isEmpty);
      expect(found(const GuideReach(reached: {_ledger: (at: 5, through: 5)})), isEmpty, reason: 'a chapter short of it');
      expect(found(const GuideReach(reached: {_ledger: (at: 6, through: 6)})), ['The Chorister', 'The Weir', 'The Long Neap']);
      expect(found(const GuideReach(revealed: {_ledger: 6})), ['The Chorister', 'The Weir', 'The Long Neap']);
    });

    test('a world with no guide on the phone is found by its list alone', () {
      expect(_found(searchWorlds('und', [_undersong], const {})), ['The Undersong']);
      expect(searchWorlds('ade', [_undersong], const {}), isEmpty);
    });

    test('chapters come only from the chapters it is given', () {
      expect(searchWorlds('tenth', [_undersong], guides), isEmpty);
      final hits = searchWorlds('tenth', [_undersong], guides, chapters: [_chapter(2, 'The Weir Gate'), _chapter(3, 'The Tenth Key')]);
      final hit = hits.single;
      expect((hit.kind, hit.title, hit.line, hit.production), (SearchKind.chapter, 'The Tenth Key', 'Chapter 3 · The Ledger of Nights', _ledger));
    });

    test('its groups: worlds, titles, characters, places, lore, chapters, whichever world found them', () {
      const salty = Guide(
        productions: [],
        characters: [GuideCharacter(id: 'c', name: 'Salt Annie', role: 'Rigger', sections: [])],
        places: [GuidePlace(id: 'p', name: 'Salt Flats', sections: [])],
        lore: [GuideLore(id: 'l', kind: LoreKind.lore, title: 'Salt Law', text: 'Law.')],
      );
      final first = CatalogueWorld(
        id: 'first',
        name: 'Tide',
        genres: const ['Horror'],
        productions: const [CatalogueProduction(id: 't', title: 'Salt Ledger', kind: 'Book')],
        package: _package,
      );
      final second = CatalogueWorld(id: 'second', name: 'Saltmouth', genres: const ['Mystery'], age: '18+', productions: const [], package: _package);
      final hits = searchWorlds(
        'salt',
        [first, second],
        {'first': (guide: salty, reach: GuideReach.none)},
        chapters: [(world: first, production: 't', productionTitle: 'Salt Ledger', number: 1, title: 'Salt Water')],
      );
      expect([for (final hit in hits) hit.kind], SearchKind.values);
      expect([for (final kind in SearchKind.values) kind.heading], ['Worlds', 'Titles', 'Characters', 'Places', 'Lore', 'Chapters']);
      // Each says where it is, in data only.
      expect([for (final hit in hits) hit.line], ['Mystery · 18+', 'Tide', 'Rigger · Tide', 'Place · Tide', 'Tide', 'Chapter 1 · Salt Ledger']);
      expect([for (final hit in hits) hit.entry?.id], [null, null, 'c', 'p', 'l', null]);
    });
  });

  group('the screen (P22f, P22g)', () {
    testWidgets('Home’s Search and Worlds’ both open it', (tester) async {
      await _pump(tester, location: Routes.home);
      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);

      await _pump(tester, location: Routes.worlds);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('empty, its Genres and Characters; none who waits for a chapter (P22f)', (tester) async {
      await _pump(tester, location: Routes.search);
      expect(find.text('Genres'), findsOneWidget);
      expect(find.text('Horror'), findsOneWidget);
      expect(find.text('Mystery'), findsOneWidget);
      expect(find.text('1 world'), findsOneWidget);
      expect(find.text('2 worlds'), findsOneWidget);
      expect(find.text('Characters'), findsOneWidget);
      expect(find.ancestor(of: find.text('Ola Adeyemi'), matching: find.byType(PosterTile)), findsOneWidget);
      expect(find.text('The Chorister'), findsNothing);
      expect(find.byType(SectionHead), findsNWidgets(2));
    });

    testWidgets('a genre’s card opens Worlds under that genre', (tester) async {
      await _pump(tester, location: Routes.search);
      await tester.tap(find.text('Horror'));
      await tester.pumpAndSettle();
      expect(find.byType(WorldsScreen), findsOneWidget);
      expect(find.byType(WorldShelfCard), findsOneWidget);
      expect(find.text('The Undersong'), findsOneWidget);
    });

    testWidgets('typed, what it found by kind, and the empty state gone (P22g)', (tester) async {
      await _pump(tester, location: Routes.search);
      await _type(tester, 'the');
      expect([for (final head in tester.widgetList<SectionHead>(find.byType(SectionHead))) head.title], ['Worlds', 'Titles', 'Places', 'Lore']);
      expect(find.text('Genres'), findsNothing);
      expect(find.text('Horror · 16+'), findsOneWidget);
      expect(find.text('The Ledger of Nights'), findsOneWidget);
      expect(find.text('The Arcade'), findsOneWidget);
      expect(find.text('The Drowned God'), findsOneWidget);
      expect(find.text('The Weir'), findsNothing, reason: 'it waits for chapter 6');
      expect(find.text('The Chorister'), findsNothing);

      await _type(tester, 'zzz');
      expect(find.text('Nothing found'), findsOneWidget);
    });

    testWidgets('Clear empties it, and the genres come back', (tester) async {
      await _pump(tester, location: Routes.search);
      await _type(tester, 'ade');
      expect(find.text('Ola Adeyemi'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Genres'), findsOneWidget);
    });

    testWidgets('a world here is searched by its chapters too', (tester) async {
      final installed = LibraryWorld(
        id: 'undersong',
        edition: '2026-10-21',
        name: 'The Undersong',
        byteLength: 386000000,
        installedAt: DateTime.utc(2026, 10, 21),
        productions: const [LibraryProduction(id: _ledger, title: 'The Ledger of Nights', narration: 'narration')],
      );
      final narration = LibraryItem(
        id: 'narration',
        format: FileFormat.m4b,
        title: 'The Ledger of Nights',
        byteLength: 120000000,
        addedAt: DateTime.utc(2026, 10, 21),
        file: 'worlds/undersong/narration.m4b',
        chapters: const [
          Chapter(title: 'The Weigh House', start: Duration.zero),
          Chapter(title: 'The Tenth Key', start: Duration(minutes: 21)),
        ],
        worldId: 'undersong',
      );
      await _pump(tester, location: Routes.search);
      await _type(tester, 'tenth');
      expect(find.text('Nothing found'), findsOneWidget, reason: 'a guide knows its chapters by number alone');

      await _pump(tester, location: Routes.search, worlds: [installed], items: [narration]);
      await _type(tester, 'tenth');
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('Chapter 2 · The Ledger of Nights'), findsOneWidget);
    });

    testWidgets('a hit opens its entry', (tester) async {
      await _pump(tester, location: Routes.search);
      await _type(tester, 'ade');
      await tester.tap(find.text('Ola Adeyemi'));
      await tester.pumpAndSettle();
      expect(find.byType(GuideEntryScreen), findsOneWidget);
      expect(tester.widget<GuideEntryScreen>(find.byType(GuideEntryScreen)).entryId, 'adeyemi');
    });
  });
}
