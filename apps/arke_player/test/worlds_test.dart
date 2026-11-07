import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/app/widgets/shelf.dart';
import 'package:arke_player/features/home/presentation/home_screen.dart';
import 'package:arke_player/features/players/presentation/open_item_screen.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/production_screen.dart';
import 'package:arke_player/features/worlds/presentation/row_widgets.dart';
import 'package:arke_player/features/worlds/presentation/world_screen.dart';
import 'package:arke_player/features/worlds/presentation/world_shelf.dart';
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

/// The Undersong again, as the list would name an 18+ world (P22 rule 9, call 42).
final _adult = CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  genres: const ['Horror'],
  age: '18+',
  productions: const [CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook · Book · 2 h 03 m')],
  package: CataloguePackage(url: Uri.parse('https://example.org/undersong.zip'), byteLength: 386000000, sha256: 'a' * 64),
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

/// The world's narration begun, 25 minutes in: chapter 2.
final _begun = [
  _worldItems.first.copyWith(
    place: Place(position: const Duration(minutes: 25), progress: 0.2, updatedAt: DateTime.utc(2026, 10, 22)),
  ),
  _worldItems.last,
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
  var installs = 0;

  @override
  Future<LibraryWorld> install(CatalogueWorld world, {void Function(InstallStep step)? onStep, InstallCancel? cancel}) {
    installs++;
    if (refusal != null) return Future.error(refusal!);
    onStep?.call(const Downloading(162000000, 386000000));
    return Completer<LibraryWorld>().future;
  }
}

/// Settings kept in memory: the phone's storage is a platform channel no widget test has.
class _Settings extends SettingsController {
  @override
  Future<DeviceSettings> build() async => const DeviceSettings();

  @override
  Future<void> change(DeviceSettings Function(DeviceSettings current) edit) async => state = AsyncData(edit(state.value ?? const DeviceSettings()));
}

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  List<CatalogueWorld> catalogue = const [],
  List<LibraryWorld> worlds = const [],
  List<LibraryItem> items = const [],
  WorldInstaller? installer,
  Future<void> Function(Ref)? refresh,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool online = true,
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
        if (refresh != null) catalogueRefreshProvider.overrideWith(refresh),
        volumeProvider.overrideWith((ref) async => (free: 41000000000, total: 128000000000)),
        onlineProvider.overrideWith((ref) => Stream.value(online)),
        settingsProvider.overrideWith(_Settings.new),
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

Finder _start([String size = '386 MB']) => find.text('Start · $size', findRichText: true);

void main() {
  group('a brand-new install (P25, call 37)', () {
    testWidgets('opens on Home, and a hosted world shows once the list arrives, with no file added', (tester) async {
      final fetched = Completer<void>();
      final catalogue = <CatalogueWorld>[];
      await _pump(
        tester,
        location: Routes.home,
        catalogue: catalogue,
        refresh: (ref) async {
          await fetched.future;
          catalogue.add(_undersong);
          ref.invalidate(catalogueProvider);
        },
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(_undersong.name), findsNothing);
      fetched.complete();
      await tester.pumpAndSettle();
      expect(find.text(_undersong.name), findsOneWidget);
    });

    testWidgets('with no list at all, Add a file is still there in Library', (tester) async {
      await _pump(tester, location: Routes.library, refresh: (ref) async => throw const SocketException('offline'));
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      expect(find.text('Add a file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Home with what is on the phone (P22 rules 1, 5)', () {
    testWidgets('a file added has left Home for Library: the covers, and no Added', (tester) async {
      await _pump(tester, location: Routes.home, catalogue: [_undersong], items: [_file]);
      expect(find.text('Added'), findsNothing);
      expect(find.text('Harbour Songs'), findsNothing);
      expect(find.byType(WorldCover), findsOneWidget);
      expect(find.text('The Undersong'), findsOneWidget);
    });
    testWidgets('with nothing added, the covers are the page, and Add a file has moved to Library', (tester) async {
      await _pump(tester, location: Routes.home, catalogue: [_undersong]);
      expect(find.text('Nothing added'), findsNothing);
      expect(find.text('Add a file'), findsNothing);
      expect(find.byType(WorldCover), findsOneWidget);
    });
    testWidgets('an installed world keeps its cover, its press now Play; a world’s items are not files', (tester) async {
      await _pump(tester, location: Routes.home, catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      final cover = find.byType(WorldCover);
      expect(cover, findsOneWidget);
      expect(find.descendant(of: cover, matching: find.text('Play')), findsOneWidget);
      // Nothing is going, so the covers still open the page, with no head over them.
      expect(find.descendant(of: find.byType(HomeScreen), matching: find.text('Worlds')), findsNothing);
      expect(find.text('Added'), findsNothing);
      expect(find.text('Nothing added'), findsNothing);
    });
  });

  group('a world before it is here (P22h, P22 rule 11)', () {
    testWidgets('its meta line, Start with its size, its one title; Space in ⋯', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong]);
      expect(find.text('The Undersong'), findsOneWidget);
      expect(find.text('1 title'), findsOneWidget);
      expect(_start(), findsOneWidget);
      expect(find.text('Story'), findsOneWidget);
      expect(find.ancestor(of: find.text('The Ledger of Nights'), matching: find.byType(PosterTile)), findsOneWidget);
      expect(find.textContaining('production'), findsNothing);
      expect(find.text('Space'), findsNothing);

      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      expect(find.text('Space'), findsOneWidget);
      expect(find.text('386 MB of 41 GB free'), findsOneWidget);
    });
    testWidgets('its meta line leads with its first genre', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_adult]);
      expect(find.text('Horror · 1 title'), findsOneWidget);
      expect(find.text('18+'), findsOneWidget);
    });
    testWidgets('installing puts the progress in the press’s place, with Cancel', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], installer: _FakeInstaller());
      await tester.tap(_start());
      await tester.pump();
      await tester.pump();
      expect(find.text('Downloading · 162 of 386 MB'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(_start(), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(_start(), findsOneWidget);
    });
    testWidgets('a refusal is one clause, with Try again and Close', (tester) async {
      await _pump(
        tester,
        location: Routes.world('undersong'),
        catalogue: [_undersong],
        installer: _FakeInstaller(refusal: const NoConnection()),
      );
      await tester.tap(_start());
      await tester.pumpAndSettle();
      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('The Undersong · 386 MB'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('No connection'), findsNothing);
    });
  });

  testWidgets('with no connection, Home’s head says Offline (P25h)', (tester) async {
    await _pump(tester, location: Routes.home, catalogue: [_undersong], online: false);
    expect(find.text('Offline'), findsOneWidget);
  });

  group('a world’s press (P22 rule 3, P25d, P25e, P25h)', () {
    Future<void> pressAsk(WidgetTester tester, Finder press) async {
      await tester.tap(press);
      await tester.pumpAndSettle();
    }

    test('its size is all the download comes to: the edition, every part since, what is published alone', () {
      CataloguePart part(int bytes) => CataloguePart(
        url: Uri.parse('https://example.org/part.zip'),
        byteLength: bytes,
        sha256: 'c' * 64,
        edition: '2026-10-23',
        fingerprint: 'd' * 64,
        released: DateTime.utc(2026, 10, 23),
        production: 'ledger',
        chapters: const [],
      );
      final world = CatalogueWorld(
        id: 'whole',
        name: 'Whole',
        productions: [
          CatalogueProduction(
            id: 'album',
            title: 'Album',
            kind: 'Album · 9 tracks',
            music: MusicKind.album,
            package: CataloguePackage(url: Uri.parse('https://example.org/album.zip'), byteLength: 36000000, sha256: 'e' * 64),
          ),
          const CatalogueProduction(id: 'ledger', title: 'Ledger', kind: 'Book'),
        ],
        package: CatalogueEdition(
          url: Uri.parse('https://example.org/whole.zip'),
          byteLength: 88000000,
          sha256: 'a' * 64,
          edition: '2026-10-09',
          fingerprint: 'e' * 64,
          parts: [part(18000000), part(2000000)],
        ),
      );
      expect(worldBytes(world), 88000000 + 18000000 + 2000000 + 36000000);
      expect(worldBytes(const CatalogueWorld(id: 'none', name: 'None', productions: [])), 0);
    });

    test('what it opens: the place kept most lately, else the title the list names, else the first that is not music (call 39)', () {
      LibraryItem book(String id, {DateTime? placed}) => LibraryItem(
        id: id,
        format: FileFormat.epub,
        title: id,
        byteLength: 1,
        addedAt: DateTime.utc(2026),
        file: 'worlds/$id',
        place: placed == null ? null : Place(progress: 0.5, updatedAt: placed),
      );
      final world = LibraryWorld(
        id: 'w',
        edition: '2026-10-21',
        name: 'W',
        byteLength: 1,
        installedAt: DateTime.utc(2026),
        productions: const [
          LibraryProduction(
            id: 'album',
            title: 'Album',
            music: LibraryMusic(document: 'a', kind: 'album', tracks: 1, duration: Duration(minutes: 3)),
          ),
          LibraryProduction(id: 'a', title: 'A', book: 'a'),
          LibraryProduction(id: 'b', title: 'B', book: 'b'),
          LibraryProduction(id: 'c', title: 'C', book: 'c'),
        ],
      );
      const named = CatalogueWorld(
        id: 'w',
        name: 'W',
        start: 'b',
        productions: [CatalogueProduction(id: 'b', title: 'B', kind: 'Book')],
      );
      expect(worldStart(world, null, const {})?.production.id, 'a');
      expect(worldStart(world, named, const {})?.production.id, 'b');
      final going = {'a': book('a', placed: DateTime.utc(2026, 1, 1)), 'c': book('c', placed: DateTime.utc(2026, 2, 1))};
      expect(worldStart(world, named, going)?.production.id, 'c');
      // A world of music alone has nothing for the press to open.
      expect(
        worldStart(
          LibraryWorld(id: 'm', edition: 'e', name: 'M', byteLength: 1, installedAt: DateTime.utc(2026), productions: [world.productions.first]),
          null,
          const {},
        ),
        isNull,
      );
    });

    testWidgets('a world with nothing published has no press', (tester) async {
      await _pump(
        tester,
        location: Routes.world('soon'),
        catalogue: const [CatalogueWorld(id: 'soon', name: 'Soon', productions: [])],
      );
      expect(find.text('Soon'), findsOneWidget);
      expect(find.textContaining('Start'), findsNothing);
      expect(find.byType(NotifyBell), findsNothing);
    });

    testWidgets('Start · its size; pressed, it installs, with nothing asked of a world for everyone', (tester) async {
      final installer = _FakeInstaller();
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], installer: installer);
      expect(_start(), findsOneWidget);
      expect(find.byType(NotifyBell), findsOneWidget);
      await tester.tap(_start());
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('I am 18'), findsNothing);
      expect(installer.installs, 1);
      expect(find.text('Downloading · 162 of 386 MB'), findsOneWidget);
    });

    testWidgets('on an 18+ world Start asks first, and Not now starts nothing', (tester) async {
      final installer = _FakeInstaller();
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_adult], installer: installer);
      await pressAsk(tester, _start());
      expect(find.text('I am 18 or older · Start'), findsOneWidget);
      expect(find.text('Horror · 386 MB'), findsOneWidget);
      expect(installer.installs, 0, reason: 'before anything downloads');
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(installer.installs, 0);
      expect(find.text('I am 18 or older · Start'), findsNothing);
      expect(_start(), findsOneWidget);

      // Not now is no answer: pressed again, it asks again.
      await pressAsk(tester, _start());
      expect(find.text('I am 18 or older · Start'), findsOneWidget);
    });

    testWidgets('the yes starts it, and this phone asks no more', (tester) async {
      final installer = _FakeInstaller();
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_adult], installer: installer);
      await pressAsk(tester, _start());
      await tester.tap(find.text('I am 18 or older · Start'));
      await tester.pumpAndSettle();
      expect(installer.installs, 1);
      expect(find.text('Downloading · 162 of 386 MB'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(WorldPress)));
      expect(container.read(settingsProvider).value?.adultContent, isTrue);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.tap(_start());
      await tester.pumpAndSettle();
      expect(find.textContaining('I am 18'), findsNothing);
      expect(installer.installs, 2);
    });

    testWidgets('with no connection: No connection, and pressing it does nothing; the bell stays (P25h)', (tester) async {
      final installer = _FakeInstaller();
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], installer: installer, online: false);
      final press = find.text('Start · No connection', findRichText: true);
      expect(press, findsOneWidget);
      expect(_start(), findsNothing);
      expect(find.byType(NotifyBell), findsOneWidget);
      expect(
        tester.widget<ButtonStyleButton>(find.ancestor(of: press, matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton))).onPressed,
        isNull,
      );
      await tester.tap(press);
      await tester.pumpAndSettle();
      expect(installer.installs, 0);
      expect(find.textContaining('Downloading'), findsNothing);
    });

    testWidgets('with no connection, an 18+ world asks nothing either, as there is nothing to start', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_adult], installer: _FakeInstaller(), online: false);
      await tester.tap(find.text('Start · No connection', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('I am 18'), findsNothing);
    });

    testWidgets('Play once it arrived, with Read beside a narration’s book; each opens its own (P25e)', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.textContaining('Start'), findsNothing);
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      expect(tester.widget<OpenItemScreen>(find.byType(OpenItemScreen)).itemId, 'undersong.ledger-of-nights.book');
    });

    testWidgets('Play opens the first title', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(tester.widget<OpenItemScreen>(find.byType(OpenItemScreen)).itemId, 'undersong.ledger-of-nights.narration');
    });

    testWidgets('a world of a book alone reads: Read, with nothing beside it', (tester) async {
      final book = LibraryWorld(
        id: 'undersong',
        edition: '2026-10-21',
        name: 'The Undersong',
        byteLength: 400000,
        installedAt: DateTime.utc(2026, 10, 21),
        productions: const [LibraryProduction(id: 'ledger-of-nights', title: 'The Ledger of Nights', book: 'undersong.ledger-of-nights.book')],
      );
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [book], items: [_worldItems.last]);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Play'), findsNothing);
    });

    testWidgets('Continue · Chapter N once begun, with Read beside it', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _begun);
      expect(find.text('Continue · Chapter 2', findRichText: true), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Play'), findsNothing);
    });

    testWidgets('with no connection, a world that is here still plays', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _worldItems, online: false);
      expect(find.text('Play'), findsOneWidget);
      expect(find.textContaining('No connection'), findsNothing);
    });

    testWidgets('on an 18+ world here, Play and Read ask too, each by its name; Not now opens nothing', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_adult], worlds: [_installed], items: _worldItems);
      await pressAsk(tester, find.text('Play'));
      expect(find.text('I am 18 or older · Play'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byType(OpenItemScreen), findsNothing);

      await pressAsk(tester, find.text('Read'));
      expect(find.text('I am 18 or older · Read'), findsOneWidget);
      await tester.tap(find.text('I am 18 or older · Read'));
      await tester.pumpAndSettle();
      expect(tester.widget<OpenItemScreen>(find.byType(OpenItemScreen)).itemId, 'undersong.ledger-of-nights.book');
    });

    // P22 rule 9 has Play and Read ask wherever they are: the route asks, whichever press led there.
    testWidgets('on an 18+ world here, a title’s own Play asks too', (tester) async {
      await _pump(
        tester,
        location: Routes.production(Routes.world('undersong'), 'ledger-of-nights'),
        catalogue: [_adult],
        worlds: [_installed],
        items: _worldItems,
      );
      await pressAsk(tester, find.text('Play'));
      expect(find.text('I am 18 or older · Play'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byType(OpenItemScreen), findsNothing);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('on an 18+ world here, a chapter on its page asks too', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_adult], worlds: [_installed], items: _worldItems);
      await pressAsk(tester, find.text('The Weir'));
      expect(find.text('I am 18 or older · Play'), findsOneWidget);
      await tester.tap(find.text('I am 18 or older · Play'));
      await tester.pumpAndSettle();
      expect(find.byType(OpenItemScreen), findsOneWidget);
    });

    testWidgets('reached straight, as a notification does, nothing plays until it is answered, and Not now goes Home', (tester) async {
      await _pump(tester, location: Routes.open('undersong.ledger-of-nights.book'), catalogue: [_adult], worlds: [_installed], items: _worldItems);
      expect(find.text('I am 18 or older · Read'), findsOneWidget);
      expect(find.byType(OpenItemScreen), findsNothing);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byType(OpenItemScreen), findsNothing);
      expect(find.byType(WorldCover), findsOneWidget);
    });

    testWidgets('on a cover too: the download in the press’s place, with Cancel, and the page free to browse (P25d)', (tester) async {
      await _pump(tester, location: Routes.home, catalogue: [_undersong], installer: _FakeInstaller());
      final cover = find.byType(WorldCover);
      await tester.tap(find.descendant(of: cover, matching: _start()));
      await tester.pump();
      await tester.pump();
      expect(find.descendant(of: cover, matching: find.text('Downloading · 162 of 386 MB')), findsOneWidget);
      expect(find.descendant(of: cover, matching: find.text('Cancel')), findsOneWidget);
      expect(find.descendant(of: find.byType(HomeScreen), matching: find.byType(ModalBarrier)), findsNothing);
      await tester.tap(find.descendant(of: cover, matching: find.text('Cancel')));
      await tester.pump();
      expect(find.descendant(of: cover, matching: _start()), findsOneWidget);
    });

    testWidgets('a band’s Start starts its world, its press then showing how far', (tester) async {
      final installer = _FakeInstaller();
      await _pump(tester, location: Routes.home, catalogue: [_undersong, _band()], installer: installer, size: const Size(390, 2400));
      await tester.tap(find.descendant(of: find.byType(WorldBand), matching: find.text('Start')));
      await tester.pump();
      await tester.pump();
      expect(installer.installs, 1);
      expect(tester.widget<BandPress>(find.byType(BandPress)).progress, isNotNull);
    });

    testWidgets('a band’s Start asks as well on an 18+ world', (tester) async {
      final installer = _FakeInstaller();
      await _pump(
        tester,
        location: Routes.home,
        catalogue: [
          _undersong,
          _band(age: '18+'),
        ],
        installer: installer,
        size: const Size(390, 2400),
      );
      await pressAsk(tester, find.descendant(of: find.byType(WorldBand), matching: find.text('Start')));
      expect(find.text('I am 18 or older · Start'), findsOneWidget);
      expect(installer.installs, 0);
    });
  });

  group('installed (P22i, call 44)', () {
    testWidgets('a world of one title has one page: its chapters at once, and no poster', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      expect(find.text('1 title'), findsOneWidget);
      expect(find.byType(ProductionContents), findsOneWidget);
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('The Weir'), findsOneWidget);
      expect(find.byType(PosterTile), findsNothing);
      expect(find.textContaining('Installed'), findsNothing);
      expect(find.textContaining('In Library'), findsNothing);
    });
    testWidgets('a chapter on that page opens the narration there', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      await tester.tap(find.text('The Weir'));
      await tester.pumpAndSettle();
      final opened = tester.widget<OpenItemScreen>(find.byType(OpenItemScreen));
      expect((opened.itemId, opened.startAt), ('undersong.ledger-of-nights.narration', const Duration(minutes: 21)));
    });
    testWidgets('before it is here, a title has no chapters to show: a poster', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong]);
      expect(find.byType(ProductionContents), findsNothing);
      expect(find.byType(PosterTile), findsOneWidget);
    });
    testWidgets('of two titles, each a poster opening its own page', (tester) async {
      final two = LibraryWorld(
        id: 'undersong',
        edition: '2026-10-21',
        name: 'The Undersong',
        byteLength: 386000000,
        installedAt: DateTime.utc(2026, 10, 21),
        productions: [
          ..._installed.productions,
          const LibraryProduction(id: 'undertow', title: 'Undertow', book: 'undersong.undertow.book'),
        ],
      );
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [two], items: _worldItems);
      expect(find.text('2 titles'), findsOneWidget);
      expect(find.byType(ProductionContents), findsNothing);
      expect(tester.getSize(find.ancestor(of: find.text('The Ledger of Nights'), matching: find.byType(PosterTile))).width, 172);
      await tester.tap(find.text('The Ledger of Nights'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductionScreen), findsOneWidget);
    });
    testWidgets('a world whose one title is still on its way shows that title (R-72, R-73)', (tester) async {
      final empty = LibraryWorld(
        id: 'undersong',
        edition: '2026-10-21',
        name: 'The Undersong',
        byteLength: 1000,
        installedAt: DateTime.utc(2026, 10, 21),
        productions: const [],
      );
      final listed = CatalogueWorld(
        id: 'undersong',
        name: 'The Undersong',
        productions: [
          CatalogueProduction(
            id: 'album',
            title: 'Songs of the Drowned Quarter',
            kind: 'Album · 9 tracks',
            music: MusicKind.album,
            package: CataloguePackage(url: Uri.parse('https://example.org/album.zip'), byteLength: 36000000, sha256: 'e' * 64),
          ),
        ],
        package: _undersong.package,
      );
      await _pump(tester, location: Routes.world('undersong'), catalogue: [listed], worlds: [empty]);
      expect(tester.takeException(), isNull);
      expect(find.byType(ProductionContents), findsNothing);
      expect(find.text('Songs of the Drowned Quarter'), findsOneWidget);
    });
    testWidgets('its edition and space are in ⋯', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      expect(find.text('Edition'), findsNothing);
      await tester.tap(find.bySemanticsLabel('More').first);
      await tester.pumpAndSettle();
      expect(find.text('Edition'), findsOneWidget);
      expect(find.text('21 Oct 2026'), findsOneWidget);
      expect(find.text('Space'), findsOneWidget);
      expect(find.text('386 MB'), findsOneWidget);
    });
    // P22 rule 16: Title replaces production on screen, and Installed goes.
    testWidgets('⋯’s Details says Titles, and not Installed', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], worlds: [_installed], items: _worldItems);
      await tester.tap(find.bySemanticsLabel('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Productions'), findsNothing);
      expect(find.text('Installed'), findsNothing);
      expect(find.text('Titles'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
    });
    testWidgets('its production page: Play, Read beside it, Chapters', (tester) async {
      await _pump(tester, location: Routes.production(Routes.world('undersong'), 'ledger-of-nights'), worlds: [_installed], items: _worldItems);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('The Weir'), findsOneWidget);
    });
    testWidgets('Library shows the world under Worlds, and its own items are not files (P22l)', (tester) async {
      await _pump(tester, location: Routes.library, worlds: [_installed], items: [..._worldItems, _file]);
      expect(find.text('The Undersong'), findsOneWidget);
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      expect(find.text('Harbour Songs'), findsOneWidget);
      expect(find.text('The Ledger of Nights'), findsNothing);
    });
  });

  group('Worlds (P22d, call 41)', () {
    CatalogueWorld world(String id, String name, {List<String> genres = const [], String? age, bool published = true}) => CatalogueWorld(
      id: id,
      name: name,
      genres: genres,
      age: age,
      keyArt: 'assets/worlds/undersong/key-art.jpg',
      productions: const [CatalogueProduction(id: 'one', title: 'One', kind: 'Book')],
      package: published ? CataloguePackage(url: Uri.parse('https://example.org/$id.zip'), byteLength: 1000000, sha256: 'a' * 64) : null,
    );
    final horror = world('horror', 'Salt', genres: ['Horror', 'Romance'], age: '16+');
    final romance = world('romance', 'Juju', genres: ['Romance'], age: '18+');
    final unpublished = world('western', 'Dust', genres: ['Western'], published: false);

    List<String> cards(WidgetTester tester) => [for (final card in tester.widgetList<WorldShelfCard>(find.byType(WorldShelfCard))) card.name];

    testWidgets('its chips are All and only the genres a listed world has, in the list’s order', (tester) async {
      await _pump(tester, location: Routes.worlds, catalogue: [horror, romance, unpublished]);
      final chips = tester.widget<LabelChips<String>>(find.byType(LabelChips<String>));
      expect([for (final (_, label) in chips.options) label], ['Horror', 'Romance']);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Western'), findsNothing, reason: 'a chip with no world is never drawn');
      expect(find.text('Dust'), findsNothing, reason: 'nothing published, so nothing offered');
      expect(cards(tester), ['Salt', 'Juju']);
    });

    testWidgets('a chip keeps its genre’s worlds, and All brings the rest back', (tester) async {
      await _pump(tester, location: Routes.worlds, catalogue: [horror, romance]);
      await tester.tap(find.text('Horror'));
      await tester.pumpAndSettle();
      expect(cards(tester), ['Salt']);
      await tester.tap(find.text('Romance'));
      await tester.pumpAndSettle();
      expect(cards(tester), ['Salt', 'Juju']);
      await tester.tap(find.text('Horror'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(cards(tester), ['Salt', 'Juju']);
    });

    testWidgets('with no genres in the list, there are no chips to draw', (tester) async {
      await _pump(tester, location: Routes.worlds, catalogue: [world('plain', 'Plain')]);
      expect(find.byType(LabelChips<String>), findsNothing);
      expect(find.text('All'), findsNothing);
      expect(cards(tester), ['Plain']);
    });

    testWidgets('a card’s line is its first genre and its titles, with no size', (tester) async {
      await _pump(tester, location: Routes.worlds, catalogue: [horror]);
      expect(find.text('Horror · 1 title'), findsOneWidget);
      expect(find.textContaining('MB'), findsNothing);
    });

    testWidgets('an 18+ world’s card is in plain view with its 18+, not blurred, and opens asking nothing (call 42)', (tester) async {
      await _pump(tester, location: Routes.worlds, catalogue: [romance]);
      final card = find.byType(WorldShelfCard);
      expect(find.descendant(of: card, matching: find.text('Juju')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('18+')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.byType(ImageFiltered)), findsNothing);
      expect(tester.widget<WorldShelfCard>(card).picture, isNotNull);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(WorldScreen), findsOneWidget);
      expect(find.textContaining('I am 18'), findsNothing);
    });

    group('a card’s size (P22d, P26d)', () {
      final three = [horror, romance, world('third', 'Third')];
      double top(WidgetTester tester, int card) => tester.getTopLeft(find.byType(WorldShelfCard).at(card)).dy;

      testWidgets('358 × 202, one across on a phone', (tester) async {
        await _pump(tester, location: Routes.worlds, catalogue: three);
        expect(tester.getSize(find.byType(WorldShelfCard).first), const Size(358, 202));
        expect(top(tester, 1), greaterThan(top(tester, 0)));
      });

      testWidgets('16:9, two across on a Fold', (tester) async {
        await _pump(tester, location: Routes.worlds, catalogue: three, size: const Size(984, 1092));
        expect(tester.getSize(find.byType(WorldShelfCard).first).aspectRatio, closeTo(16 / 9, 0.01));
        expect(top(tester, 1), top(tester, 0));
        expect(top(tester, 2), greaterThan(top(tester, 0)));
      });

      testWidgets('three across on a tablet sideways', (tester) async {
        await _pump(tester, location: Routes.worlds, catalogue: three, size: const Size(1440, 900));
        expect(top(tester, 2), top(tester, 0));
      });
    });

    testWidgets('a world installing says so on its card, a line of progress under it (P9 rule 4)', (tester) async {
      final installer = _FakeInstaller();
      await _pump(tester, location: Routes.worldsWorld('undersong'), catalogue: [_undersong], installer: installer);
      await tester.tap(_start());
      await tester.pump();
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      final card = find.byType(WorldShelfCard);
      expect(find.descendant(of: card, matching: find.text('Downloading · 37%')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.byType(LinearProgressIndicator)), findsOneWidget);
    });
  });

  group('text at 200% clips no press (acceptance 9)', () {
    for (final (name, location, worlds, items) in [
      ('Worlds', Routes.worlds, const <LibraryWorld>[], const <LibraryItem>[]),
      ('a world not yet here', Routes.world('undersong'), const <LibraryWorld>[], const <LibraryItem>[]),
      ('Home with its covers', Routes.home, const <LibraryWorld>[], [_file]),
      ('the installed world', Routes.world('undersong'), [_installed], _worldItems),
      ('begun, with Continue and Read', Routes.world('undersong'), [_installed], _begun),
      ('its production', Routes.production(Routes.world('undersong'), 'ledger-of-nights'), [_installed], _worldItems),
    ]) {
      testWidgets(name, (tester) async {
        await _pump(tester, location: location, catalogue: [_undersong], worlds: worlds, items: items, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('a world not yet here on a Fold (P22o)', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], size: const Size(984, 1092), textScale: 2);
      expect(tester.takeException(), isNull);
    });
    testWidgets('with no connection', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), catalogue: [_undersong], online: false, textScale: 2);
      expect(tester.takeException(), isNull);
    });
    for (final (name, location) in [
      ('a cover with its genre and age', Routes.home),
      ('a card with its genre and age', Routes.worlds),
      ('a page with its genre and age', Routes.world('undersong')),
    ]) {
      testWidgets(name, (tester) async {
        await _pump(tester, location: location, catalogue: [_adult], textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('a cover’s download', (tester) async {
      await _pump(tester, location: Routes.home, catalogue: [_undersong], installer: _FakeInstaller(), textScale: 2);
      await tester.tap(find.descendant(of: find.byType(WorldCover), matching: _start()));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

/// The band's world: the last listed that does not lead (P16 call 15).
CatalogueWorld _band({String? age}) => CatalogueWorld(
  id: 'band',
  name: 'Band',
  age: age,
  productions: const [CatalogueProduction(id: 'one', title: 'One', kind: 'Book')],
  package: CataloguePackage(url: Uri.parse('https://example.org/band.zip'), byteLength: 1000000, sha256: 'a' * 64),
);
