// Renders the audiobook player over an installed world's illustrated narration and saves PNGs, to
// compare with the design's frames (P5a, P6f; SPEC-058 R-22 – R-24). Not a gate, like
// shoot_test.dart, so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_listening_test.dart   (from apps/arke_player; PNGs in build/shots)
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/players/application/audio_engine.dart';
import 'package:arke_player/features/players/application/listening_plan.dart';
import 'package:arke_player/features/players/application/players.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _shoot = Platform.environment['SHOOT'] == '1';

/// Who Here shows.
const _cast = Guide(
  productions: [],
  characters: [
    GuideCharacter(
      id: 'maren',
      name: 'Maren Kest',
      role: 'Tide-caller',
      portrait: 'char-maren.jpg',
      sections: [GuideSection(heading: 'Essence', text: '.')],
    ),
    GuideCharacter(
      id: 'bray',
      name: 'Bray Half-Hitch',
      role: 'Rigger',
      portrait: 'char-bray.jpg',
      sections: [GuideSection(heading: 'Essence', text: '.')],
    ),
    GuideCharacter(
      id: 'chorister',
      name: 'The Chorister',
      role: 'Keeper of the drowned verse',
      portrait: 'char-chorister.jpg',
      sections: [GuideSection(heading: 'Essence', text: '.')],
    ),
  ],
  places: [],
  lore: [],
);
const _design = '../../design/assets';
const _media = '../../packages/arke_media/test/fixtures';

/// An engine held still at one moment of the narration: tests never play.
class _StillEngine implements AudioEngine {
  _StillEngine(this.item, this.plan, this.now);

  @override
  final LibraryItem item;
  @override
  final ListeningPlan plan;
  @override
  final Duration now;
  @override
  final artwork = ValueNotifier<String?>(null);

  @override
  Stream<Duration> get position => Stream.value(now);
  @override
  Stream<bool> get playingStream => Stream.value(false);
  @override
  bool get playing => false;
  @override
  double get speed => 1;
  @override
  SleepTimer get sleep => SleepTimer.off;
  @override
  Duration get length => plan.document.duration;

  @override
  int chapterAt(Duration position) => plan.locate(position).$1;

  @override
  (Duration, Duration) chapterBounds(Duration position) {
    final index = chapterAt(position);
    return (plan.starts[index], plan.starts[index] + plan.chapters[index].duration);
  }

  @override
  Future<void> open(
    LibraryItem item, {
    String? path,
    ListeningPlan? plan,
    String? artPath,
    Duration? startAt,
    required double speed,
    required void Function(Place place, {bool? finished}) keep,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsController {
  _Settings(this.fixed);

  final DeviceSettings fixed;

  @override
  Future<DeviceSettings> build() async => fixed;
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

  late Directory root;
  late LibraryStore store;
  late LibraryItem item;
  late ListeningPlan plan;

  setUpAll(() async {
    await _loadFonts();
    root = Directory.systemTemp.createTempSync('arke-player-listening-shots-');
    final source = Directory('${root.path}/source')..createSync();
    for (final name in ['ch1.m4a', 'ch2.m4a']) {
      File('$_media/chapters.m4b').copySync('${source.path}/$name');
    }
    // Two chapters of six seconds: the opening, a wide picture at 1 s with its focus, a tall one at
    // 3 s; then the rail book on the wide one again, made Tall as well (P14), with a phrase for Text.
    // The Tall picture is P14's own when the design has it, else Maren's portrait.
    final tall = File('$_design/maren-ledger-tall.jpg').existsSync() ? '$_design/maren-ledger-tall.jpg' : '$_design/char-maren.jpg';
    final spec = WorldSpec(
      id: 'undersong',
      edition: '2026-10-21',
      name: 'The Undersong',
      keyArt: '$_design/world-undersong.jpg',
      productions: [
        ProductionSpec(
          id: 'ledger-of-nights',
          title: 'The Ledger of Nights',
          book: '$_media/book.epub',
          listening: {
            'title': 'The Ledger of Nights',
            'cover': '$_design/world-undersong.jpg',
            'chapters': [
              {
                'id': 'neap',
                'title': 'Neap',
                'audio': '${source.path}/ch1.m4a',
                'book': 'OEBPS/chapter-1.xhtml',
                'opening': '$_design/world-undersong.jpg',
                'pictures': [
                  {
                    'at': 1000,
                    'picture': '$_design/drowned-quarter.jpg',
                    'focus': {'x': 0.62, 'y': 0.4},
                  },
                  {'at': 3000, 'picture': '$_design/char-maren.jpg'},
                ],
                'phrases': [
                  {'at': 1200, 'end': 2800, 'text': 'The tide-clock keeps the drowned god’s hours, and nobody in Saltmouth winds it.'},
                ],
              },
              {
                'id': 'the-rail-book',
                'title': 'The rail book',
                'audio': '${source.path}/ch2.m4a',
                'pictures': [
                  {
                    'at': 0,
                    'picture': '$_design/drowned-quarter.jpg',
                    'tall': tall,
                    'focus': {'x': 1, 'y': 0.5},
                  },
                ],
                'phrases': [
                  {'at': 500, 'end': 5000, 'text': 'Odile did not answer. She held the lamp lower.'},
                ],
              },
            ],
          },
        ),
      ],
    );
    await packWorld(spec, '${source.path}/world.zip');
    store = LibraryStore(Directory('${root.path}/library'));
    await store.load();
    final installer = WorldInstaller(store: store, freeBytes: (_) async => null);
    final zip = File('${source.path}/world.zip');
    final prepared = await installer.prepareFile(size: await zip.length(), open: zip.openRead);
    await installer.commit(prepared);
    item = store.items.singleWhere((item) => item.worldId == 'undersong' && item.kind == LibraryKind.listen);
    plan = await loadListeningPlan(store, item);
  });

  Future<void> shoot(WidgetTester tester, String name, Size size, Duration at, {bool text = false, Future<void> Function(WidgetTester tester)? act}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 47 * 2, bottom: 34 * 2);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      for (final path in {
        for (final chapter in plan.chapters) ...[
          for (final picture in chapter.pictures) ...[plan.pathOf(picture.picture), if (picture.tall != null) plan.pathOf(picture.tall!)],
        ],
      }..add(plan.pathOf(plan.document.cover!))) {
        final loaded = Completer<void>();
        FileImage(File(path))
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener((_, _) => loaded.isCompleted ? null : loaded.complete(), onError: (_, _) => loaded.isCompleted ? null : loaded.complete()),
            );
        await loaded.future;
      }
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith((ref) => Stream.value(store.items)),
          libraryStoreProvider.overrideWith((ref) async => store),
          libraryWorldsProvider.overrideWith((ref) => Stream.value(store.worlds)),
          catalogueProvider.overrideWith((ref) async => const []),
          worldGuideProvider.overrideWith((ref, worldId) async => WorldGuide(guide: _cast, pathOf: (asset) => '$_design/$asset')),
          guideReachProvider.overrideWith((ref, worldId) async => GuideReach.none),
          audioEngineProvider.overrideWithValue(_StillEngine(item, plan, at)),
          settingsProvider.overrideWith(() => _Settings(DeviceSettings(text: text))),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: arkeTheme(Brightness.dark),
            routerConfig: buildRouter(initialLocation: Routes.open(item.id)),
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
  // P24: the upright player at rest, a tap, its two sheets, turned, on a Fold and upright on a tablet.
  Duration tallAt() => plan.starts[1] + const Duration(seconds: 1);
  testWidgets('P24c at rest', (t) => shoot(t, 'P24c-rest', phone, tallAt()));
  testWidgets('P24c with Text', (t) => shoot(t, 'P24c-rest-text', phone, tallAt(), text: true));
  testWidgets('P24d a tap', (t) => shoot(t, 'P24d-tap', phone, tallAt(), act: (tester) => tester.tapAt(const Offset(195, 300))));
  testWidgets('P24e here', (t) => shoot(t, 'P24e-here', phone, tallAt(), act: (tester) => tester.tap(find.text('Here'))));
  testWidgets('P24f episodes', (t) => shoot(t, 'P24f-episodes', phone, tallAt(), act: (tester) => tester.tap(find.text('Episodes'))));
  testWidgets('P24i turned', (t) => shoot(t, 'P24i-turned', const Size(844, 390), tallAt()));
  testWidgets('P24j on a fold', (t) => shoot(t, 'P24j-fold', fold, tallAt(), text: true));
  testWidgets('P27o upright on a tablet', (t) => shoot(t, 'P27o-tablet', const Size(800, 1280), tallAt()));
  const tablet = Size(1280, 800);
  testWidgets('P27c sideways on a tablet', (t) => shoot(t, 'P27c-tablet', tablet, tallAt()));
  testWidgets('P27e a tap', (t) => shoot(t, 'P27e-tap', tablet, tallAt(), act: (tester) => tester.tapAt(const Offset(500, 300))));
  testWidgets('P27f here', (t) => shoot(t, 'P27f-here', tablet, tallAt(), act: (tester) => tester.tap(find.text('Here'))));
  testWidgets('P27g episodes', (t) => shoot(t, 'P27g-episodes', tablet, tallAt(), act: (tester) => tester.tap(find.text('Episodes'))));
  testWidgets('P27h caught up', (t) => shoot(t, 'P27h-caught-up', tablet, plan.document.duration));
  testWidgets('P24h caught up', (t) => shoot(t, 'P24h-caught-up', phone, plan.document.duration));
  testWidgets('P27p here upright', (t) => shoot(t, 'P27p-here', const Size(800, 1280), tallAt(), act: (tester) => tester.tap(find.text('Here'))));
  testWidgets('P5a the picture of the moment', (t) => shoot(t, 'P5a-listening', phone, const Duration(milliseconds: 2000)));
  testWidgets('P5a with Text', (t) => shoot(t, 'P5a-listening-text', phone, const Duration(milliseconds: 1500), text: true));
  testWidgets('P5a a tall picture', (t) => shoot(t, 'P5a-listening-tall', phone, const Duration(milliseconds: 4000)));
  testWidgets('P5a the opening', (t) => shoot(t, 'P5a-listening-opening', phone, const Duration(milliseconds: 400)));
  testWidgets('P6f on a fold', (t) => shoot(t, 'P6f-listening-fold', fold, const Duration(milliseconds: 2000), text: true));
  // The rail book's picture comes Tall as well: the whole screen on a phone, the Wide one on a fold.
  Duration railBook() => plan.starts[1] + const Duration(milliseconds: 1500);
  testWidgets('P14a a Tall picture', (t) => shoot(t, 'P14a-listening-tall', phone, railBook()));
  testWidgets('P14b a Tall picture, Text on', (t) => shoot(t, 'P14b-listening-tall-text', phone, railBook(), text: true));
  testWidgets('P14 the same moment on a fold', (t) => shoot(t, 'P14-listening-fold-wide', fold, railBook(), text: true));
}
