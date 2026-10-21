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
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _shoot = Platform.environment['SHOOT'] == '1';
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
    required double speed,
    required void Function(Place place, {bool? finished}) keep,
  }) async {}

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
    // 3 s; then the rail book on the wide one again.
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
                  {'at': 0, 'picture': '$_design/drowned-quarter.jpg'},
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

  Future<void> shoot(WidgetTester tester, String name, Size size, Duration at, {bool text = false}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 47 * 2, bottom: 34 * 2);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      for (final path in {
        for (final chapter in plan.chapters) ...[for (final picture in chapter.pictures) plan.pathOf(picture.picture)],
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
  testWidgets('P5a the picture of the moment', (t) => shoot(t, 'P5a-listening', phone, const Duration(milliseconds: 2000)));
  testWidgets('P5a with Text', (t) => shoot(t, 'P5a-listening-text', phone, const Duration(milliseconds: 1500), text: true));
  testWidgets('P5a a tall picture', (t) => shoot(t, 'P5a-listening-tall', phone, const Duration(milliseconds: 4000)));
  testWidgets('P5a the opening', (t) => shoot(t, 'P5a-listening-opening', phone, const Duration(milliseconds: 400)));
  testWidgets('P6f on a fold', (t) => shoot(t, 'P6f-listening-fold', fold, const Duration(milliseconds: 2000), text: true));
}
