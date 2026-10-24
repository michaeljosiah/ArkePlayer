// Renders a world's newer edition (P12) with the real fonts and pictures, to compare with the
// design's frames. Not a gate — pixels differ by platform — so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_update_test.dart        (from apps/arke_player; PNGs in build/shots)
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _shoot = Platform.environment['SHOOT'] == '1';
const _ledger = 'the-ledger-of-nights';

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
  final icons = FontLoader('MaterialIcons');
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent.path;
  final iconFont = File('$artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconFont.existsSync()) {
    icons.addFont(Future.value(ByteData.sublistView(iconFont.readAsBytesSync())));
    await icons.load();
  }
}

/// An update that reports how far it has come and then waits, or refuses at once (P12c, P12f).
class _Installer extends WorldInstaller {
  _Installer(LibraryStore store, {this.refusal}) : super(store: store, freeBytes: (_) async => null);
  final InstallRefusal? refusal;

  @override
  Future<LibraryWorld> update(CatalogueWorld world, {void Function(InstallStep step)? onStep, InstallCancel? cancel, Future<void> Function()? beforeSwap}) {
    if (refusal != null) return Future.error(refusal!);
    onStep?.call(const Downloading(120000000, 228000000));
    return Completer<LibraryWorld>().future;
  }
}

void main() {
  if (!_shoot) {
    test('shots are taken only with SHOOT=1', () {}, skip: 'set SHOOT=1 to render the screens');
    return;
  }

  late Directory root;
  late LibraryStore store;
  final assets = Directory('../../design/assets').absolute.path;

  CatalogueWorld undersong({String edition = '2026-10-22', String fingerprint = 'b'}) => CatalogueWorld(
    id: 'undersong',
    name: 'The Undersong',
    logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
    keyArt: 'assets/worlds/undersong/key-art.jpg',
    productions: const [
      CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook · Book · 8 h 2 m', picture: 'assets/worlds/undersong/ledger-of-nights.jpg'),
    ],
    package: CataloguePackage(
      url: Uri.parse('https://example.org/undersong.zip'),
      byteLength: 228000000,
      sha256: 'a' * 64,
      edition: edition,
      fingerprint: fingerprint * 64,
    ),
  );
  final copper = CatalogueWorld(
    id: 'copper-saints',
    name: 'Copper Saints',
    productions: const [
      CatalogueProduction(title: 'One', kind: 'Book'),
      CatalogueProduction(title: 'Two', kind: 'Book'),
    ],
    package: CataloguePackage(url: Uri.parse('https://example.org/copper.zip'), byteLength: 240000000, sha256: 'c' * 64),
  );

  late LibraryWorld before;
  late LibraryWorld after;
  late List<LibraryItem> items;

  setUpAll(() async {
    await _loadFonts();
    root = Directory.systemTemp.createTempSync('arke-player-update-shots-');
    store = LibraryStore(root);
    String place(String relative, String picture) {
      final file = File(store.resolve(relative))..parent.createSync(recursive: true);
      File('$assets/$picture').copySync(file.path);
      return relative;
    }

    LibraryWorld world(String edition, int bytes, String fingerprint) => LibraryWorld(
      id: 'undersong',
      edition: edition,
      name: 'The Undersong',
      logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
      keyArt: place('worlds/undersong/key-art.jpg', 'world-undersong.jpg'),
      byteLength: bytes,
      installedAt: DateTime.utc(2026, 10, 20),
      fingerprint: fingerprint * 64,
      productions: [
        LibraryProduction(
          id: _ledger,
          title: 'The Ledger of Nights',
          picture: place('worlds/undersong/ledger/picture.jpg', 'banner-story.jpg'),
          book: 'undersong.ledger.book',
          narration: 'undersong.ledger.listening',
        ),
      ],
    );
    before = world('2026-10-20', 182000000, 'a');
    after = world('2026-10-22', 228000000, 'b');
    items = [
      LibraryItem(
        id: 'undersong.ledger.listening',
        format: FileFormat.listening,
        title: 'The Ledger of Nights',
        byteLength: 120000000,
        addedAt: DateTime.utc(2026, 10, 20),
        file: 'worlds/undersong/ledger/listening.json',
        duration: const Duration(hours: 8, minutes: 2),
        worldId: 'undersong',
        place: Place(progress: 0.31, position: const Duration(hours: 2, minutes: 30), locator: 'ch04', updatedAt: DateTime.utc(2026, 10, 22)),
      ),
      LibraryItem(
        id: 'undersong.ledger.book',
        format: FileFormat.epub,
        title: 'The Ledger of Nights',
        byteLength: 400000,
        addedAt: DateTime.utc(2026, 10, 20),
        file: 'worlds/undersong/ledger/book.epub',
        worldId: 'undersong',
      ),
    ];
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  Future<void> preload(WidgetTester tester) => tester.runAsync(() async {
    for (final provider in <ImageProvider>[
      const AssetImage('assets/worlds/undersong/key-art.jpg'),
      FileImage(File(store.resolve(before.keyArt!))),
      FileImage(File(store.resolve(before.productions.single.picture!))),
    ]) {
      final loaded = Completer<void>();
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener((_, _) => loaded.isCompleted ? null : loaded.complete(), onError: (_, _) => loaded.isCompleted ? null : loaded.complete()),
          );
      await loaded.future;
    }
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    String location, {
    LibraryWorld? installed,
    InstallRefusal? refusal,
    Brightness brightness = Brightness.dark,
    Future<void> Function(WidgetTester tester)? act,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 47 * 2, bottom: 34 * 2);
    addTearDown(tester.view.reset);
    await preload(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith((ref) => Stream.value(items)),
          libraryStoreProvider.overrideWith((ref) async => store),
          volumeProvider.overrideWith((ref) async => (free: refusal is NeedsSpace ? 20000000 : 41000000000, total: 128000000000)),
          catalogueProvider.overrideWith((ref) async => [undersong(), copper]),
          libraryWorldsProvider.overrideWith((ref) => Stream.value([installed ?? before])),
          worldGuideProvider.overrideWith((ref, worldId) async => null),
          guideFetchProvider.overrideWith((ref, worldId) async {}),
          worldInstallerProvider.overrideWith((ref) async => _Installer(store, refusal: refusal)),
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

  final world = Routes.discoverWorld('undersong');
  Future<void> update(WidgetTester tester) => tester.tap(find.text('Update · 228 MB', findRichText: true));

  testWidgets('P12a worlds with an update', (t) => shoot(t, 'P12a-worlds-update', Routes.discover));
  testWidgets('P12b a newer edition', (t) => shoot(t, 'P12b-newer-edition', world));
  testWidgets('P12b, light', (t) => shoot(t, 'P12b-newer-edition-light', world, brightness: Brightness.light));
  testWidgets('P12c updating', (t) => shoot(t, 'P12c-updating', world, act: update));
  testWidgets('P12d updated', (t) => shoot(t, 'P12d-updated', world, installed: after));
  testWidgets(
    'P12e downloads',
    (t) => shoot(
      t,
      'P12e-downloads',
      world,
      act: (tester) async {
        await update(tester);
        await tester.pump();
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go(Routes.downloads);
      },
    ),
  );
  testWidgets('P12f not updated', (t) => shoot(t, 'P12f-not-updated', world, refusal: const NeedsSpace(456000000, 20000000), act: update));
}
