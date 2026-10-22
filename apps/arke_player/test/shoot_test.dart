// Renders the shelves with the real fonts and pictures and saves them as PNGs, to compare with the
// design's frames (P8). Not a gate — pixels differ by platform — so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_test.dart        (from apps/arke_player; PNGs in build/shots)
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _shoot = Platform.environment['SHOOT'] == '1';

// P9: The Undersong as the catalogue offers it, and as it is once installed.
final _undersong = CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour.',
  keyArt: 'assets/worlds/undersong/key-art.jpg',
  productions: const [
    CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook · Book · 2 h 03 m', picture: 'assets/worlds/undersong/ledger-of-nights.jpg'),
  ],
  package: CataloguePackage(url: Uri.parse('https://example.org/undersong.zip'), byteLength: 386000000, sha256: 'a' * 64),
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

Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Geist Sans', ['GeistSans-400', 'GeistSans-500', 'GeistSans-600', 'GeistSans-700']),
    ('Jost', ['Jost-200', 'Jost-300', 'Jost-400']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$file.ttf').readAsBytesSync())));
    }
    await loader.load();
  }
  // Material's icons, so the tab bar and presses draw as they will on a phone.
  final icons = FontLoader('MaterialIcons');
  // flutter_tester sits in <sdk>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent.path;
  final iconFont = File('$artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconFont.existsSync()) {
    icons.addFont(Future.value(ByteData.sublistView(iconFont.readAsBytesSync())));
    await icons.load();
  }
}

void main() {
  if (!_shoot) {
    test('shots are taken only with SHOOT=1', () {}, skip: 'set SHOOT=1 to render the screens');
    return;
  }

  late Directory root;
  late LibraryStore store;
  late List<LibraryItem> items;
  late LibraryWorld installed;
  late List<LibraryItem> worldItems;

  setUpAll(() async {
    await _loadFonts();
    root = Directory.systemTemp.createTempSync('arke-player-shots-');
    store = LibraryStore(root);
    String cover(String id, String picture) {
      final dir = store.itemDirectory(id)..createSync(recursive: true);
      File('../../design/assets/$picture').copySync('${dir.path}/cover.jpg');
      return 'items/$id/cover.jpg';
    }

    final now = DateTime.utc(2026, 10, 20, 9);
    items = [
      LibraryItem(
        id: 'tide',
        format: FileFormat.m4b,
        title: 'Tidewater Sessions',
        author: 'Amaal Reyes',
        duration: const Duration(hours: 6, minutes: 12),
        byteLength: 288000000,
        addedAt: now.subtract(const Duration(days: 6)),
        file: 'items/tide/media.m4b',
        cover: cover('tide', 'launch-harbour.jpg'),
        chapters: const [
          Chapter(title: 'One', start: Duration.zero),
          Chapter(title: 'Two', start: Duration(hours: 1)),
          Chapter(title: 'Three', start: Duration(hours: 2)),
          Chapter(title: 'Four', start: Duration(hours: 3)),
        ],
        place: Place(position: const Duration(hours: 3, minutes: 44), progress: 0.62, updatedAt: now),
      ),
      LibraryItem(
        id: 'songs',
        format: FileFormat.mp3,
        title: 'Harbour Songs',
        duration: const Duration(minutes: 3, seconds: 42),
        byteLength: 8000000,
        addedAt: now.subtract(const Duration(days: 5)),
        file: 'items/songs/media.mp3',
        cover: cover('songs', 'banner-audio.jpg'),
      ),
      LibraryItem(
        id: 'almanac',
        format: FileFormat.epub,
        title: 'The Salt Almanac',
        author: 'Ines Varga',
        byteLength: 2100000,
        addedAt: now.subtract(const Duration(days: 4)),
        file: 'items/almanac/media.epub',
        cover: cover('almanac', 'char-maren.jpg'),
      ),
      LibraryItem(
        id: 'boards',
        format: FileFormat.pdf,
        title: 'Saltlight boards',
        pages: 24,
        byteLength: 18000000,
        addedAt: now.subtract(const Duration(days: 3)),
        file: 'items/boards/media.pdf',
        cover: cover('boards', 'scene4-board-sheet.jpg'),
      ),
      LibraryItem(
        id: 'ferry',
        format: FileFormat.mov,
        title: 'Night Ferry',
        duration: const Duration(hours: 1, minutes: 48),
        byteLength: 2400000000,
        addedAt: now.subtract(const Duration(days: 2)),
        file: 'items/ferry/media.mov',
        cover: cover('ferry', 'drowned-quarter.jpg'),
        place: Place(position: const Duration(minutes: 56), progress: 0.52, updatedAt: now.subtract(const Duration(hours: 3))),
      ),
      LibraryItem(
        id: 'reel',
        format: FileFormat.mp4,
        title: 'Lighthouse reel',
        duration: const Duration(minutes: 12),
        byteLength: 410000000,
        addedAt: now.subtract(const Duration(days: 1)),
        file: 'items/reel/media.mp4',
        cover: cover('reel', 'banner-video.jpg'),
      ),
    ];
  });

  setUpAll(() {
    String place(String relative, String picture) {
      final file = File(store.resolve(relative))..parent.createSync(recursive: true);
      File('../../design/assets/$picture').copySync(file.path);
      return relative;
    }

    installed = LibraryWorld(
      id: 'undersong',
      edition: '2026-10-21',
      name: 'The Undersong',
      logline: 'A drowned god still sings beneath the harbour.',
      keyArt: place('worlds/undersong/key-art.jpg', 'world-undersong.jpg'),
      byteLength: 386000000,
      installedAt: DateTime.utc(2026, 10, 21),
      productions: [
        LibraryProduction(
          id: 'ledger-of-nights',
          title: 'The Ledger of Nights',
          picture: place('worlds/undersong/ledger-of-nights/picture.jpg', 'banner-story.jpg'),
          book: 'undersong.ledger-of-nights.book',
          narration: 'undersong.ledger-of-nights.narration',
        ),
      ],
    );
    worldItems = [
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
          Chapter(title: 'Saltmouth Bells', start: Duration(minutes: 61)),
          Chapter(title: 'A Choir Underwater', start: Duration(minutes: 82)),
          Chapter(title: 'The Keeper’s Ledger', start: Duration(minutes: 102)),
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
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  /// Loads every cover into the image cache on the real clock, under the exact keys the widgets
  /// ask for (`Image.file(cacheWidth:)`), so the screens find them decoded. Loading them from inside
  /// the test's fake clock never completes.
  Future<void> preload(WidgetTester tester) => tester.runAsync(() async {
    final opening = Completer<void>();
    const AssetImage('assets/images/first-open.jpg')
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((_, _) => opening.isCompleted ? null : opening.complete(), onError: (_, _) => opening.isCompleted ? null : opening.complete()),
        );
    await opening.future;
    // P9's pictures: the catalogue's bundled ones, and an installed world's files, drawn uncropped.
    for (final provider in <ImageProvider>[
      const AssetImage('assets/worlds/undersong/key-art.jpg'),
      const AssetImage('assets/worlds/undersong/ledger-of-nights.jpg'),
      FileImage(File(store.resolve('worlds/undersong/key-art.jpg'))),
      FileImage(File(store.resolve('worlds/undersong/ledger-of-nights/picture.jpg'))),
    ]) {
      final loaded = Completer<void>();
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener((_, _) => loaded.isCompleted ? null : loaded.complete(), onError: (_, _) => loaded.isCompleted ? null : loaded.complete()),
          );
      await loaded.future;
    }
    for (final item in items) {
      if (item.cover == null) continue;
      final file = File(store.resolve(item.cover!));
      for (final width in const [44.0, 52.0, 120.0, 300.0, 420.0]) {
        final provider = ResizeImage.resizeIfNeeded((width * 3).round(), null, FileImage(file));
        final loaded = Completer<void>();
        provider
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener((_, _) => loaded.isCompleted ? null : loaded.complete(), onError: (_, _) => loaded.isCompleted ? null : loaded.complete()),
            );
        await loaded.future;
      }
      final full = Completer<void>();
      FileImage(file)
          .resolve(ImageConfiguration.empty)
          .addListener(ImageStreamListener((_, _) => full.isCompleted ? null : full.complete(), onError: (_, _) => full.isCompleted ? null : full.complete()));
      await full.future;
    }
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Size size,
    String location, {
    List<LibraryItem>? with_,
    Brightness brightness = Brightness.light,
    List<CatalogueWorld> catalogue = const [],
    List<LibraryWorld> worlds = const [],
    WorldInstaller? installer,
    Future<void> Function(WidgetTester tester)? act,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 47 * 2, bottom: 34 * 2);
    addTearDown(tester.view.reset);
    final shown = with_ ?? items;
    await preload(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith((ref) => Stream.value(shown)),
          libraryStoreProvider.overrideWith((ref) async => store),
          volumeProvider.overrideWith((ref) async => (free: 41000000000, total: 128000000000)),
          catalogueProvider.overrideWith((ref) async => catalogue),
          libraryWorldsProvider.overrideWith((ref) => Stream.value(worlds)),
          if (installer != null) worldInstallerProvider.overrideWith((ref) async => installer),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: arkeTheme(brightness),
            routerConfig: buildRouter(initialLocation: location),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (act != null) {
      await act(tester);
      await tester.pumpAndSettle();
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  const phone = Size(390, 844);
  const fold = Size(984, 1092);
  testWidgets('P8a first open', (t) => shoot(t, 'P8a-first-open', phone, Routes.welcome, with_: const []));
  testWidgets('P8b home, nothing added', (t) => shoot(t, 'P8b-home-empty', phone, Routes.home, with_: const []));
  testWidgets('P8d home, with files', (t) => shoot(t, 'P8d-home', phone, Routes.home));
  testWidgets('P8c library', (t) => shoot(t, 'P8c-library', phone, Routes.library));
  testWidgets('P8e library on a fold', (t) => shoot(t, 'P8e-library-fold', fold, Routes.library));
  testWidgets('P8f you', (t) => shoot(t, 'P8f-you', phone, Routes.you));
  testWidgets('P6a downloads', (t) => shoot(t, 'P6a-downloads', phone, Routes.downloads));
  testWidgets('P8d home, dark', (t) => shoot(t, 'P8d-home-dark', phone, Routes.home, brightness: Brightness.dark));
  testWidgets('P6e home on a fold', (t) => shoot(t, 'P6e-home-fold', fold, Routes.home));

  Future<void> install(WidgetTester tester) => tester.tap(find.textContaining('Install').last);
  testWidgets('P9a first open, with a world to install', (t) => shoot(t, 'P9a-first-open', phone, Routes.welcome, with_: const [], catalogue: [_undersong]));
  testWidgets('P9c a world to install', (t) => shoot(t, 'P9c-world-to-install', phone, Routes.world('undersong'), catalogue: [_undersong]));
  testWidgets(
    'P9d installing',
    (t) => shoot(t, 'P9d-installing', phone, Routes.world('undersong'), catalogue: [_undersong], installer: _FakeInstaller(), act: install),
  );
  testWidgets(
    'P9e not installed',
    (t) => shoot(
      t,
      'P9e-not-installed',
      phone,
      Routes.world('undersong'),
      catalogue: [_undersong],
      installer: _FakeInstaller(refusal: const NoConnection()),
      act: install,
    ),
  );
  testWidgets(
    'P9f installed',
    (t) => shoot(t, 'P9f-installed', phone, Routes.world('undersong'), with_: [...items, ...worldItems], catalogue: [_undersong], worlds: [installed]),
  );
  testWidgets('P9g home with available', (t) => shoot(t, 'P9g-home', phone, Routes.home, catalogue: [_undersong]));
  testWidgets('P9h a world to install on a fold', (t) => shoot(t, 'P9h-world-fold', fold, Routes.world('undersong'), catalogue: [_undersong]));
  testWidgets(
    'P1e production',
    (t) => shoot(
      t,
      'P9-production',
      phone,
      Routes.production(Routes.world('undersong'), 'ledger-of-nights'),
      with_: [...items, ...worldItems],
      worlds: [installed],
    ),
  );
  testWidgets('P9c dark', (t) => shoot(t, 'P9c-world-to-install-dark', phone, Routes.world('undersong'), catalogue: [_undersong], brightness: Brightness.dark));
}
