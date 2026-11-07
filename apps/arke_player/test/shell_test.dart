import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/shell/adaptive_shell.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/app/widgets/shelf.dart';
import 'package:arke_player/features/home/presentation/home_screen.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAt(WidgetTester tester, Size size, {String location = Routes.home, List<LibraryItem> items = const [], double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryItemsProvider.overrideWith((ref) => Stream.value(items)),
        // No list: Home's covers have their own tests, and these are the shell's.
        catalogueProvider.overrideWith((ref) async => const <CatalogueWorld>[]),
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

LibraryItem _item(String id, FileFormat format, {Place? place, DateTime? addedAt}) => LibraryItem(
  id: id,
  format: format,
  title: 'Title $id',
  byteLength: 1000000,
  addedAt: addedAt ?? DateTime.utc(2026, 10, 20),
  file: 'items/$id/media',
  place: place,
);

void main() {
  testWidgets('a phone has the tabs as a pill floating over the page, 358 × 64 (P16h, rule 9)', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    final pill = find.byType(TabPill);
    expect(pill, findsOneWidget);
    expect(tester.getSize(pill), const Size(358, 64));
    // 24 above the foot with the phone's 34 for its home indicator; 12 with none, as here.
    expect(tester.getBottomLeft(pill).dy, 844 - 12);
    expect(tester.getCenter(pill).dx, 195);
    for (final label in ['Home', 'Worlds', 'Library', 'You']) {
      expect(find.descendant(of: pill, matching: find.text(label)), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Home'), findsWidgets);
  });

  testWidgets('a Fold7 open has the pill too, 520 wide, and no rail: the page takes the width (P16j)', (tester) async {
    await _pumpAt(tester, const Size(984, 1092), location: Routes.you);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(find.byType(TabPill)).width, 520);
    expect(tester.getTopLeft(find.byType(ShelfHeader)).dx, 0);
  });

  testWidgets('a press on the pill goes to its tab', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    await tester.tap(find.descendant(of: find.byType(TabPill), matching: find.text('You')));
    await tester.pumpAndSettle();
    expect(find.text('Version'), findsOneWidget);
    expect(tester.widget<TabPill>(find.byType(TabPill)).selected, 3);
  });

  testWidgets('a page’s last row clears the pill: the page is given its room at the foot (P16 rule 9)', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    final page = tester.element(find.byType(HomeScreen));
    expect(MediaQuery.paddingOf(page).bottom, 12 + 64 + 12);
  });

  testWidgets('with no list and nothing going: the state line and Add a file, no account anywhere (P22 rule 1, P8 rule 1)', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    expect(find.text('Nothing added'), findsOneWidget);
    expect(find.text('Add a file'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
  });

  group('Library (P22l, P22m, P25f)', () {
    testWidgets('its chips are Worlds, Files and Downloads, and an empty Worlds points to the tab', (tester) async {
      await _pumpAt(tester, const Size(390, 844), location: Routes.library);
      expect(find.text('No worlds yet'), findsOneWidget);
      expect(find.text('Worlds'), findsNWidgets(3)); // The chip, the press, the tab.
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing added'), findsOneWidget);
      expect(find.text('Add a file'), findsOneWidget);
    });
    testWidgets('You’s On this phone opens it at Downloads', (tester) async {
      await _pumpAt(tester, const Size(390, 844), location: Routes.you);
      await tester.tap(find.text('On this phone'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Arke Player'), findsOneWidget);
    });
  });

  group('You (P25g)', () {
    testWidgets('has Theme, dark until changed, and Check for updates (P22 rule 7)', (tester) async {
      await _pumpAt(tester, const Size(390, 844), location: Routes.you);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Check for updates'), 200);
      expect(find.text('Check for updates'), findsOneWidget);
    });
    testWidgets('Adult content asks once, and only a yes turns it on (call 42)', (tester) async {
      await _pumpAt(tester, const Size(390, 844), location: Routes.you);
      await tester.scrollUntilVisible(find.text('Adult content'), 200);
      await tester.tap(find.text('Adult content'));
      await tester.pumpAndSettle();
      expect(find.text('I am 18 or older · Turn on'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsWidgets);
      await tester.tap(find.text('Adult content'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I am 18 or older · Turn on'));
      await tester.pumpAndSettle();
      expect(find.text('On'), findsOneWidget);
    });
  });

  testWidgets('Home with files: Continue, and Added has left for Library (P22 rule 5)', (tester) async {
    final items = [
      _item(
        'a',
        FileFormat.m4b,
        place: Place(progress: 0.4, position: const Duration(minutes: 3), updatedAt: DateTime.utc(2026, 10, 20, 9)),
      ),
      _item('b', FileFormat.epub),
    ];
    await _pumpAt(tester, const Size(390, 844), items: items);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Added'), findsNothing);
    expect(find.text('Nothing added'), findsNothing);
    await tester.tap(find.descendant(of: find.byType(TabPill), matching: find.text('Library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('Title b'), findsOneWidget);
  });

  testWidgets('Library’s files are under Files, whatever their kinds (P22l)', (tester) async {
    await _pumpAt(tester, const Size(390, 844), location: Routes.library, items: [_item('a', FileFormat.mp3), _item('b', FileFormat.epub)]);
    expect(find.text('All'), findsNothing);
    expect(find.text('Title a'), findsNothing);
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('Title b'), findsOneWidget);
  });

  testWidgets('You before an account: Playback, Storage, About only (P8f)', (tester) async {
    await _pumpAt(tester, const Size(390, 844), location: Routes.you);
    expect(find.text('Captions'), findsOneWidget);
    expect(find.text('On this phone'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  group('text at 200% clips no press (acceptance 9)', () {
    final items = [
      _item(
        'a',
        FileFormat.m4b,
        place: Place(progress: 0.4, position: const Duration(minutes: 3), updatedAt: DateTime.utc(2026, 10, 20, 9)),
      ),
      _item('b', FileFormat.epub),
      _item('c', FileFormat.mov),
    ];
    for (final (name, location) in [('Home', Routes.home), ('Library', Routes.library), ('Downloads', Routes.downloads), ('You', Routes.you)]) {
      testWidgets(name, (tester) async {
        // An overflow is reported as an exception, so a clipped press fails the test.
        await _pumpAt(tester, const Size(390, 844), location: location, items: items, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('Home with no list and nothing going', (tester) async {
      await _pumpAt(tester, const Size(390, 844), textScale: 2);
      expect(find.text('Add a file'), findsOneWidget);
    });
  });
}
