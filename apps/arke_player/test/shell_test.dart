import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/shell/adaptive_shell.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/app/widgets/shelf.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAt(WidgetTester tester, Size size, {String location = Routes.home, List<LibraryItem> items = const [], double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [libraryItemsProvider.overrideWith((ref) => Stream.value(items))],
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
    for (final label in ['Home', 'Discover', 'Library', 'Downloads', 'You']) {
      expect(find.descendant(of: pill, matching: find.text(label)), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Home'), findsWidgets);
  });

  testWidgets('a Fold7 open has the pill too, 520 wide, and no rail: the page takes the width (P16j)', (tester) async {
    await _pumpAt(tester, const Size(984, 1092));
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(find.byType(TabPill)).width, 520);
    expect(tester.getTopLeft(find.byType(ShelfHeader)).dx, 0);
  });

  testWidgets('a press on the pill goes to its tab', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    await tester.tap(find.descendant(of: find.byType(TabPill), matching: find.text('You')));
    await tester.pumpAndSettle();
    expect(find.text('Version'), findsOneWidget);
    expect(tester.widget<TabPill>(find.byType(TabPill)).selected, 4);
  });

  testWidgets('a page’s last row clears the pill: the page is given its room at the foot (P16 rule 9)', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    final page = tester.element(find.byType(ShelfHeader));
    expect(MediaQuery.paddingOf(page).bottom, 12 + 64 + 12);
  });

  testWidgets('nothing added: the state line and Add a file, no account anywhere (P8b, P8 rule 1)', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    expect(find.text('Nothing added'), findsOneWidget);
    expect(find.text('Add a file'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
  });

  testWidgets('first open is the wordmark and Add a file alone (P8a)', (tester) async {
    await _pumpAt(tester, const Size(390, 844), location: Routes.welcome);
    expect(find.text('ARKE'), findsOneWidget);
    expect(find.text('Add a file'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
  });

  testWidgets('Home with files: Continue, then Added (P8d)', (tester) async {
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
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Nothing added'), findsNothing);
  });

  testWidgets('Library with one kind shows no chips (P8 rule 4)', (tester) async {
    await _pumpAt(tester, const Size(390, 844), location: Routes.library, items: [_item('a', FileFormat.mp3)]);
    expect(find.text('Listen'), findsNothing);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('Library with two kinds shows Discover’s chips, which filter (P8 rule 4, P15h)', (tester) async {
    await _pumpAt(tester, const Size(390, 844), location: Routes.library, items: [_item('a', FileFormat.mp3), _item('b', FileFormat.pdf)]);
    for (final chip in ['All', 'Listen', 'Watch', 'Play', 'Read']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('Title a'), findsOneWidget);
    await tester.ensureVisible(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsNothing);
    expect(find.text('Title b'), findsOneWidget);
  });

  testWidgets('Library with one kind shows no chips (P8 rule 4)', (tester) async {
    await _pumpAt(tester, const Size(390, 844), location: Routes.library, items: [_item('a', FileFormat.mp3)]);
    expect(find.text('Listen'), findsNothing);
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
    for (final (name, location) in [
      ('Home', Routes.home),
      ('Library', Routes.library),
      ('Downloads', Routes.downloads),
      ('You', Routes.you),
      ('first open', Routes.welcome),
    ]) {
      testWidgets(name, (tester) async {
        // An overflow is reported as an exception, so a clipped press fails the test.
        await _pumpAt(tester, const Size(390, 844), location: location, items: items, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('Home with nothing added', (tester) async {
      await _pumpAt(tester, const Size(390, 844), textScale: 2);
      expect(find.text('Add a file'), findsOneWidget);
    });
  });
}
