// A Tall picture fills the phone (Player P14, SPEC-058 R-37 – R-40): over an installed world whose
// first picture comes Wide and Tall, the audiobook player shows the Tall one over the whole screen on
// a phone in portrait, and the Wide one as P5a everywhere else.
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/players/application/audio_engine.dart';
import 'package:arke_player/features/players/application/listening_plan.dart';
import 'package:arke_player/features/players/application/players.dart';
import 'package:arke_player/features/players/presentation/picture_of_the_moment.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsController {
  _Settings(this.fixed);

  final DeviceSettings fixed;

  @override
  Future<DeviceSettings> build() async => fixed;
}

void main() {
  late Directory root;
  late LibraryStore store;
  late LibraryItem item;
  late ListeningPlan plan;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('arke-player-tall-');
    final source = Directory('${root.path}/source')..createSync();
    File('$_media/chapters.m4b').copySync('${source.path}/ch1.m4a');
    // One chapter: a picture at 1 s made Wide and Tall, then one at 3 s made Wide alone.
    final spec = WorldSpec(
      id: 'undersong',
      edition: '2026-10-23',
      name: 'The Undersong',
      keyArt: '$_design/world-undersong.jpg',
      productions: [
        ProductionSpec(
          id: 'ledger-of-nights',
          title: 'The Ledger of Nights',
          listening: {
            'title': 'The Ledger of Nights',
            'cover': '$_design/world-undersong.jpg',
            'chapters': [
              {
                'id': 'neap',
                'title': 'Neap',
                'audio': '${source.path}/ch1.m4a',
                'pictures': [
                  {
                    'at': 1000,
                    'picture': '$_design/drowned-quarter.jpg',
                    'tall': '$_design/char-maren.jpg',
                    'focus': {'x': 0.62, 'y': 0.4},
                  },
                  {'at': 3000, 'picture': '$_design/world-undersong.jpg'},
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

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester, Size size, Duration at, {bool text = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith((ref) => Stream.value(store.items)),
          libraryStoreProvider.overrideWith((ref) async => store),
          audioEngineProvider.overrideWithValue(_StillEngine(item, plan, at)),
          settingsProvider.overrideWith(() => _Settings(DeviceSettings(text: text))),
        ],
        child: MaterialApp.router(
          theme: arkeTheme(Brightness.dark),
          routerConfig: buildRouter(initialLocation: Routes.open(item.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PictureOfTheMoment picture(WidgetTester tester) => tester.widget<PictureOfTheMoment>(find.byType(PictureOfTheMoment));

  const phone = Size(390, 844);
  const withTall = Duration(milliseconds: 2000);
  const wideAlone = Duration(milliseconds: 4000);

  test('the package names the Tall picture beside the Wide one (R-37)', () {
    final shown = plan.shownAt(withTall)!;
    expect(shown.tallPath, isNotNull);
    expect(shown.tallPath, isNot(shown.path));
    expect(plan.shownAt(wideAlone)!.tallPath, isNull);
  });

  testWidgets('a phone in portrait shows the Tall picture over the whole screen (P14a)', (tester) async {
    await open(tester, phone, withTall);
    final shown = picture(tester);
    expect(shown.fill, isTrue);
    expect(shown.shown!.path, plan.shownAt(withTall)!.tallPath);
    expect(tester.getSize(find.byType(PictureOfTheMoment)).height, phone.height);
  });

  testWidgets('with Text on, the Tall picture still fills the screen (P14b)', (tester) async {
    await open(tester, phone, withTall, text: true);
    expect(picture(tester).fill, isTrue);
    expect(tester.getSize(find.byType(PictureOfTheMoment)).height, phone.height);
  });

  testWidgets('a moment without a Tall picture keeps P5a: the Wide one, letterboxed in the top 62%', (tester) async {
    await open(tester, phone, wideAlone);
    final shown = picture(tester);
    expect(shown.fill, isFalse);
    expect(shown.shown!.path, plan.shownAt(wideAlone)!.path);
    expect(tester.getSize(find.byType(PictureOfTheMoment)).height, closeTo(phone.height * 0.62, 0.01));
  });

  testWidgets('a tablet shows the Wide picture (R-39)', (tester) async {
    await open(tester, const Size(820, 1180), withTall);
    final shown = picture(tester);
    expect(shown.fill, isFalse);
    expect(shown.shown!.path, plan.shownAt(withTall)!.path);
  });

  testWidgets('a phone turned shows the Wide picture, at the same place in the hold (P14 rule 4)', (tester) async {
    await open(tester, phone, withTall);
    final upright = picture(tester).shown!;
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    final turned = picture(tester);
    expect(turned.fill, isFalse);
    expect(turned.shown!.path, plan.shownAt(withTall)!.path);
    expect((turned.shown!.start, turned.shown!.end), (upright.start, upright.end));
  });
}
