// Renders P21's screens — a graphic novel's own page, the reader as it opens and at rest, its Pages,
// and a Fold open's spread — over the real published Ledger of Nights, drawn, and saves PNGs to
// compare with the design's frames. Not a gate, like the other shoot tests, so it runs only
// when asked, with the package's path:
//
//   SHOOT=1 COMIC_ZIP=<the-ledger-of-nights-drawn-comic-*.zip> flutter test test/shoot_p21_test.dart
//
// from apps/arke_player; PNGs in build/shots.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/features/comics/application/comics.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'story_fixture.dart';

final _shoot = Platform.environment['SHOOT'] == '1';
final _zipPath = Platform.environment['COMIC_ZIP'];

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

void main() {
  if (!_shoot || _zipPath == null) {
    test('shots are taken only with SHOOT=1 and COMIC_ZIP', () {}, skip: 'set SHOOT=1 and COMIC_ZIP to render the screens');
    return;
  }

  setUpAll(_loadFonts);
  final zip = _zipPath!;

  // The real package, opened as the Player opens it.
  final manifest = readWorldPackage(zip);
  final production = manifest.productions.single;
  final document = manifest.comics[production.id]!;
  final unpacked = Directory('build/shots/comic')..createSync(recursive: true);
  extractFileToDisk(zip, unpacked.path);
  String pathOf(String asset) => '${unpacked.path}/${manifest.assets[asset]!.path}';
  final comic = LoadedComic(
    worldId: worldId,
    worldName: 'The Undersong',
    production: LibraryProduction(
      id: production.id,
      title: production.title,
      picture: pathOf(production.picture!),
      comic: LibraryComic(
        document: pathOf(production.comic!),
        reading: document.reading.name,
        aspect: document.aspect,
        chapters: document.chapters.length,
        pages: document.pages.length,
      ),
      package: LibraryProductionPackage(
        edition: manifest.edition,
        fingerprint: editionFingerprint(manifest),
        byteLength: File(zip).lengthSync(),
        installedAt: DateTime.utc(2026, 10, 30),
        folder: unpacked.path,
      ),
    ),
    document: document,
    pathOf: pathOf,
  );

  Future<void> preload(WidgetTester tester) => tester.runAsync(() async {
    for (final page in document.pages) {
      for (final provider in <ImageProvider>[FileImage(File(pathOf(page.picture))), for (final width in [168, 312, 400]) ResizeImage(FileImage(File(pathOf(page.picture))), width: width)]) {
        final loaded = Completer<void>();
        provider.resolve(ImageConfiguration.empty).addListener(
          ImageStreamListener((_, _) => loaded.isCompleted ? null : loaded.complete(), onError: (_, _) => loaded.isCompleted ? null : loaded.complete()),
        );
        await loaded.future;
      }
    }
  });

  Future<void> shoot(WidgetTester tester, String name, Size size, String location, {Future<void> Function(WidgetTester tester)? act}) async {
    await preload(tester);
    final key = GlobalKey();
    await pumpStories(tester, location, stories: const [], comics: [comic], size: size, ratio: 2, brightness: Brightness.dark, key: key);
    if (act != null) {
      await act(tester);
      await tester.pumpAndSettle();
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    File('build/shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  const phone = Size(390, 844);
  const fold = Size(984, 1092);
  final world = Routes.libraryWorld(worldId);
  final page = Routes.production(world, production.id);
  final reader = Routes.comic(worldId, production.id);

  for (final (where, size) in [('', phone), ('-fold', fold)]) {
    testWidgets('P21d its page$where', (t) => shoot(t, 'P21d-page$where', size, page));
    testWidgets('P21e the reader as it opens$where', (t) => shoot(t, 'P21e-opens$where', size, reader));
    testWidgets(
      'P21f the reader at rest$where',
      (t) => shoot(t, 'P21f-rest$where', size, reader, act: (tester) async => tester.pump(const Duration(seconds: 3))),
    );
    testWidgets(
      'P21g Pages$where',
      (t) => shoot(t, 'P21g-pages$where', size, reader, act: (tester) async => tester.tap(find.byTooltip('Pages'))),
    );
  }
}
