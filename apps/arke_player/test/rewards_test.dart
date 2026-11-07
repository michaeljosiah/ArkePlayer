// A world's rewards (P23): the teaser feed, what you have found, and someone new.
import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/downloads/presentation/downloads_screen.dart';
import 'package:arke_player/features/parts/application/notices.dart';
import 'package:arke_player/features/players/presentation/open_item_screen.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_player/features/worlds/application/discover.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/teaser_feed.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/guide_screens.dart';
import 'package:arke_player/features/worlds/presentation/guide_widgets.dart';
import 'package:arke_player/features/worlds/presentation/someone_new.dart';
import 'package:arke_player/features/worlds/presentation/teaser_screen.dart';
import 'package:arke_player/features/worlds/presentation/world_screen.dart';
import 'package:arke_player/features/worlds/presentation/world_shelf.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _ledger = 'ledger';
GuideAfter _after(int number) => GuideAfter(production: _ledger, chapter: 'ch$number', number: number);
List<GuideSection> _says(String what) => [GuideSection(heading: 'Essence', text: what)];

final _maren = GuideCharacter(
  id: 'maren',
  name: 'Maren Kest',
  role: 'Tide-caller',
  portrait: 'maren.jpg',
  sections: _says('Tide-caller.'),
  voice: const GuideVoice(audio: 'maren.m4a', text: 'The tide is low.', duration: Duration(seconds: 8), production: _ledger, chapter: 'ch1'),
);
final _bray = GuideCharacter(id: 'bray', name: 'Bray', role: 'Rigger', portrait: 'bray.jpg', sections: _says('Rigger.'));
final _kemi = GuideCharacter(id: 'kemi', name: 'Kemi', role: 'A friend', portrait: 'kemi.jpg', after: _after(2), sections: _says('A friend.'));
final _zee = GuideCharacter(id: 'zee', name: 'Zee', role: 'From the club', portrait: 'zee.jpg', after: _after(5), sections: _says('From the club.'));
final _vigil = GuidePlace(id: 'vigil', name: 'The Vigil', picture: 'vigil.jpg', sections: _says('A wall.'));
final _vault = GuidePlace(id: 'vault', name: 'The Vault', picture: 'vault.jpg', after: _after(2), sections: _says('Below.'));
final _clip = ClipTeaser(title: 'Saltmouth bells', picture: 'bells.jpg', from: _after(1), audio: 'bells.m4a', duration: const Duration(seconds: 24));

final _guide = Guide(
  productions: [
    GuideProduction(
      id: _ledger,
      title: 'The Ledger of Nights',
      chapters: [for (var n = 1; n <= 6; n++) GuideChapter(id: 'ch$n', number: n)],
    ),
  ],
  characters: [_maren, _bray, _kemi, _zee],
  places: [_vigil, _vault],
  lore: const [],
  teasers: [_clip, EntryTeaser(_bray)],
);

final _quiet = Guide(productions: const [], characters: [_maren], places: const [], lore: const [], teasers: const []);

CatalogueWorld _listed({String id = 'undersong', String name = 'The Undersong', String? age = '16+'}) => CatalogueWorld(
  id: id,
  name: name,
  genres: const ['Fantasy'],
  age: age,
  productions: const [CatalogueProduction(id: _ledger, title: 'The Ledger of Nights', kind: 'Audiobook · Book · 6 chapters')],
  package: CataloguePackage(url: Uri.parse('https://example.org/$id.zip'), byteLength: 72000000, sha256: 'a' * 64),
);

final _here = LibraryWorld(
  id: 'undersong',
  edition: '2026-10-21',
  name: 'The Undersong',
  byteLength: 72000000,
  installedAt: DateTime.utc(2026, 10, 21),
  productions: const [LibraryProduction(id: _ledger, title: 'The Ledger of Nights', narration: 'undersong.ledger.listening')],
);

final _narration = LibraryItem(
  id: 'undersong.ledger.listening',
  format: FileFormat.listening,
  title: 'The Ledger of Nights',
  byteLength: 72000000,
  addedAt: DateTime.utc(2026, 10, 21),
  file: 'worlds/undersong/ledger/listening.json',
  worldId: 'undersong',
);

ListeningChapter _chapter(int number) =>
    ListeningChapter(id: 'ch$number', order: number, title: 'Chapter $number', duration: const Duration(minutes: 3), audio: 'ch$number.m4a');

class _Audio implements TeaserAudio {
  final played = <String>[];
  var stopped = 0;

  @override
  Future<void> play(String path) async => played.add(path);

  @override
  Future<void> stop() async => stopped++;

  @override
  Stream<Duration> get position => const Stream.empty();
}

class _Settings extends SettingsController {
  _Settings(this.start);
  final DeviceSettings start;

  @override
  Future<DeviceSettings> build() async => start;

  @override
  Future<void> change(DeviceSettings Function(DeviceSettings current) update) async {
    state = AsyncData(update(state.requireValue));
  }
}

class _NoNotices implements Notices {
  @override
  Future<bool> ask() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _overrides({
  required _Audio audio,
  required List<CatalogueWorld> catalogue,
  required List<LibraryWorld> worlds,
  required GuideReach reach,
  required DeviceSettings settings,
  Guide? guide,
}) => [
  libraryItemsProvider.overrideWith((ref) => Stream.value(worlds.isEmpty ? const <LibraryItem>[] : [_narration])),
  libraryWorldsProvider.overrideWith((ref) => Stream.value(worlds)),
  volumeProvider.overrideWith((ref) async => (free: 40000000000, total: 128000000000)),
  catalogueProvider.overrideWith((ref) async => catalogue),
  catalogueRefreshProvider.overrideWith((ref) async {}),
  listPicksProvider.overrideWith((ref) async => (feature: null, band: null)),
  worldGuideProvider.overrideWith((ref, worldId) async => WorldGuide(guide: guide ?? _guide, pathOf: (asset) => 'guide/$asset')),
  guideFetchProvider.overrideWith((ref, worldId) async {}),
  guideReachProvider.overrideWith((ref, worldId) async => reach),
  teaserAudioProvider.overrideWithValue(audio),
  noticesProvider.overrideWithValue(_NoNotices()),
  onlineProvider.overrideWith((ref) => Stream.value(true)),
  settingsProvider.overrideWith(() => _Settings(settings)),
];

Future<_Audio> _pump(
  WidgetTester tester, {
  String? location,
  List<CatalogueWorld>? catalogue,
  List<LibraryWorld>? worlds,
  GuideReach reach = GuideReach.none,
  DeviceSettings settings = const DeviceSettings(),
  Guide? guide,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final audio = _Audio();
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(audio: audio, catalogue: catalogue ?? [_listed()], worlds: worlds ?? const [], reach: reach, settings: settings, guide: guide),
      child: MaterialApp.router(
        theme: arkeTheme(Brightness.dark),
        routerConfig: buildRouter(initialLocation: location ?? Routes.home),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return audio;
}

/// Opens the feed at the top of the phone, over Home.
Future<void> _openFeed(WidgetTester tester, List<FeedPage> pages, {int start = 0}) async {
  unawaited(openFeed(tester.element(find.byType(Scaffold).first), pages, start));
  await tester.pumpAndSettle();
}

List<FeedPage> _feedOf(List<Guide> guides) => teaserFeed([
  for (final (i, guide) in guides.indexed)
    (
      world: _listed(id: 'w$i', name: 'World $i'),
      worldId: 'w$i',
      worldPage: Routes.world('w$i'),
      guide: WorldGuide(guide: guide, pathOf: (asset) => 'guide/$asset'),
    ),
]);

Future<void> _swipeUp(WidgetTester tester) async {
  await tester.fling(find.byType(PageView), const Offset(0, -500), 1000);
  await tester.pumpAndSettle();
}

void main() {
  group('the feed’s pages (P23 rule 1, call 46)', () {
    String name(GuideTeaser teaser) => switch (teaser) {
      EntryTeaser(:final entry) => entryName(entry),
      PictureTeaser(:final title) => title,
      SongTeaser(:final title) => title,
    };

    test('a world’s chosen teasers first, then its open characters and places, no entry twice', () {
      expect(
        [
          for (final page in _feedOf([_guide])) name(page.teaser),
        ],
        ['Saltmouth bells', 'Bray', 'Maren Kest', 'The Vigil'],
      );
    });

    test('an entry that waits for a chapter never shows, even chosen', () {
      final chosen = Guide(productions: _guide.productions, characters: _guide.characters, places: const [], lore: const [], teasers: [EntryTeaser(_kemi)]);
      expect(
        [
          for (final page in _feedOf([chosen])) name(page.teaser),
        ],
        ['Maren Kest', 'Bray'],
      );
    });

    test('someone with no picture has nothing to fill the phone with', () {
      final bare = Guide(
        productions: const [],
        characters: [GuideCharacter(id: 'x', name: 'No Face', sections: _says('.'))],
        places: const [],
        lore: const [],
        teasers: const [],
      );
      expect(_feedOf([bare]), isEmpty);
    });

    test('it runs across every world, each page knowing its own', () {
      final pages = _feedOf([_quiet, _quiet]);
      expect([for (final page in pages) page.worldId], ['w0', 'w1']);
    });
  });

  group('the feed (P23a – P23d)', () {
    testWidgets('a swipe up moves to the next, with its own sound; down goes back', (tester) async {
      final audio = await _pump(tester);
      await _openFeed(tester, _feedOf([_guide]));
      expect(find.text('Clip · 0:24'), findsOneWidget);
      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Sound'), findsOneWidget);
      expect(audio.played, ['guide/bells.m4a']);

      await _swipeUp(tester);
      expect(find.text('Bray'), findsOneWidget);
      expect(find.text('Character'), findsOneWidget);
      expect(find.text('Voice'), findsNothing, reason: 'he has no line');
      expect(audio.played, ['guide/bells.m4a']);
      expect(audio.stopped, 1);

      await _swipeUp(tester);
      expect(find.text('Maren Kest'), findsOneWidget);
      expect(find.text('“The tide is low.”'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);
      expect(audio.played, ['guide/bells.m4a', 'guide/maren.m4a']);

      await tester.fling(find.byType(PageView), const Offset(0, 500), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Bray'), findsOneWidget);
    });

    testWidgets('pressed off, its sound stays off from page to page', (tester) async {
      final audio = await _pump(tester);
      await _openFeed(tester, _feedOf([_guide]));
      await tester.tap(find.text('Sound'));
      await tester.pumpAndSettle();
      expect(audio.stopped, 1);
      await _swipeUp(tester);
      await _swipeUp(tester);
      expect(find.text('Maren Kest'), findsOneWidget);
      expect(audio.played, ['guide/bells.m4a'], reason: 'nothing since it was pressed off');
    });

    testWidgets('a place has no sound to press', (tester) async {
      await _pump(tester);
      await _openFeed(tester, _feedOf([_guide]), start: 3);
      expect(find.text('The Vigil'), findsOneWidget);
      expect(find.text('Place'), findsOneWidget);
      expect(find.text('Sound'), findsNothing);
      expect(find.text('Voice'), findsNothing);
      expect(find.text('Notify'), findsOneWidget);
      expect(find.text('World'), findsOneWidget);
    });

    testWidgets('World leaves it for the world’s page; so does the world’s name', (tester) async {
      await _pump(tester);
      final pages = teaserFeed([
        (world: _listed(), worldId: 'undersong', worldPage: Routes.world('undersong'), guide: WorldGuide(guide: _guide, pathOf: (asset) => asset)),
      ]);
      await _openFeed(tester, pages);
      await tester.tap(find.text('World'));
      await tester.pumpAndSettle();
      expect(find.byType(TeaserFeedScreen), findsNothing);
      expect(find.byType(WorldScreen), findsOneWidget);
    });

    testWidgets('its foot is the world’s own press: an 18+ world’s page shows, and only Start asks (rule 2, rule 3)', (tester) async {
      await _pump(tester, catalogue: [_listed(age: '18+')]);
      final pages = teaserFeed([
        (world: _listed(age: '18+'), worldId: 'undersong', worldPage: Routes.world('undersong'), guide: WorldGuide(guide: _guide, pathOf: (asset) => asset)),
      ]);
      await _openFeed(tester, pages);
      expect(find.text('I am 18 or older · Start'), findsNothing);
      expect(find.text('18+'), findsWidgets);
      expect(find.text('Fantasy'), findsWidgets);
      await tester.tap(find.textContaining('Start', findRichText: true).last);
      await tester.pumpAndSettle();
      expect(find.text('I am 18 or older · Start'), findsOneWidget);
    });

    testWidgets('Play leaves the feed, its sound with it, for the title (P22 rule 3)', (tester) async {
      final audio = await _pump(tester, worlds: [_here]);
      final pages = teaserFeed([
        (world: _listed(), worldId: 'undersong', worldPage: Routes.world('undersong'), guide: WorldGuide(guide: _guide, pathOf: (asset) => asset)),
      ]);
      await _openFeed(tester, pages);
      await tester.tap(find.text('Play').last);
      await tester.pumpAndSettle();
      expect(find.byType(TeaserFeedScreen), findsNothing);
      expect(audio.stopped, greaterThan(0));
      expect(find.byType(OpenItemScreen), findsOneWidget);
    });

    testWidgets('a Fold keeps it upright, centred (P23d)', (tester) async {
      tester.view.physicalSize = const Size(984, 1092);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(audio: _Audio(), catalogue: [_listed()], worlds: const [], reach: GuideReach.none, settings: const DeviceSettings()),
          child: MaterialApp.router(theme: arkeTheme(Brightness.dark), routerConfig: buildRouter()),
        ),
      );
      await tester.pumpAndSettle();
      await _openFeed(tester, _feedOf([_guide]));
      final strip = tester.getRect(find.text('World 0'));
      expect(strip.left, greaterThan((984 - 1092 * 0.695) / 2));
      expect(strip.left, lessThan(984 / 2));
    });
  });

  group('an older edition on the phone', () {
    final replacing = CatalogueWorld(
      id: 'the-undersong',
      name: 'The Undersong',
      replaces: const ['undersong'],
      productions: const [CatalogueProduction(id: _ledger, title: 'The Ledger of Nights', kind: 'Audiobook · Book · 6 chapters')],
      package: CataloguePackage(url: Uri.parse('https://example.org/undersong.zip'), byteLength: 72000000, sha256: 'a' * 64),
    );

    testWidgets('Home’s cover knows it is here, and offers Play rather than a download', (tester) async {
      await _pump(tester, catalogue: [replacing], worlds: [_here]);
      expect(find.text('Play'), findsOneWidget);
      expect(find.textContaining('Start', findRichText: true), findsNothing);
    });
  });

  group('a press’s title (P22 rule 3)', () {
    LibraryItem book(String id, {Place? place, bool finished = false}) =>
        LibraryItem(id: id, format: FileFormat.epub, title: id, byteLength: 1, addedAt: DateTime.utc(2026), file: '$id.epub', place: place, finished: finished);

    test('a book in parts: the part in hand, and it says Continue', () {
      final world = LibraryWorld(
        id: 'w',
        edition: '2026-10-21',
        name: 'W',
        byteLength: 1,
        installedAt: DateTime.utc(2026),
        productions: const [
          LibraryProduction(id: 'p', title: 'P', book: 'one', bookParts: ['two']),
        ],
      );
      final items = {
        'one': book('one', finished: true),
        'two': book(
          'two',
          place: Place(locator: 'epubcfi(/6/4)', progress: 0.5, updatedAt: DateTime.utc(2026)),
        ),
      };
      final start = worldStart(world, null, items)!;
      expect(start.first?.id, 'two');
      expect(start.begun, isTrue);
      expect(start.read, isTrue);
    });
  });

  group('every way to a song asks (P22 rule 9)', () {
    Future<List<int>> pumpSong(WidgetTester tester, CatalogueWorld world, DeviceSettings settings) async {
      final played = <int>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(audio: _Audio(), catalogue: [world], worlds: const [], reach: GuideReach.none, settings: settings),
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(catalogueProvider);
                ref.watch(settingsProvider);
                return Scaffold(
                  body: TextButton(onPressed: () => playSong(context, ref, world.id, () => played.add(1)), child: const Text('A song')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return played;
    }

    testWidgets('on an 18+ world it asks, and Not now plays nothing', (tester) async {
      final played = await pumpSong(tester, _listed(age: '18+'), const DeviceSettings());
      await tester.tap(find.text('A song'));
      await tester.pumpAndSettle();
      expect(find.text('I am 18 or older · Play'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(played, isEmpty);
    });

    testWidgets('anywhere else it just plays', (tester) async {
      final played = await pumpSong(tester, _listed(), const DeviceSettings());
      await tester.tap(find.text('A song'));
      await tester.pumpAndSettle();
      expect(played, [1]);
    });
  });

  group('Library’s section (P22 rule 15)', () {
    testWidgets('You’s On this phone opens Downloads, every time', (tester) async {
      await _pump(tester, location: Routes.you);
      await tester.tap(find.text('On this phone'));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadsPane), findsOneWidget);
      await tester.tap(find.text('Worlds').first);
      await tester.pumpAndSettle();
      expect(find.byType(DownloadsPane), findsNothing);
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('On this phone'));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadsPane), findsOneWidget);
    });
  });

  group('what you have found (P23f, P23g, call 47)', () {
    const reached = GuideReach(reached: {_ledger: (at: 2, through: 2)});

    testWidgets('a world here counts it all, and People its own', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), worlds: [_here], reach: reached);
      // Maren, Bray, Kemi; the Vigil, the Vault.
      expect(find.text('5 of 6 found'), findsOneWidget);
      expect(find.text('3 of 4'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
    });

    testWidgets('before it is here there is no count, only how many', (tester) async {
      await _pump(tester, location: Routes.world('undersong'));
      expect(find.textContaining('found'), findsNothing);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('with nothing that waits there is nothing to find', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), worlds: [_here], guide: _quiet);
      expect(find.textContaining('found'), findsNothing);
    });

    testWidgets('People: its count, what is new first and marked, what waits last', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), worlds: [_here], reach: reached);
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 4 found'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      final kemi = tester.getTopLeft(find.text('Kemi'));
      final maren = tester.getTopLeft(find.text('Maren Kest'));
      expect(kemi.dx, lessThan(maren.dx));
      expect(find.text('Zee'), findsNothing, reason: 'still to come');
    });

    testWidgets('New goes once it is opened, and only then', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), worlds: [_here], reach: reached);
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maren Kest'));
      await tester.pumpAndSettle();
      expect(find.byType(GuideEntryScreen), findsOneWidget);
      GoRouter.of(tester.element(find.byType(GuideEntryScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('New'), findsOneWidget, reason: 'Maren was open from the start, and Kemi is not opened yet');

      await tester.tap(find.text('Kemi'));
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(GuideEntryScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('New'), findsNothing);
    });

    testWidgets('what you opened is kept on the device', (tester) async {
      const settings = DeviceSettings(opened: {'undersong/kemi'});
      final kept = DeviceSettings.fromPrefs(settings.toPrefs().cast<String, Object?>().remove);
      expect(kept.opened, {'undersong/kemi'});
    });

    testWidgets('Home adds what is new in your worlds', (tester) async {
      await _pump(tester, worlds: [_here], reach: reached);
      expect(find.text('New in your worlds'), findsOneWidget);
      expect(find.text('Kemi'), findsOneWidget);
      expect(find.text('The Vault'), findsOneWidget);
    });

    testWidgets('with nothing new, Home has no such row', (tester) async {
      await _pump(tester, worlds: [_here], reach: GuideReach.none);
      expect(find.text('New in your worlds'), findsNothing);
    });
  });

  group('someone new (P23e, rule 5)', () {
    late ValueNotifier<int> playing;

    Future<void> pump(WidgetTester tester, {required GuideReach reach}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      playing = ValueNotifier(1);
      addTearDown(playing.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: playing,
                builder: (context, number, _) => Stack(
                  fit: StackFit.expand,
                  children: [SomeoneNew(item: _narration, chapter: _chapter(number))],
                ),
              ),
            ),
          ),
          GoRoute(path: '/worlds/world/:world/_guide/:entry', builder: (context, state) => Text('entry ${state.pathParameters['entry']}')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(audio: _Audio(), catalogue: [_listed()], worlds: [_here], reach: reach, settings: const DeviceSettings()),
          child: MaterialApp.router(theme: arkeTheme(Brightness.dark), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    const atOne = GuideReach(reached: {_ledger: (at: 1, through: 1)});

    testWidgets('the chapter that brings one out of waiting brings its card, which leaves after five seconds', (tester) async {
      await pump(tester, reach: atOne);
      expect(find.text('Kemi'), findsNothing);
      playing.value = 2;
      await tester.pumpAndSettle();
      expect(find.text('Kemi'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Character'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Kemi'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Kemi'), findsNothing);
    });

    testWidgets('two at once come one after the other', (tester) async {
      await pump(tester, reach: atOne);
      playing.value = 2;
      await tester.pumpAndSettle();
      expect(find.text('Kemi'), findsOneWidget);
      expect(find.text('The Vault'), findsNothing);
      await tester.pump(SomeoneNew.stays);
      await tester.pumpAndSettle();
      expect(find.text('The Vault'), findsOneWidget);
      expect(find.text('Place'), findsOneWidget);
      await tester.pump(SomeoneNew.stays);
      await tester.pumpAndSettle();
    });

    testWidgets('what you already had is no news, and neither is a chapter heard again', (tester) async {
      await pump(tester, reach: const GuideReach(reached: {_ledger: (at: 2, through: 2)}));
      playing.value = 2;
      await tester.pumpAndSettle();
      expect(find.text('Kemi'), findsNothing);
      playing.value = 1;
      await tester.pumpAndSettle();
      playing.value = 2;
      await tester.pumpAndSettle();
      expect(find.text('Kemi'), findsNothing);
    });

    testWidgets('it does not ask for what is further on', (tester) async {
      await pump(tester, reach: atOne);
      playing.value = 4;
      await tester.pumpAndSettle();
      expect(find.text('Zee'), findsNothing);
      await tester.pump(SomeoneNew.stays);
      await tester.pump(SomeoneNew.stays);
      await tester.pumpAndSettle();
    });

    testWidgets('a press opens the entry', (tester) async {
      await pump(tester, reach: atOne);
      playing.value = 2;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kemi'));
      await tester.pumpAndSettle();
      expect(find.text('entry kemi'), findsOneWidget);
    });

    testWidgets('a file has no world and so no one to find', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final file = LibraryItem(id: 'file', format: FileFormat.m4b, title: 'A file', byteLength: 1, addedAt: DateTime.utc(2026), file: 'file.m4b');
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(audio: _Audio(), catalogue: const [], worlds: const [], reach: atOne, settings: const DeviceSettings()),
          child: MaterialApp(
            home: Stack(
              children: [SomeoneNew(item: file, chapter: _chapter(2))],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kemi'), findsNothing);
    });
  });

  group('a tablet (P26, P27)', () {
    const sideways = Size(1280, 800);
    const upright = Size(800, 1280);
    const reached = GuideReach(reached: {_ledger: (at: 2, through: 2)});

    testWidgets('sideways, a world stays at the left, so its press never leaves the screen (P26h)', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), worlds: [_here], reach: reached, size: sideways);
      expect(tester.getSize(find.byType(WorldPane)).width, 460);
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      expect(find.text('Kemi'), findsOneWidget);
      final press = find.byType(WorldPress);
      expect(press, findsOneWidget);
      expect(tester.getTopLeft(press).dx, lessThan(460));
      expect(tester.getTopLeft(find.text('Kemi')).dx, greaterThan(460));
    });

    testWidgets('upright, it keeps the Fold’s page (P26u)', (tester) async {
      await _pump(tester, location: Routes.world('undersong'), worlds: [_here], reach: reached, size: upright);
      expect(find.byType(WorldPane), findsNothing);
      expect(find.byType(WorldPress), findsOneWidget);
    });

    for (final size in const [sideways, upright]) {
      testWidgets('People runs five across at ${size.width.toInt()} wide', (tester) async {
        const everyone = GuideReach(reached: {_ledger: (at: 6, through: 6)});
        final crowd = Guide(
          productions: _guide.productions,
          characters: [
            for (var i = 0; i < 7; i++) GuideCharacter(id: 'c$i', name: 'Person $i', sections: _says('.')),
            _kemi,
          ],
          places: const [],
          lore: const [],
        );
        await _pump(tester, location: Routes.world('undersong'), worlds: [_here], reach: everyone, guide: crowd, size: size);
        await tester.tap(find.text('People'));
        await tester.pumpAndSettle();
        final tops = [for (var i = 0; i < 6; i++) tester.getTopLeft(find.text('Person $i')).dy];
        expect(tops.take(4).toSet(), hasLength(1), reason: 'Kemi is new and first, then four on her row');
        expect(tops[5], greaterThan(tops[3]));
      });
    }

    testWidgets('a character keeps the portrait at the left and its words at the right (P26n)', (tester) async {
      await _pump(tester, location: Routes.guideEntry(Routes.worldsWorld('undersong'), 'maren'), worlds: [_here], reach: reached, size: sideways);
      expect(tester.getSize(find.byType(WorldPane)).width, 460);
      expect(tester.getTopLeft(find.textContaining('Voice', findRichText: true)).dx, lessThan(460));
      expect(tester.getTopLeft(find.text('Tide-caller.')).dx, greaterThan(460));
    });

    testWidgets('You: two columns sideways, one upright (P26r, P26x)', (tester) async {
      await _pump(tester, location: Routes.you, size: sideways);
      expect(tester.getTopLeft(find.text('Appearance'.toUpperCase())).dy, tester.getTopLeft(find.text('Downloads'.toUpperCase())).dy);
      await _pump(tester, location: Routes.you, size: upright);
      expect(tester.getTopLeft(find.text('Downloads'.toUpperCase())).dy, greaterThan(tester.getTopLeft(find.text('Appearance'.toUpperCase())).dy));
    });

    testWidgets('a sheet keeps a phone’s width, centred (P26e)', (tester) async {
      await _pump(
        tester,
        location: Routes.world('undersong'),
        catalogue: [_listed(age: '18+')],
        size: sideways,
      );
      await tester.tap(find.textContaining('Start', findRichText: true).first);
      await tester.pumpAndSettle();
      // Its press runs its width, less the sheet's margins.
      final press = tester.getRect(find.widgetWithText(FilledButton, 'I am 18 or older · Start'));
      expect(press.width, 560 - 32);
      expect(press.center.dx, closeTo(640, 0.5));
    });

    testWidgets('a teaser is upright over its blur sideways, and fills the tablet upright (P27a, P27q)', (tester) async {
      await _pump(tester, size: sideways);
      await _openFeed(tester, _feedOf([_guide]), start: 1);
      expect(tester.getTopLeft(find.text('Bray')).dx, greaterThan(400));
      await _pump(tester, size: upright);
      await _openFeed(tester, _feedOf([_guide]), start: 1);
      expect(tester.getTopLeft(find.text('Bray')).dx, 16);
    });
  });

  test('a clip’s picture is read from the guide’s own folder', () {
    final pages = _feedOf([_guide]);
    expect(File(pages.first.guide.pathOf('bells.jpg')).path, 'guide/bells.jpg');
  });
}
