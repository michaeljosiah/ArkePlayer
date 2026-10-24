import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/home/presentation/home_screen.dart';
import 'package:arke_player/features/library/presentation/library_screen.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/discover_screen.dart';
import 'package:arke_player/features/worlds/presentation/row_widgets.dart';
import 'package:arke_player/features/worlds/presentation/world_widgets.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _undersong = CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour.',
  productions: const [CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook · Book · 2 h 03 m')],
  package: CataloguePackage(url: Uri.parse('https://example.org/undersong.zip'), byteLength: 386000000, sha256: 'a' * 64),
);
const _unpublished = CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  productions: [CatalogueProduction(title: 'The Ledger of Nights', kind: 'Book')],
);

final _installed = LibraryWorld(
  id: 'undersong',
  edition: '2026-10-21',
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour.',
  byteLength: 386000000,
  installedAt: DateTime.utc(2026, 10, 21),
  productions: const [
    LibraryProduction(
      id: 'ledger-of-nights',
      title: 'The Ledger of Nights',
      book: 'undersong.ledger-of-nights.book',
      narration: 'undersong.ledger-of-nights.narration',
    ),
  ],
);
final _worldItems = [
  LibraryItem(
    id: 'undersong.ledger-of-nights.narration',
    format: FileFormat.m4b,
    title: 'The Ledger of Nights',
    byteLength: 120000000,
    addedAt: DateTime.utc(2026, 10, 21),
    file: 'worlds/undersong/ledger-of-nights/narration.m4b',
    duration: const Duration(hours: 2, minutes: 3),
    chapters: const [
      Chapter(title: 'The Weigh House', start: Duration.zero),
      Chapter(title: 'The Weir', start: Duration(minutes: 21)),
      Chapter(title: 'The Tenth Key', start: Duration(minutes: 40)),
    ],
    worldId: 'undersong',
  ),
  LibraryItem(
    id: 'undersong.ledger-of-nights.book',
    format: FileFormat.epub,
    title: 'The Ledger of Nights',
    byteLength: 400000,
    addedAt: DateTime.utc(2026, 10, 21),
    file: 'worlds/undersong/ledger-of-nights/book.epub',
    worldId: 'undersong',
  ),
];
final _file = LibraryItem(
  id: 'a',
  format: FileFormat.mp3,
  title: 'Harbour Songs',
  byteLength: 8000000,
  addedAt: DateTime.utc(2026, 10, 20),
  file: 'items/a/media',
);

/// An installer that reports one step and then waits, or refuses at once.
class _FakeInstaller extends WorldInstaller {
  _FakeInstaller({this.refusal}) : super(store: LibraryStore(Directory.systemTemp), freeBytes: (_) async => null);

  final InstallRefusal? refusal;

  @override
  Future<LibraryWorld> install(CatalogueWorld world, {void Function(InstallStep step)? onStep, InstallCancel? cancel}) {
    if (refusal != null) return Future.error(refusal!);
    onStep?.call(const Downloading(162000000, 386000000));
    return Completer<LibraryWorld>().future;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  List<CatalogueWorld> catalogue = const [],
  List<LibraryWorld> worlds = const [],
  List<LibraryItem> items = const [],
  WorldInstaller? installer,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryItemsProvider.overrideWith((ref) => Stream.value(items)),
        libraryWorldsProvider.overrideWith((ref) => Stream.value(worlds)),
        catalogueProvider.overrideWith((ref) async => catalogue),
        volumeProvider.overrideWith((ref) async => (free: 41000000000, total: 128000000000)),
        if (installer != null) worldInstallerProvider.overrideWith((ref) async => installer),
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
}

/// Scrolls the page until [target] is in its middle, clear of the tabs' pill floating at the foot
/// (P16 rule 9): under Discover's feature (P16a), Worlds is further down.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
  await tester.scrollUntilVisible(target, 300, scrollable: page);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  group('first open (P9a)', () {
    testWidgets('offers Install a world when one is published', (tester) async {
      await _pump(tester, location: Routes.welcome, catalogue: [_undersong]);
      expect(find.text('Add a file'), findsOneWidget);
      expect(find.text('Install a world'), findsOneWidget);
      await tester.tap(find.text('Install a world'));
      await tester.pumpAndSettle();
      // Discover, the tab that took P9b's place (P11 rule 1, P15 rule 1), its worlds under Worlds.
      expect(find.byType(DiscoverScreen), findsOneWidget);
      await _reveal(tester, find.text('1 production · 386 MB'));
      expect(find.descendant(of: find.byType(DiscoverScreen), matching: find.text('Worlds')), findsOneWidget);
      expect(find.text('1 production · 386 MB'), findsOneWidget);
    });
    testWidgets('has no second press while nothing is published (P9 rule 2)', (tester) async {
      await _pump(tester, location: Routes.welcome, catalogue: [_unpublished]);
      expect(find.text('Install a world'), findsNothing);
    });
  });

  group('Home (P9g)', () {
    // Home's Discover section, not the tab of the same name (P15g).
    Finder discoverOnHome() => find.descendant(of: find.byType(HomeScreen), matching: find.text('Discover'));
    testWidgets('ends with Discover after the files', (tester) async {
      await _pump(tester, location: Routes.home, catalogue: [_undersong], items: [_file]);
      expect(find.text('Added'), findsOneWidget);
      expect(discoverOnHome(), findsOneWidget);
      expect(find.text('The Undersong'), findsOneWidget);
    });
    testWidgets('with nothing added, Discover sits under Add a file', (tester) async {
      await _pump(tester, location: Routes.home, catalogue: [_undersong]);
      expect(find.text('Nothing added'), findsOneWidget);
      expect(discoverOnHome(), findsOneWidget);
    });
    testWidgets('an installed world is under Worlds, and Discover is gone', (tester) async {
      await _pump(tester, location: Routes.home, catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      expect(find.descendant(of: find.byType(HomeScreen), matching: find.text('Worlds')), findsOneWidget);
      expect(discoverOnHome(), findsNothing);
      // A world's items are not files: no Added, no Nothing added.
      expect(find.text('Added'), findsNothing);
      expect(find.text('Nothing added'), findsNothing);
    });
  });

  group('a world before it is installed (P9c–P9e)', () {
    testWidgets('Install with its size, then its productions by kind (P15c) and Space', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong]);
      expect(find.text('The Undersong'), findsOneWidget);
      expect(find.text('1 production · 386 MB'), findsOneWidget);
      expect(find.textContaining('Install'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('The Ledger of Nights'), findsOneWidget);
      expect(find.text('386 MB of 41 GB free'), findsOneWidget);
    });
    testWidgets('installing puts the progress in the press’s place, with Cancel', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], installer: _FakeInstaller());
      await tester.tap(find.textContaining('Install'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Downloading · 162 MB of 386 MB'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.textContaining('Install'), findsOneWidget);
    });
    testWidgets('a refusal is one clause, with Try again and Close', (tester) async {
      await _pump(
        tester,
        location: Routes.world('undersong'),
        catalogue: [_undersong],
        installer: _FakeInstaller(refusal: const NoConnection()),
      );
      await tester.tap(find.textContaining('Install'));
      await tester.pumpAndSettle();
      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('The Undersong · 386 MB'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('No connection'), findsNothing);
    });
  });

  group('installed (P9f)', () {
    testWidgets('the page is P1d’s, its one audiobook a poster under Listen (P16 rule 3)', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      expect(find.text('Installed · 1 production · 386 MB'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Audiobook · Book · 2 h 03 m'), findsOneWidget);
      // A lone poster keeps the poster's size: at the full width it would be Discover's feature.
      expect(tester.getSize(find.byType(PosterTile)).width, 172);
      expect(find.byType(ProductionTile), findsNothing);
    });
    testWidgets('its production page: Play, Read beside it, Chapters', (tester) async {
      await _pump(tester, location: Routes.production(Routes.world('undersong'), 'ledger-of-nights'), worlds: [_installed], items: _worldItems);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('The Weir'), findsOneWidget);
    });
    testWidgets('Library shows the world under Worlds, above the files under Added (P15h)', (tester) async {
      await _pump(tester, location: Routes.library, worlds: [_installed], items: [..._worldItems, _file]);
      expect(find.text('The Undersong'), findsOneWidget);
      expect(find.descendant(of: find.byType(LibraryScreen), matching: find.text('Worlds')), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      expect(find.text('Harbour Songs'), findsOneWidget);
      // The world's own items are not listed as files.
      expect(find.text('The Ledger of Nights'), findsNothing);
    });
  });

  group('text at 200% clips no press (acceptance 9)', () {
    for (final (name, location, worlds, items) in [
      ('first open with two presses', Routes.welcome, const <LibraryWorld>[], const <LibraryItem>[]),
      ('Worlds', Routes.discover, const <LibraryWorld>[], const <LibraryItem>[]),
      ('a world to install', Routes.world('undersong'), const <LibraryWorld>[], const <LibraryItem>[]),
      ('Home with Available', Routes.home, const <LibraryWorld>[], [_file]),
      ('the installed world', Routes.world('undersong'), [_installed], _worldItems),
      ('its production', Routes.production(Routes.world('undersong'), 'ledger-of-nights'), [_installed], _worldItems),
    ]) {
      testWidgets(name, (tester) async {
        await _pump(tester, location: location, catalogue: [_undersong], worlds: worlds, items: items, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('a world to install on a Fold (P9h)', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], size: const Size(984, 1092), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
