// Renders P17's screens — a world's Music, Discover's row and song teaser, an album's page, a song
// playing and its lyrics, a character's Theme and a story's music — over The Undersong and its
// music, and saves PNGs to compare with the design's frames (P17a – P17h). Not a gate, like
// shoot_test.dart, so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_p17_test.dart   (from apps/arke_player; PNGs in build/shots)
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_player/app/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'music_fixture.dart';

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
  final icons = FontLoader('MaterialIcons');
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

  setUpAll(_loadFonts);

  Future<void> preload(WidgetTester tester) => tester.runAsync(() async {
    for (final provider in <ImageProvider>[
      for (final asset in ['assets/worlds/undersong/key-art.jpg', 'assets/worlds/undersong/ledger-of-nights.jpg']) AssetImage(asset),
      for (final name in [
        'world-undersong.jpg',
        'ledger-of-nights.jpg',
        'scene4-shot15.jpg',
        'launch-harbour.jpg',
        'scene4-shot14b.jpg',
        'scene4-shot13.jpg',
        'char-chorister.jpg',
        'char-maren.jpg',
      ]) ...[
        FileImage(File(designAsset(name))),
        // A thumbnail decodes at its own size: the dock's 44, the rows' 52.
        for (final width in [88, 104, 132, 156]) ResizeImage(FileImage(File(designAsset(name))), width: width),
      ],
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
    Size size,
    String location, {
    Brightness brightness = Brightness.dark,
    bool installed = true,
    MusicEngine? engine,
    Future<void> Function(WidgetTester tester)? act,
  }) async {
    await preload(tester);
    final key = GlobalKey();
    await pumpMusic(tester, location, size: size, ratio: 2, brightness: brightness, installed: installed, engine: engine, key: key);
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

  /// Brings [target] to [alignment] down the page, as a hand scrolling to it would.
  Future<void> bring(WidgetTester tester, Finder target, {double alignment = 0.1}) async {
    final page = find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down).first;
    await tester.scrollUntilVisible(target, 240, scrollable: page);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(target.first), alignment: alignment);
    await tester.pumpAndSettle();
  }

  MusicEngine playing({int track = 0}) {
    final album = worldMusic().firstWhere((album) => album.production.id == albumId);
    return MusicEngine(album: album, track: track, now: const Duration(minutes: 1, seconds: 48));
  }

  const phone = Size(390, 844);
  const fold = Size(984, 1092);
  final world = Routes.discoverWorld(worldId);
  final album = Routes.production(world, albumId);

  for (final brightness in Brightness.values) {
    for (final (where, size) in [('', phone), ('-fold', fold)]) {
      final suffix = '$where${brightness == Brightness.dark ? '' : '-light'}';
      testWidgets(
        'P17a a world with music$suffix',
        (t) => shoot(
          t,
          'P17a-world$suffix',
          size,
          world,
          brightness: brightness,
          installed: false,
          act: (tester) => bring(tester, find.text('Listen'), alignment: 0.15),
        ),
      );
      // Stories ending, then Music, then the Teasers with the song first (P17b).
      testWidgets(
        'P17b Discover$suffix',
        (t) => shoot(
          t,
          'P17b-discover$suffix',
          size,
          Routes.discover,
          brightness: brightness,
          act: (tester) => bring(tester, find.text('Music'), alignment: where.isEmpty ? 0.3 : 0.2),
        ),
      );
      testWidgets(
        'P17c an album$suffix',
        (t) => shoot(t, '${where.isEmpty ? 'P17c' : 'P17h'}-album$suffix', size, album, brightness: brightness, engine: playing()),
      );
      testWidgets(
        'P17d a song playing$suffix',
        (t) => shoot(t, 'P17d-playing$suffix', size, Routes.music(worldId, albumId), brightness: brightness, engine: playing()),
      );
      testWidgets(
        'P17e its lyrics$suffix',
        (t) => shoot(
          t,
          'P17e-lyrics$suffix',
          size,
          Routes.music(worldId, albumId),
          brightness: brightness,
          engine: playing(),
          act: (tester) => tester.tap(find.text('Lyrics')),
        ),
      );
      // Nothing playing, so the rows offer play.
      testWidgets(
        'P17f a theme$suffix',
        (t) => shoot(t, 'P17f-theme$suffix', size, Routes.guideEntry(world, 'the-chorister'), brightness: brightness, engine: MusicEngine(playing: false)),
      );
      testWidgets(
        'P17g a story’s chapters$suffix',
        (t) => shoot(
          t,
          'P17g-story$suffix',
          size,
          Routes.production(world, ledgerId),
          brightness: brightness,
          engine: MusicEngine(playing: false),
          act: (tester) => bring(tester, find.text('Chapter 7'), alignment: 0.15),
        ),
      );
      testWidgets(
        'P17g a story’s music$suffix',
        (t) => shoot(
          t,
          'P17g-music$suffix',
          size,
          Routes.production(world, ledgerId),
          brightness: brightness,
          engine: MusicEngine(playing: false),
          act: (tester) => bring(tester, find.text('Music'), alignment: 0.5),
        ),
      );
    }
  }
}
