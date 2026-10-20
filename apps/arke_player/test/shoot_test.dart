// Renders the shelves with the real fonts and pictures and saves them as PNGs, to compare with the
// design's frames (P8). Not a gate — pixels differ by platform — so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_test.dart        (from apps/arke_player; PNGs in build/shots)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _shoot = Platform.environment['SHOOT'] == '1';

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
        chapters: const [Chapter(title: 'One', start: Duration.zero), Chapter(title: 'Two', start: Duration(hours: 1)), Chapter(title: 'Three', start: Duration(hours: 2)), Chapter(title: 'Four', start: Duration(hours: 3))],
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

  tearDownAll(() => root.deleteSync(recursive: true));

  Future<void> shoot(WidgetTester tester, String name, Size size, String location, {List<LibraryItem>? with_, Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 47 * 2, bottom: 34 * 2);
    addTearDown(tester.view.reset);
    final shown = with_ ?? items;
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith((ref) => Stream.value(shown)),
          libraryStoreProvider.overrideWith((ref) async => store),
          volumeProvider.overrideWith((ref) async => (free: 41000000000, total: 128000000000)),
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
    await tester.pump(const Duration(milliseconds: 100));
    stderr.writeln('$name: pumped');
    // Pictures decode off the fake clock.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    stderr.writeln('$name: precached');
    await tester.pump(const Duration(milliseconds: 100));
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
  testWidgets('P8d home, with files', (t) => shoot(t, 'P8d-home', phone, Routes.home), timeout: const Timeout(Duration(seconds: 60)));
  testWidgets('P8c library', (t) => shoot(t, 'P8c-library', phone, Routes.library));
  testWidgets('P8e library on a fold', (t) => shoot(t, 'P8e-library-fold', fold, Routes.library));
  testWidgets('P8f you', (t) => shoot(t, 'P8f-you', phone, Routes.you));
  testWidgets('P6a downloads', (t) => shoot(t, 'P6a-downloads', phone, Routes.downloads));
  testWidgets('P8d home, dark', (t) => shoot(t, 'P8d-home-dark', phone, Routes.home, brightness: Brightness.dark));
  testWidgets('P6e home on a fold', (t) => shoot(t, 'P6e-home-fold', fold, Routes.home));
}
