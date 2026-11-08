// The upright player (P24): it plays like a video, a tap pauses, a swipe moves on.
import 'dart:async';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/parts/application/notices.dart';
import 'package:arke_player/features/players/application/audio_engine.dart';
import 'package:arke_player/features/players/application/listening_plan.dart';
import 'package:arke_player/features/players/application/music.dart';
import 'package:arke_player/features/players/application/players.dart';
import 'package:arke_player/features/players/presentation/episode_player.dart';
import 'package:arke_player/features/players/presentation/episode_rows.dart';
import 'package:arke_player/features/players/presentation/picture_of_the_moment.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_player/features/worlds/application/discover.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/production_screen.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _minute = Duration(minutes: 1);
const _ledger = 'ledger';

ListeningChapter _chapter(int number, String title) => ListeningChapter(
  id: 'ch$number',
  order: number,
  title: title,
  duration: _minute * 3,
  audio: 'ch$number.m4a',
  pictures: [ListeningPicture(at: Duration.zero, picture: 'wide$number.jpg', tall: 'tall$number.jpg')],
);

final _plan = ListeningPlan(
  document: ListeningDocument(
    title: 'The Ledger of Nights',
    cover: 'cover.jpg',
    chapters: [_chapter(1, 'The Weigh House'), _chapter(2, 'The Weir'), _chapter(3, 'The Tenth Key')],
  ),
  pathOf: (asset) => 'world/$asset',
);

final _item = LibraryItem(
  id: 'undersong.ledger.listening',
  format: FileFormat.listening,
  title: 'The Ledger of Nights',
  byteLength: 72000000,
  addedAt: DateTime.utc(2026, 10, 21),
  file: 'worlds/undersong/ledger/listening.json',
  worldId: 'undersong',
  duration: _minute * 9,
  chapters: const [
    Chapter(title: 'The Weigh House', start: Duration.zero, id: 'ch1'),
    Chapter(title: 'The Weir', start: Duration(minutes: 3), id: 'ch2'),
    Chapter(title: 'The Tenth Key', start: Duration(minutes: 6), id: 'ch3'),
  ],
);

final _world = LibraryWorld(
  id: 'undersong',
  edition: '2026-10-21',
  name: 'The Undersong',
  byteLength: 72000000,
  installedAt: DateTime.utc(2026, 10, 21),
  productions: [LibraryProduction(id: _ledger, title: 'The Ledger of Nights', narration: _item.id)],
);

final _listed = CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  productions: [
    CatalogueProduction(
      id: _ledger,
      title: 'The Ledger of Nights',
      kind: 'Audiobook · 3 chapters',
      schedule: WorldSchedule(day: ScheduleDay.friday, next: DateTime.utc(2026, 11, 13)),
    ),
  ],
  package: CataloguePackage(url: Uri.parse('https://example.org/undersong.zip'), byteLength: 72000000, sha256: 'a' * 64),
);

List<GuideSection> _says(String what) => [GuideSection(heading: 'Essence', text: what)];
GuideAfter _after(int number) => GuideAfter(production: _ledger, chapter: 'ch$number', number: number);
final _guide = Guide(
  productions: [
    GuideProduction(
      id: _ledger,
      title: 'The Ledger of Nights',
      chapters: [for (var n = 1; n <= 3; n++) GuideChapter(id: 'ch$n', number: n)],
    ),
  ],
  characters: [
    GuideCharacter(id: 'maren', name: 'Maren Kest', role: 'Tide-caller', sections: _says('Tide-caller.')),
    GuideCharacter(id: 'kemi', name: 'Kemi', role: 'A friend', after: _after(2), sections: _says('A friend.')),
    GuideCharacter(id: 'zee', name: 'Zee', role: 'From the club', after: _after(3), sections: _says('From the club.')),
  ],
  places: [GuidePlace(id: 'vigil', name: 'The Vigil', sections: _says('A wall.'))],
  lore: const [],
);

/// An engine a test moves by hand: nothing plays.
class _Engine implements AudioEngine {
  _Engine({this.at = Duration.zero});

  final _positions = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _finished = StreamController<void>.broadcast();
  Duration at;
  bool isPlaying = true;
  final seeks = <Duration>[];
  int pauses = 0;
  int plays = 0;
  int backs = 0;
  int forwards = 0;

  void moveTo(Duration position) {
    at = position;
    _positions.add(position);
  }

  void finish() => _finished.add(null);

  /// What it holds: [_item] until a test says otherwise.
  LibraryItem? held = _item;

  @override
  LibraryItem? get item => held;
  @override
  ListeningPlan get plan => _plan;
  @override
  Duration get now => at;
  @override
  Stream<Duration> get position => _positions.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<void> get finished => _finished.stream;
  @override
  bool get playing => isPlaying;
  @override
  double get speed => 1;
  @override
  SleepTimer get sleep => SleepTimer.off;
  @override
  Duration get length => _plan.document.duration;
  @override
  int chapterAt(Duration position) => _plan.locate(position).$1;
  @override
  (Duration, Duration) chapterBounds(Duration position) {
    final index = chapterAt(position);
    return (_plan.starts[index], _plan.starts[index] + _plan.chapters[index].duration);
  }

  @override
  Future<void> pause() async {
    pauses++;
    isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> play() async {
    plays++;
    isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    moveTo(position);
  }

  @override
  Future<void> rewind() async => backs++;
  @override
  Future<void> forward15() async => forwards++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsController {
  _Settings(this.fixed);
  final DeviceSettings fixed;

  @override
  Future<DeviceSettings> build() async => fixed;

  @override
  Future<void> change(DeviceSettings Function(DeviceSettings current) edit) async => state = AsyncData(edit(state.requireValue));
}

class _NoNotices implements Notices {
  @override
  Future<bool> ask() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Engine> _pump(
  WidgetTester tester, {
  Duration at = Duration.zero,
  Size size = const Size(390, 844),
  // Slow push off: its move runs for a picture's whole hold, and pumpAndSettle would wait it out.
  DeviceSettings settings = const DeviceSettings(slowPush: false),
  GuideReach reach = const GuideReach(reached: {_ledger: (at: 1, through: 1)}),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final engine = _Engine(at: at);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => EpisodePlayer(item: _item, plan: _plan, engine: engine, onSpeedAndSleep: () {}),
      ),
      GoRoute(path: '/worlds/world/:world', builder: (context, state) => Text('world ${state.pathParameters['world']}')),
      GoRoute(path: '/worlds/world/:world/_guide/:entry', builder: (context, state) => Text('entry ${state.pathParameters['entry']}')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryItemsProvider.overrideWith((ref) => Stream.value([_item])),
        libraryWorldsProvider.overrideWith((ref) => Stream.value([_world])),
        catalogueProvider.overrideWith((ref) async => [_listed]),
        worldGuideProvider.overrideWith((ref, worldId) async => WorldGuide(guide: _guide, pathOf: (asset) => 'guide/$asset')),
        guideReachProvider.overrideWith((ref, worldId) async => reach),
        settingsProvider.overrideWith(() => _Settings(settings)),
        noticesProvider.overrideWithValue(_NoNotices()),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 7)),
      ],
      child: MaterialApp.router(theme: arkeTheme(Brightness.dark), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return engine;
}

Future<void> _swipe(WidgetTester tester, double dy) async {
  await tester.fling(find.byType(PageView), Offset(0, dy), 1200);
  await tester.pumpAndSettle();
}

void main() {
  group('at rest (P24c, rule 3)', () {
    testWidgets('the episode and its title, a thin line and the rail: nothing else', (tester) async {
      await _pump(tester);
      expect(find.text('1 · The Weigh House'), findsOneWidget);
      expect(find.text('The Ledger of Nights'), findsOneWidget);
      expect(find.text('Here'), findsOneWidget);
      expect(find.text('Episodes'), findsOneWidget);
      expect(find.text('Notify'), findsOneWidget);
      expect(find.bySemanticsLabel('Forward 15 seconds'), findsNothing);
      expect(find.text('Sleep'), findsNothing);
    });

    testWidgets('the rail has no likes, comments, counts or shares (call 49)', (tester) async {
      await _pump(tester);
      for (final word in ['Like', 'Comment', 'Share', 'Coins']) {
        expect(find.text(word), findsNothing);
      }
    });
  });

  group('a tap (P24d, rule 5)', () {
    Future<void> tap(WidgetTester tester) async {
      await tester.tapAt(const Offset(195, 300));
      await tester.pumpAndSettle();
    }

    testWidgets('pauses and brings the controls; it never moves on', (tester) async {
      final engine = await _pump(tester);
      await tap(tester);
      expect(engine.pauses, 1);
      expect(engine.seeks, isEmpty);
      expect(find.bySemanticsLabel('Back 15 seconds'), findsOneWidget);
      expect(find.bySemanticsLabel('Forward 15 seconds'), findsOneWidget);
      expect(find.text('Sleep'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('1 · The Weigh House'), findsOneWidget);
    });

    testWidgets('the steps are fifteen seconds each way', (tester) async {
      final engine = await _pump(tester);
      await tap(tester);
      await tester.tap(find.bySemanticsLabel('Back 15 seconds'));
      await tester.tap(find.bySemanticsLabel('Forward 15 seconds'));
      await tester.pumpAndSettle();
      expect((engine.backs, engine.forwards), (1, 1));
    });

    testWidgets('a second tap plays, and the controls rest after 2.5 s of playing', (tester) async {
      final engine = await _pump(tester);
      await tap(tester);
      await tester.tapAt(const Offset(195, 300));
      await tester.pump();
      expect(engine.plays, 1);
      expect(find.text('Sleep'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.text('Sleep'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Sleep'), findsNothing);
    });

    testWidgets('choosing an episode with them up plays it, and they rest as usual', (tester) async {
      final engine = await _pump(tester);
      await tap(tester);
      await tester.tap(find.text('Episodes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 · The Tenth Key'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 3));
      expect(engine.seeks, [_minute * 6]);
      expect(find.text('Sleep'), findsNothing);
    });

    testWidgets('paused, they stay', (tester) async {
      await _pump(tester);
      await tap(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Sleep'), findsOneWidget);
    });
  });

  group('as it opens (cold, or holding another title)', () {
    Future<_Engine> pumpOpening(WidgetTester tester, {Duration? startAt, required LibraryItem? held, Place? place}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = _Engine()..held = held;
      final item = LibraryItem(
        id: _item.id,
        format: _item.format,
        title: _item.title,
        byteLength: _item.byteLength,
        addedAt: _item.addedAt,
        file: _item.file,
        worldId: _item.worldId,
        duration: _item.duration,
        chapters: _item.chapters,
        place: place,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => EpisodePlayer(item: item, plan: _plan, engine: engine, startAt: startAt, onSpeedAndSleep: () {}),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryItemsProvider.overrideWith((ref) => Stream.value([item])),
            libraryWorldsProvider.overrideWith((ref) => Stream.value([_world])),
            catalogueProvider.overrideWith((ref) async => [_listed]),
            worldGuideProvider.overrideWith((ref, worldId) async => WorldGuide(guide: _guide, pathOf: (asset) => 'guide/$asset')),
            guideReachProvider.overrideWith((ref, worldId) async => GuideReach.none),
            settingsProvider.overrideWith(() => _Settings(const DeviceSettings(slowPush: false, autoplayNext: false))),
            noticesProvider.overrideWithValue(_NoNotices()),
          ],
          child: MaterialApp.router(theme: arkeTheme(Brightness.dark), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return engine;
    }

    final kept = Place(locator: 'ch3', position: _minute, progress: 0.8, updatedAt: DateTime.utc(2026, 11, 1));

    testWidgets('with nothing open yet, it shows where it was left, not the first chapter', (tester) async {
      await pumpOpening(tester, held: null, place: kept);
      expect(find.text('3 · The Tenth Key'), findsOneWidget);
    });

    testWidgets('it ignores the engine until it gets there, and then follows it', (tester) async {
      final engine = await pumpOpening(tester, held: null, place: kept);
      // The engine still holds the title it had.
      engine.moveTo(_minute);
      await tester.pumpAndSettle();
      expect(find.text('3 · The Tenth Key'), findsOneWidget);
      // It has this one now, and a report from before it reached its place is no reason to run back.
      engine.held = _item;
      engine.moveTo(_minute);
      await tester.pumpAndSettle();
      expect(find.text('3 · The Tenth Key'), findsOneWidget);
      expect(engine.pauses, 0, reason: 'nor is it the player moving on by itself');
      engine.moveTo(_minute * 7);
      engine.moveTo(_minute * 3);
      await tester.pumpAndSettle();
      expect(find.text('2 · The Weir'), findsOneWidget);
    });

    testWidgets('a chapter pressed opens there, whatever the engine last reported', (tester) async {
      final engine = await pumpOpening(tester, held: _item, startAt: _minute * 6);
      expect(find.text('3 · The Tenth Key'), findsOneWidget);
      engine.moveTo(_minute);
      await tester.pumpAndSettle();
      expect(find.text('3 · The Tenth Key'), findsOneWidget);
    });

    testWidgets('a place the engine never reaches does not hold the pages for good', (tester) async {
      final engine = await pumpOpening(tester, held: _item, startAt: _minute * 6);
      for (var i = 0; i < 12; i++) {
        engine.moveTo(_minute);
      }
      await tester.pumpAndSettle();
      expect(find.text('1 · The Weigh House'), findsOneWidget);
    });
  });

  group('it moves on (P24g, rule 4)', () {
    testWidgets('the next episode comes on its own at the end, with no tap', (tester) async {
      final engine = await _pump(tester);
      engine.moveTo(_minute * 3);
      await tester.pumpAndSettle();
      expect(find.text('2 · The Weir'), findsOneWidget);
      expect(engine.pauses, 0);
    });

    testWidgets('with Autoplay next off it stops at the next one’s start', (tester) async {
      final engine = await _pump(tester, settings: const DeviceSettings(slowPush: false, autoplayNext: false));
      engine.moveTo(_minute * 3 - const Duration(milliseconds: 500));
      engine.moveTo(_minute * 3);
      await tester.pumpAndSettle();
      expect(find.text('2 · The Weir'), findsOneWidget);
      expect(engine.pauses, 1);
    });

    testWidgets('a step across a chapter’s end is not it ending: Autoplay next off pauses nothing', (tester) async {
      final engine = await _pump(tester, at: _minute * 2, settings: const DeviceSettings(slowPush: false, autoplayNext: false));
      engine.moveTo(_minute * 3 + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('2 · The Weir'), findsOneWidget);
      expect(engine.pauses, 0);
    });

    testWidgets('a swipe up moves to the next, a swipe down to the one before', (tester) async {
      final engine = await _pump(tester);
      await _swipe(tester, -600);
      expect(engine.seeks, [_minute * 3]);
      expect(engine.plays, 1);
      expect(find.text('2 · The Weir'), findsOneWidget);
      await _swipe(tester, 600);
      expect(engine.seeks, [_minute * 3, Duration.zero]);
      expect(find.text('1 · The Weigh House'), findsOneWidget);
      expect(engine.pauses, 0, reason: 'a swipe is not the player moving on by itself');
    });

    testWidgets('a swipe with Autoplay next off still plays what it asked for', (tester) async {
      final engine = await _pump(tester, settings: const DeviceSettings(slowPush: false, autoplayNext: false));
      await _swipe(tester, -600);
      expect(engine.pauses, 0);
      expect(engine.plays, 1);
    });
  });

  group('Episodes (P24f, rule 8)', () {
    testWidgets('rises over what plays, the one playing marked, each heard ticked; a press plays it', (tester) async {
      final engine = await _pump(tester, at: _minute * 4);
      await tester.tap(find.text('Episodes'));
      await tester.pumpAndSettle();
      expect(find.text('1 · The Weigh House'), findsOneWidget);
      expect(find.text('3 · The Tenth Key'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.equalizer_rounded), findsOneWidget);
      expect(find.textContaining('2:00 left'), findsOneWidget);
      await tester.tap(find.text('3 · The Tenth Key'));
      await tester.pumpAndSettle();
      expect(engine.seeks, [_minute * 6]);
      expect(engine.pauses, 0);
    });

    test('in ranges of 50, none for a title under that', () {
      expect(episodeRanges(50), isEmpty);
      expect(episodeRanges(248), [(0, 49), (50, 99), (100, 149), (150, 199), (200, 247)]);
      expect(episodeRanges(100), [(0, 49), (50, 99)]);
      expect(rangeOf(0), 0);
      expect(rangeOf(49), 0);
      expect(rangeOf(50), 1);
    });
  });

  group('the menus are glass (owner, 8 November 2026)', () {
    testWidgets('a phone’s Episodes sheet: the picture plays on behind it, blurred, under a light barrier', (tester) async {
      await _pump(tester, at: _minute * 4);
      await tester.tap(find.text('Episodes'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.byType(BackdropFilter)), findsOneWidget);
      expect(tester.widget<BottomSheet>(sheet).backgroundColor, Colors.transparent);
      expect(find.byType(PictureOfTheMoment), findsOneWidget);
      final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
      expect((barrier.color?.a ?? 0), lessThan(0.2));
    });

    testWidgets('on a Fold the panel floats over the picture, not beside it', (tester) async {
      await _pump(tester, size: const Size(984, 1092), at: _minute * 4);
      await tester.tap(find.text('Here'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PageView)).width, 984, reason: 'the picture runs under the panel');
      expect(find.byType(BackdropFilter), findsWidgets);
      final panel = tester.getRect(find.ancestor(of: find.text('Maren Kest'), matching: find.byType(Positioned)).first);
      expect(panel.right, lessThan(984));
      expect(panel.top, greaterThan(0));
    });
  });

  group('Here (P24e, rule 7)', () {
    testWidgets('who the chapter has reached, with their roles, and nobody still waiting', (tester) async {
      await _pump(tester, at: _minute * 4);
      await tester.tap(find.text('Here'));
      await tester.pumpAndSettle();
      expect(find.text('Maren Kest'), findsOneWidget);
      expect(find.text('Tide-caller'), findsOneWidget);
      expect(find.text('Kemi'), findsWidgets, reason: 'the chapter playing has reached her, so her card is up too');
      expect(find.text('Zee'), findsNothing, reason: 'still waiting');
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('a row opens the entry while the episode plays on', (tester) async {
      final engine = await _pump(tester, at: _minute * 4);
      await tester.tap(find.text('Here'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maren Kest'));
      await tester.pumpAndSettle();
      expect(find.text('entry maren'), findsOneWidget);
      expect(engine.pauses, 0);
    });

    testWidgets('its foot opens the world', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Here'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'The Undersong'));
      await tester.pumpAndSettle();
      expect(find.text('world undersong'), findsOneWidget);
    });
  });

  group('Caught up (P24h, rule 9)', () {
    testWidgets('after the last episode: the next date, Notify and what is in this world', (tester) async {
      final engine = await _pump(tester, at: _minute * 8);
      engine.finish();
      await tester.pumpAndSettle();
      expect(find.text('Caught up'), findsOneWidget);
      expect(find.text('Episode 4 · 13 Nov'), findsOneWidget);
      expect(find.text('Notify'), findsOneWidget);
      expect(find.text('In this world'), findsOneWidget);
      expect(find.text('Maren Kest'), findsOneWidget);
      expect(find.text('The Vigil'), findsOneWidget);
      expect(find.text('Zee'), findsNothing);
      expect(find.text('Here'), findsNothing, reason: 'its rail rests here');
    });

    testWidgets('a swipe past the last reaches it, and stops what plays', (tester) async {
      final engine = await _pump(tester, at: _minute * 7);
      await _swipe(tester, -600);
      expect(find.text('Caught up'), findsOneWidget);
      expect(engine.pauses, 1);
    });

    for (final size in const [Size(390, 844), Size(390, 620), Size(1280, 800)]) {
      testWidgets('a swipe down leaves it for the last episode, at ${size.width.toInt()} × ${size.height.toInt()}', (tester) async {
        final engine = await _pump(tester, at: _minute * 8, size: size);
        engine.finish();
        await tester.pumpAndSettle();
        expect(find.text('Caught up'), findsOneWidget);
        await tester.fling(find.byType(PageView), const Offset(0, 500), 1200);
        await tester.pumpAndSettle();
        expect(find.text('Caught up'), findsNothing);
        expect(engine.seeks, [_minute * 6]);
      });
    }

    testWidgets('someone from it opens their entry', (tester) async {
      final engine = await _pump(tester, at: _minute * 8);
      engine.finish();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maren Kest'));
      await tester.pumpAndSettle();
      expect(find.text('entry maren'), findsOneWidget);
    });
  });

  group('turned, and a Fold (P24i, P24j, rule 10)', () {
    testWidgets('turned, the rail stays at the right', (tester) async {
      await _pump(tester, size: const Size(844, 390));
      expect(find.text('Here'), findsOneWidget);
      expect(tester.getCenter(find.text('Here')).dx, greaterThan(760));
    });

    // The owner, 8 November 2026: always open on a Fold, the panel hid the picture and would not close.
    testWidgets('a Fold open shows the whole picture, with Here and Episodes on its rail (P24j)', (tester) async {
      await _pump(tester, size: const Size(984, 1092), at: _minute * 4);
      expect(find.text('Maren Kest'), findsNothing);
      expect(tester.getCenter(find.text('Here')).dx, greaterThan(984 - 70));
      expect(tester.getSize(find.byType(PageView)).width, 984);
    });

    testWidgets('on a Fold, Here opens beside the picture, not over it, and it plays on', (tester) async {
      final engine = await _pump(tester, size: const Size(984, 1092), at: _minute * 4);
      await tester.tap(find.text('Here'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.getTopLeft(find.text('Maren Kest')).dx, greaterThan(984 - 320));
      await tester.tap(find.text('Episodes'));
      await tester.pumpAndSettle();
      expect(find.text('3 · The Tenth Key'), findsOneWidget);
      expect(find.byTooltip('Notify'), findsOneWidget);
      expect(engine.pauses, 0);
    });

    for (final size in const [Size(984, 1092), Size(1280, 800)]) {
      testWidgets('its head closes it, back to the whole picture, at ${size.width.toInt()} wide', (tester) async {
        final engine = await _pump(tester, size: size, at: _minute * 4);
        await tester.tap(find.text('Episodes'));
        await tester.pumpAndSettle();
        expect(find.text('3 · The Tenth Key'), findsOneWidget);
        await tester.tap(find.byTooltip('Hide'));
        await tester.pumpAndSettle();
        expect(find.text('3 · The Tenth Key'), findsNothing);
        expect(tester.getSize(find.byType(PageView)).width, size.width);
        expect(find.text('Here'), findsOneWidget);
        expect(engine.pauses, 0);
      });
    }

    testWidgets('on a Fold, a tap on the picture closes it too, and pauses nothing', (tester) async {
      final engine = await _pump(tester, size: const Size(984, 1092), at: _minute * 4);
      await tester.tap(find.text('Here'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(300, 400));
      await tester.pumpAndSettle();
      expect(find.text('Maren Kest'), findsNothing);
      expect(engine.pauses, 0);
    });
  });

  group('the Story tab (P24a, rule 2)', () {
    Future<void> pumpTab(WidgetTester tester, {ListeningPlan? plan}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final item = LibraryItem(
        id: _item.id,
        format: _item.format,
        title: _item.title,
        byteLength: _item.byteLength,
        addedAt: _item.addedAt,
        file: _item.file,
        worldId: _item.worldId,
        duration: _item.duration,
        chapters: _item.chapters,
        place: Place(locator: 'ch2', position: _minute, progress: 0.4, updatedAt: DateTime.utc(2026, 11, 1)),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: ProductionContents(world: _world, production: _world.productions.single, worldLocation: '/'),
              ),
            ),
          ),
          GoRoute(path: '/open/:item', builder: (context, state) => Text('opened ${state.uri.query}')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryItemsProvider.overrideWith((ref) => Stream.value([item])),
            libraryWorldsProvider.overrideWith((ref) => Stream.value([_world])),
            catalogueProvider.overrideWith((ref) async => const []),
            worldGuideProvider.overrideWith((ref, worldId) async => null),
            worldMusicProvider.overrideWith((ref, worldId) async => const []),
            audioEngineProvider.overrideWithValue(null),
            clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 7)),
            listeningPlanProvider.overrideWith((ref, itemId) async => plan),
          ],
          child: MaterialApp.router(theme: arkeTheme(Brightness.dark), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('episodes: an upright picture, its number and title, a tick on one heard, Resume on the one you are in', (tester) async {
      await pumpTab(tester, plan: _plan);
      expect(find.text('Episodes'), findsOneWidget);
      expect(find.text('1 · The Weigh House'), findsOneWidget);
      expect(find.text('2 · The Weir'), findsOneWidget);
      expect(find.byType(EpisodeThumb), findsNWidgets(3));
      expect(tester.getSize(find.byType(EpisodeThumb).first), const Size(44, 66));
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('Resume picks up the place, and any other row its start', (tester) async {
      await pumpTab(tester, plan: _plan);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.text('opened '), findsOneWidget);
    });

    testWidgets('a narration whose document cannot be read keeps its chapters', (tester) async {
      await pumpTab(tester);
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('The Weir'), findsOneWidget);
      expect(find.byType(EpisodeThumb), findsNothing);
    });
  });

  group('a tablet, playing (P27)', () {
    const sideways = Size(1280, 800);

    testWidgets('sideways, Wide covers the screen, and the rail stays at the right (P27c)', (tester) async {
      await _pump(tester, size: sideways);
      expect(tester.widget<PictureOfTheMoment>(find.byType(PictureOfTheMoment)).fill, isTrue);
      expect(tester.widget<PictureOfTheMoment>(find.byType(PictureOfTheMoment)).shown!.path, 'world/wide1.jpg');
      expect(tester.getCenter(find.text('Here')).dx, greaterThan(1180));
    });

    testWidgets('upright, it takes the Tall (P27o, call 53)', (tester) async {
      await _pump(tester, size: const Size(800, 1280));
      expect(tester.widget<PictureOfTheMoment>(find.byType(PictureOfTheMoment)).shown!.path, 'world/tall1.jpg');
    });

    testWidgets('Here and Episodes open beside the picture, not over it, and it plays on (P27f, P27g)', (tester) async {
      final engine = await _pump(tester, size: sideways, at: _minute * 4);
      await tester.tap(find.text('Here'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.getTopLeft(find.text('Maren Kest')).dx, greaterThan(1280 - 380));
      expect(find.text('2 · The Weir'), findsOneWidget);
      expect(engine.pauses, 0);
      await tester.tap(find.text('Episodes'));
      await tester.pumpAndSettle();
      expect(find.text('3 · The Tenth Key'), findsOneWidget);
    });

    testWidgets('a tap on the picture closes the panel, and pauses nothing', (tester) async {
      final engine = await _pump(tester, size: sideways, at: _minute * 4);
      await tester.tap(find.text('Here'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(find.text('Maren Kest'), findsNothing);
      expect(engine.pauses, 0);
    });

    testWidgets('someone new comes at the top left, 400 wide (P27d)', (tester) async {
      final engine = await _pump(tester, size: sideways);
      engine.moveTo(_minute * 3);
      await tester.pumpAndSettle();
      final card = find.ancestor(of: find.text('Kemi'), matching: find.byType(Positioned)).first;
      expect(tester.getSize(card).width, 400);
      expect(tester.getTopLeft(card).dx, 40);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('Caught up: the cover at the left, the world at the right (P27h)', (tester) async {
      final engine = await _pump(tester, size: sideways, at: _minute * 8);
      engine.finish();
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Caught up')).dx, lessThan(480));
      expect(tester.getTopLeft(find.text('In this world')).dx, greaterThanOrEqualTo(480));
    });

    testWidgets('turning it changes the layout and nothing else: it keeps its place (rule 7)', (tester) async {
      final engine = await _pump(tester, at: _minute * 4);
      tester.view.physicalSize = sideways;
      await tester.pumpAndSettle();
      expect(find.text('2 · The Weir'), findsOneWidget);
      expect(engine.seeks, isEmpty);
      expect(engine.pauses, 0);
    });
  });

  testWidgets('someone new comes over it while it plays (P23e)', (tester) async {
    final engine = await _pump(tester);
    engine.moveTo(_minute * 3);
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Kemi'), findsOneWidget);
    expect(engine.pauses, 0);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
