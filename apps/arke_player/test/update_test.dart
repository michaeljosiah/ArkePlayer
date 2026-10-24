import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/production_screen.dart';
import 'package:arke_player/features/worlds/presentation/world_widgets.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// SPEC-058 R-30 – R-35, Player P12: a newer edition of an installed world, from Arke's list.

CatalogueWorld _listed({String edition = '2026-10-22', String fingerprint = 'b'}) => CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour.',
  productions: const [CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook · Book · 8 h 2 m')],
  package: CataloguePackage(
    url: Uri.parse('https://example.org/undersong.zip'),
    byteLength: 228000000,
    sha256: 'a' * 64,
    edition: edition,
    fingerprint: fingerprint * 64,
  ),
);

final _installed = LibraryWorld(
  id: 'undersong',
  edition: '2026-10-20',
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour.',
  byteLength: 182000000,
  installedAt: DateTime.utc(2026, 10, 20),
  fingerprint: 'a' * 64,
  productions: const [LibraryProduction(id: 'ledger-of-nights', title: 'The Ledger of Nights', book: 'undersong.ledger-of-nights.book')],
);

/// An installer whose update reports one step and then waits, or refuses at once.
class _FakeInstaller extends WorldInstaller {
  _FakeInstaller({this.refusal}) : super(store: LibraryStore(Directory.systemTemp), freeBytes: (_) async => null);

  final InstallRefusal? refusal;
  int updates = 0;

  @override
  Future<LibraryWorld> update(CatalogueWorld world, {void Function(InstallStep step)? onStep, InstallCancel? cancel, Future<void> Function()? beforeSwap}) {
    updates++;
    if (refusal != null) return Future.error(refusal!);
    onStep?.call(const Downloading(120000000, 228000000));
    return Completer<LibraryWorld>().future;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  required List<CatalogueWorld> catalogue,
  WorldInstaller? installer,
  LibraryWorld? installed,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryItemsProvider.overrideWith((ref) => Stream.value(const <LibraryItem>[])),
        libraryWorldsProvider.overrideWith((ref) => Stream.value([installed ?? _installed])),
        catalogueProvider.overrideWith((ref) async => catalogue),
        volumeProvider.overrideWith((ref) async => (free: 41000000000, total: 128000000000)),
        if (installer != null) worldInstallerProvider.overrideWith((ref) async => installer),
      ],
      child: MaterialApp.router(
        theme: arkeTheme(Brightness.light),
        routerConfig: buildRouter(initialLocation: location),
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
  test('Arke’s address is HTTPS, as a package is (R-31)', () => expect(arkeWorldsList.scheme, 'https'));

  test('an edition says its date (P12b)', () {
    expect(editionLabel('2026-10-22'), '22 Oct 2026');
    expect(editionLabel('2026-10-22-2'), '22 Oct 2026');
    expect(editionLabel('first'), 'first');
  });

  testWidgets('Discover marks an installed world with a newer edition (P12a, R-32)', (tester) async {
    await _pump(tester, location: Routes.discover, catalogue: [_listed()]);
    await _reveal(tester, find.text('Update'));
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('a world installed under an id the list’s world replaces is offered Update, not a second world (R-30)', (tester) async {
    final renamed = CatalogueWorld(
      id: 'the-undersong',
      name: 'The Undersong',
      replaces: const ['undersong'],
      productions: const [CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook · Book · 5 h 33 m')],
      package: CataloguePackage(
        url: Uri.parse('https://example.org/u.zip'),
        byteLength: 413000000,
        sha256: 'a' * 64,
        edition: '2026-10-22',
        fingerprint: 'c' * 64,
      ),
    );
    await _pump(tester, location: Routes.discover, catalogue: [renamed]);
    await _reveal(tester, find.text('Update'));
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Available'), findsNothing);
    await tester.tap(find.text('The Undersong'));
    await tester.pumpAndSettle();
    expect(find.text('Update · 413 MB', findRichText: true), findsOneWidget);
    expect(find.text('22 Oct 2026 · 413 MB'), findsOneWidget);
  });

  testWidgets('a page left open at a world’s old id moves to its new one, so its production opens (R-30)', (tester) async {
    const renamed = CatalogueWorld(id: 'the-undersong', name: 'The Undersong', replaces: ['undersong'], productions: []);
    final updated = LibraryWorld(
      id: 'the-undersong',
      edition: '2026-10-22',
      name: 'The Undersong',
      byteLength: 413000000,
      installedAt: DateTime.utc(2026, 10, 22),
      productions: const [LibraryProduction(id: 'the-ledger-of-nights', title: 'The Ledger of Nights', book: 'the-undersong.the-ledger-of-nights.book')],
    );
    await _pump(tester, location: Routes.discoverWorld('undersong'), catalogue: [renamed], installed: updated);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    await tester.tap(find.text('The Ledger of Nights'));
    await tester.pumpAndSettle();
    // Under the old address this was the Removed page (as the owner saw it on 22 October).
    expect(find.text('Removed'), findsNothing);
    expect(find.byType(ProductionScreen), findsOneWidget);

    // A production reached by its old address still opens.
    router.go('${Routes.discoverWorld('undersong')}/the-ledger-of-nights');
    await tester.pumpAndSettle();
    expect(find.text('Removed'), findsNothing);
    expect(find.text('The Ledger of Nights'), findsWidgets);
  });

  testWidgets('and not when the list names the edition installed', (tester) async {
    await _pump(
      tester,
      location: Routes.discover,
      catalogue: [_listed(fingerprint: 'a')],
    );
    expect(find.text('Update'), findsNothing);
  });

  testWidgets('the world’s page offers Update with the new edition and the space (P12b), then updates in place (P12c)', (tester) async {
    final installer = _FakeInstaller();
    await _pump(tester, location: Routes.discoverWorld('undersong'), catalogue: [_listed()], installer: installer);
    expect(find.text('Installed · 20 Oct 2026 · 182 MB'), findsOneWidget);
    expect(find.text('Update · 228 MB', findRichText: true), findsOneWidget);
    expect(find.text('22 Oct 2026 · 228 MB'), findsOneWidget);
    expect(find.text('+46 MB of 41 GB free'), findsOneWidget);

    await tester.tap(find.text('Update · 228 MB', findRichText: true));
    await tester.pump();
    expect(installer.updates, 1);
    expect(find.text('Downloading · 120 MB of 228 MB'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('a refusal is one clause with the edition it would have brought (P12f, R-35)', (tester) async {
    final installer = _FakeInstaller(refusal: const NeedsSpace(456000000, 20000000));
    await _pump(tester, location: Routes.discoverWorld('undersong'), catalogue: [_listed()], installer: installer);
    await tester.tap(find.text('Update · 228 MB', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text(const NeedsSpace(456000000, 20000000).clause), findsOneWidget);
    expect(find.text('The Undersong · 22 Oct 2026'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // The installed edition is untouched: the page still offers the update.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Installed · 20 Oct 2026 · 182 MB'), findsOneWidget);
  });

  testWidgets('Downloads lists an update under Worlds (P12e)', (tester) async {
    final installer = _FakeInstaller();
    await _pump(tester, location: Routes.discoverWorld('undersong'), catalogue: [_listed()], installer: installer);
    await tester.tap(find.text('Update · 228 MB', findRichText: true));
    await tester.pump();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go(Routes.downloads);
    await tester.pumpAndSettle();
    expect(find.text('Worlds'), findsWidgets);
    expect(find.text('Updating · 47%'), findsOneWidget);
  });
}
