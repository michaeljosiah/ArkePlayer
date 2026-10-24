import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/shell/adaptive_shell.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/guide_widgets.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// SPEC-059's shared fixtures, as arke_world and ArkeStudio's contracts read them.
final _fixtures = '${Directory.current.path}/../../packages/arke_world/test/fixtures/guide';
String _fixture(String name) => File('$_fixtures/$name').readAsStringSync();

Map<String, WorldAsset> _assets() => {
  for (final MapEntry(:key, value: raw) in (jsonDecode(_fixture('assets.json')) as Map<String, Object?>).entries)
    if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
      key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
};

final _guide = (readGuide(_fixture('valid.json'), _assets()) as GuideOk).guide;

/// Scrolls the page until [target] is in view: under Discover's feature (P16a), Worlds is further
/// down.
Future<void> _down(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(target, 300, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
const _ledger = 'the-ledger-of-nights';

final _undersong = CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  productions: const [CatalogueProduction(title: 'The Ledger of Nights', kind: 'Book')],
  package: CataloguePackage(url: Uri.parse('https://example.org/undersong.zip'), byteLength: 386000000, sha256: 'a' * 64),
);
final _installed = LibraryWorld(
  id: 'undersong',
  edition: '2026-10-22',
  name: 'The Undersong',
  byteLength: 386000000,
  installedAt: DateTime.utc(2026, 10, 22),
  productions: const [LibraryProduction(id: _ledger, title: 'The Ledger of Nights', book: 'undersong.book')],
  guide: 'worlds/undersong/guide/guide.json',
);

/// A store that keeps what is revealed in memory, as the widget tests' clock cannot wait on a file.
class _Store extends LibraryStore {
  _Store() : super(Directory.systemTemp);

  final revealedNow = <(String, String, int)>[];

  @override
  Future<void> reveal(String worldId, String productionId, int number) async => revealedNow.add((worldId, productionId, number));
}

class _NoStorage implements StorageInfo {
  const _NoStorage();
  @override
  Future<int?> freeBytes(String path) async => null;
  @override
  Future<int?> totalBytes(String path) async => null;
}

Future<_Store> _pump(
  WidgetTester tester, {
  required String location,
  bool installed = true,
  Guide? guide,
  GuideReach reach = GuideReach.none,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = _Store();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryStoreProvider.overrideWith((ref) async => store),
        libraryItemsProvider.overrideWith((ref) => Stream.value(const [])),
        libraryWorldsProvider.overrideWith((ref) => Stream.value(installed ? [_installed] : const [])),
        catalogueProvider.overrideWith((ref) async => [_undersong]),
        volumeProvider.overrideWith((ref) async => (free: 41000000000, total: 128000000000)),
        worldGuideProvider.overrideWith((ref, worldId) async => guide == null ? null : WorldGuide(guide: guide, pathOf: (assetId) => 'missing/$assetId')),
        guideFetchProvider.overrideWith((ref, worldId) async {}),
        guideReachProvider.overrideWith((ref, worldId) async => reach),
      ],
      child: MaterialApp.router(
        theme: arkeTheme(Brightness.light),
        routerConfig: buildRouter(initialLocation: location),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// A world package over the shared fixtures, every file's digest true: the guide alone, or with
/// [book] a full package carrying a book and the guide.
List<int> _package({List<int>? book}) {
  final files = <String, List<int>>{
    'the-ledger-of-nights/book.epub': ?book,
    'guide/guide.json': utf8.encode(_fixture('valid.json')),
    'guide/maren-kest.jpg': [0xFF, 0xD8, 0xFF, 0xD9],
    'guide/bray-half-hitch.png': [0x89, 0x50, 0x4E, 0x47],
    'guide/the-vigil.jpg': [0xFF, 0xD8, 0xFF, 0xDA, 0xFF, 0xD9],
    'guide/maren-kest.m4a': [0, 0, 0, 8, 0x66, 0x74, 0x79, 0x70],
  };
  final world = jsonDecode(_fixture(book == null ? 'world-guide-alone.json' : 'world-guide-and-book.json')) as Map<String, Object?>;
  final assets = (world['assets']! as Map<String, Object?>)..remove('key-art');
  world.remove('keyArt');
  for (final asset in assets.values.cast<Map<String, Object?>>()) {
    final content = files[asset['path']]!;
    asset['byteLength'] = content.length;
    asset['sha256'] = sha256.convert(content).toString();
  }
  final archive = Archive()..add(ArchiveFile.bytes('world.json', utf8.encode(jsonEncode(world)))..compression = CompressionType.none);
  for (final MapEntry(:key, :value) in files.entries) {
    archive.add(ArchiveFile.bytes(key, value)..compression = CompressionType.none);
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  final world = Routes.discoverWorld('undersong');

  group('Discover (P11a, as P15 rule 1 amends it)', () {
    testWidgets('is the second of five tabs', (tester) async {
      await _pump(tester, location: Routes.discover, guide: _guide);
      expect(TabPill.labels, ['Home', 'Discover', 'Library', 'Downloads', 'You']);
      expect(tester.widget<TabPill>(find.byType(TabPill)).selected, 1);
    });
    testWidgets('an installed world stays, In Library counting the productions and the characters', (tester) async {
      await _pump(tester, location: Routes.discover, guide: _guide);
      await _down(tester, find.text('In Library · 1 production · 3 characters'));
      expect(find.text('In Library · 1 production · 3 characters'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
    });
    testWidgets('Available adds the size, and the characters once the guide is here', (tester) async {
      await _pump(tester, location: Routes.discover, installed: false, guide: _guide);
      await _down(tester, find.text('1 production · 3 characters · 386 MB'));
      expect(find.text('1 production · 3 characters · 386 MB'), findsOneWidget);
    });
  });

  group('a world\'s guide on its page (P11b, P11c)', () {
    testWidgets('Characters, Places and Lore, each with its count; what waits for a chapter after what shows', (tester) async {
      await _pump(tester, location: world, guide: _guide);
      await tester.scrollUntilVisible(find.text('Lore'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('Characters'), findsOneWidget);
      expect(find.text('Maren Kest'), findsOneWidget);
      expect(find.text('Places'), findsOneWidget);
      expect(find.text('The Vigil'), findsOneWidget);
      // The Chorister and the drowning of the god wait for chapter 6.
      expect(find.text('The Chorister'), findsNothing);
      expect(find.text('After Chapter 6'), findsNWidgets(2));
      expect(find.text('Reveal'), findsOneWidget);
    });
    testWidgets('before install, from the guide alone (R-10)', (tester) async {
      await _pump(tester, location: world, installed: false, guide: _guide);
      expect(find.textContaining('Install'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Characters'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('Characters'), findsOneWidget);
    });
    testWidgets('a world with no guide, or one never fetched offline, draws none (R-22)', (tester) async {
      await _pump(tester, location: world, installed: false);
      await tester.scrollUntilVisible(find.text('Space'), 300, scrollable: find.byType(Scrollable).last);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Characters'), findsNothing);
      expect(find.text('Lore'), findsNothing);
    });
    testWidgets('a chapter reached shows what waited for it', (tester) async {
      await _pump(
        tester,
        location: world,
        guide: _guide,
        reach: const GuideReach(reached: {_ledger: (at: 6, through: 6)}),
      );
      await tester.scrollUntilVisible(find.text('Lore'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('The Chorister'), findsOneWidget);
      expect(find.text('After Chapter 6'), findsNothing);
    });
  });

  group('a character (P11d) and Reveal (P11h)', () {
    testWidgets('portrait, role · world, Voice with its length, the sections, With', (tester) async {
      await _pump(tester, location: Routes.guideEntry(world, 'maren-kest'), guide: _guide);
      expect(find.text('Maren Kest'), findsOneWidget);
      expect(find.text('Tide-caller · The Undersong'), findsOneWidget);
      expect(find.textContaining('Voice'), findsOneWidget);
      expect(find.textContaining('0:08', findRichText: true), findsOneWidget);
      expect(find.text('ESSENCE'), findsOneWidget);
      // Relationships waits for chapter 6: a row in its place, never its words.
      expect(find.text('RELATIONSHIPS'), findsNothing);
      expect(find.textContaining('Trusts Bray'), findsNothing);
      expect(find.text('After Chapter 6'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('With'), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('Bray Half-Hitch'), findsOneWidget);
      expect(find.text('The Vigil'), findsOneWidget);
    });
    testWidgets('Reveal asks once, naming the production and where you are; Reveal keeps it on the phone', (tester) async {
      final store = await _pump(
        tester,
        location: Routes.guideEntry(world, 'maren-kest'),
        guide: _guide,
        reach: const GuideReach(reached: {_ledger: (at: 2, through: 2)}),
      );
      await tester.tap(find.text('Reveal'));
      await tester.pumpAndSettle();
      expect(find.text('The Ledger of Nights · you are at Chapter 2'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      await tester.tap(find.text('Reveal').last);
      await tester.pumpAndSettle();
      expect(store.revealedNow, [('undersong', _ledger, 6)]);
    });
    testWidgets('Not now reveals nothing', (tester) async {
      final store = await _pump(tester, location: Routes.guideEntry(world, 'maren-kest'), guide: _guide);
      await tester.tap(find.text('Reveal'));
      await tester.pumpAndSettle();
      expect(find.text('The Ledger of Nights'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(store.revealedNow, isEmpty);
    });
    testWidgets('revealed, the section reads as written', (tester) async {
      await _pump(
        tester,
        location: Routes.guideEntry(world, 'maren-kest'),
        guide: _guide,
        reach: const GuideReach(revealed: {_ledger: 6}),
      );
      expect(find.text('RELATIONSHIPS'), findsOneWidget);
      expect(find.text('After Chapter 6'), findsNothing);
    });
  });

  group('a place (P11e), lore (P11f) and a lore entry (P11g)', () {
    testWidgets('a place: Place · world, its sections, Here', (tester) async {
      await _pump(tester, location: Routes.guideEntry(world, 'the-vigil'), guide: _guide);
      expect(find.text('Place · The Undersong'), findsOneWidget);
      expect(find.text('LOOK'), findsOneWidget);
      expect(find.text('Here'), findsOneWidget);
      expect(find.text('Maren Kest'), findsOneWidget);
    });
    testWidgets('lore: All and the kinds present; a chip keeps its kind', (tester) async {
      await _pump(tester, location: Routes.lore(world), guide: _guide);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Rules'), findsNothing);
      expect(find.text('The Undersong'), findsOneWidget);
      expect(find.text('After Chapter 6'), findsOneWidget);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(find.text('The Undersong'), findsNothing);
      expect(find.text('After Chapter 6'), findsOneWidget);
    });
    testWidgets('a lore entry: its kind, title, text and With', (tester) async {
      await _pump(tester, location: Routes.guideEntry(world, 'canon-001'), guide: _guide);
      expect(find.text('LORE'), findsOneWidget);
      expect(find.text('The Undersong'), findsOneWidget);
      expect(find.textContaining('drowned god'), findsOneWidget);
      expect(find.text('Maren Kest'), findsOneWidget);
    });
    testWidgets('a chip opens the entry it names', (tester) async {
      await _pump(tester, location: Routes.guideEntry(world, 'canon-001'), guide: _guide);
      await tester.tap(find.text('The Vigil'));
      await tester.pumpAndSettle();
      expect(find.text('Place · The Undersong'), findsOneWidget);
    });
  });

  group('the author\'s words, as plain text', () {
    testWidgets('paragraphs apart, a list\'s lines kept, nothing read as markup', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: arkeTheme(Brightness.light),
          home: const Scaffold(body: GuideText('First **paragraph**.\n\n- one\n- two')),
        ),
      );
      expect(find.text('First **paragraph**.'), findsOneWidget);
      expect(find.text('- one\n- two'), findsOneWidget);
    });
    testWidgets('a faction is not called a place', (tester) async {
      const faction = GuidePlace(id: 'the-council', name: 'The Council', role: 'Faction', sections: []);
      final guide = Guide(productions: _guide.productions, characters: const [], places: [faction], lore: const []);
      await _pump(tester, location: Routes.guideEntry(world, 'the-council'), guide: guide);
      expect(find.text('Faction · The Undersong'), findsOneWidget);
    });
  });

  group('text at 200% clips nothing', () {
    for (final (name, location) in [
      ('Worlds', Routes.discover),
      ('the world\'s guide', world),
      ('a character', Routes.guideEntry(world, 'maren-kest')),
      ('a place', Routes.guideEntry(world, 'the-vigil')),
      ('lore', Routes.lore(world)),
      ('a lore entry', Routes.guideEntry(world, 'canon-001')),
    ]) {
      testWidgets(name, (tester) async {
        await _pump(tester, location: location, guide: _guide, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('the guide on a Fold (P11i)', (tester) async {
      await _pump(tester, location: world, guide: _guide, size: const Size(984, 1092), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('the guide read from this phone (R-18, R-21)', () {
    late Directory root;
    late ProviderContainer container;
    late HttpServer server;
    late List<int> alone;

    setUp(() async {
      // The widget tests' binding answers every request with a 400; these fetch from a real server.
      HttpOverrides.global = null;
      root = await Directory.systemTemp.createTemp('arke-player-guides-');
      alone = _package();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.contentLength = alone.length;
        request.response.add(alone);
        await request.response.close();
      });
      final pinned = CatalogueWorld(
        id: 'undersong',
        name: 'The Undersong',
        productions: const [],
        package: _undersong.package,
        guide: CataloguePackage(
          url: Uri.parse('http://127.0.0.1:${server.port}/guide.zip'),
          byteLength: alone.length,
          sha256: sha256.convert(alone).toString(),
        ),
      );
      container = ProviderContainer(
        overrides: [
          libraryRootProvider.overrideWith((ref) async => root),
          catalogueProvider.overrideWith((ref) async => [pinned]),
          storageInfoProvider.overrideWithValue(const _NoStorage()),
        ],
      );
      await container.read(catalogueProvider.future);
      await container.read(libraryStoreProvider.future);
    });
    tearDown(() async {
      container.dispose();
      await server.close(force: true);
      await root.delete(recursive: true);
    });

    /// Waits, on the real clock, until [read] has a value [done] accepts.
    Future<T> settled<T>(AsyncValue<T> Function() read, bool Function(T value) done) async {
      for (var i = 0; i < 100; i++) {
        if (read() case AsyncData(:final value) when done(value)) return value;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('never settled: ${read()}');
    }

    test('a world page fetches its guide alone once, and reads it from the phone', () async {
      // As the world page does: watching the fetch starts it.
      container.listen(guideFetchProvider('undersong'), (_, _) {});
      container.listen(worldGuideProvider('undersong'), (_, _) {});
      await container.read(guideFetchProvider('undersong').future);
      final guide = await settled(() => container.read(worldGuideProvider('undersong')), (guide) => guide != null);
      expect(guide!.guide.characters.first.name, 'Maren Kest');
      expect(File(guide.pathOf('g-maren')).existsSync(), isTrue);
    });

    test('installed with its guide, the package\'s guide is read; Reveal shows what waited', () async {
      final store = await container.read(libraryStoreProvider.future);
      final full = _package(book: File('${Directory.current.path}/../../packages/arke_media/test/fixtures/book.epub').readAsBytesSync());
      final installer = WorldInstaller(store: store, freeBytes: (_) async => null);
      await installer.commit(await installer.prepareFile(size: full.length, open: () => Stream.value(full)));
      container.listen(guideReachProvider('undersong'), (_, _) {});
      final chorister = _guide.characters.firstWhere((character) => character.id == 'the-chorister').after;
      GuideReach reach() => container.read(guideReachProvider('undersong')).value ?? GuideReach.none;
      final before = await settled(() => container.read(guideReachProvider('undersong')), (_) => true);
      expect(before.shows(chorister), isFalse);
      await store.reveal('undersong', _ledger, 6);
      await settled(() => container.read(guideReachProvider('undersong')), (reach) => reach.shows(chorister));
      expect(reach().shows(chorister), isTrue);
      expect(store.revealed, {
        'undersong': {_ledger: 6},
      });
    });
  });
}
