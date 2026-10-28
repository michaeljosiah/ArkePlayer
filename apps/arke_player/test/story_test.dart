import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/features/stories/application/stories.dart';
import 'package:arke_player/features/stories/presentation/story_widgets.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'story_fixture.dart';

// SPEC-058 R-82 – R-88, Player P18: a story installed beside its world, played at its own shape, its
// choices in the author's order with the closed ones speaking only through their reasons, its route
// with Choose again, and where you are, replayed. The stories are the shared fixtures (R-81).
void main() {
  final lowWater = readStoryJson(storyJson('low-water.json'));
  final ring = readStoryJson(storyJson('synthetic.json'));
  final lantern = readStoryJson(storyJson('lantern-road.json'));
  final lowStory = loadedStory(storyProduction(lowWaterId, 'Low Water', lowWater, picture: 'drowned-quarter.jpg'), lowWater);
  final ringStory = loadedStory(storyProduction(ringOnceId, 'Ring Once', ring, picture: 'char-odile.jpg'), ring, fallback: 'char-odile.jpg');
  final lanternStory = loadedStory(
    storyProduction(lanternId, 'The Lantern Road', lantern, picture: 'art-direction-illustrated.jpg'),
    lantern,
    pictures: {
      for (final scene in lantern.scenes.values)
        for (final beat in scene.beats) ?beat.tall: 'maren-ledger-tall.jpg',
    },
    fallback: 'art-direction-illustrated.jpg',
  );
  final stories = [lowStory, ringStory, lanternStory];
  final world = Routes.libraryWorld(worldId);
  String page(String id) => Routes.production(world, id);

  MemorySaves saved(LoadedStory story, Map<String, Object?> save) => MemorySaves({story.key: save});

  /// The choice cards on screen, top to bottom and left to right.
  List<ChoiceCard> cards(WidgetTester tester) => tester.widgetList<ChoiceCard>(find.byType(ChoiceCard)).toList();

  group('installing and Update app (R-82, R-83)', () {
    testWidgets('an installed story sits under Play with its kind line, and opens its page', (tester) async {
      await pumpStories(tester, world, stories: stories);
      expect(find.text('Play'), findsWidgets);
      expect(find.text('Interactive movie · 6 scenes'), findsNWidgets(2));
      expect(find.text('Visual novel · 5 scenes'), findsOneWidget);
      await tester.tap(find.text('Low Water'));
      await tester.pumpAndSettle();
      expect(find.text('Interactive movie · The Undersong · 6 scenes'), findsOneWidget);
    });

    testWidgets('a story whose version this Player does not read shows Update app, and opens nothing', (tester) async {
      final listed = listedStoryWorld([
        (lowWaterId, 'Low Water', 'Interactive movie · 6 scenes', 1),
        ('the-red-quiet', 'First Contact', 'Interactive movie · 202 scenes', 2),
      ]);
      await pumpStories(tester, world, stories: [lowStory], listed: listed);
      expect(find.text('Update app'), findsOneWidget);
      await tester.tap(find.text('First Contact'));
      await tester.pumpAndSettle();
      expect(find.text('Update app'), findsOneWidget, reason: 'the tile opens nothing');
      // Before the world is installed, too.
      await pumpStories(tester, world, stories: const [], listed: listed, installed: false);
      expect(find.text('Update app'), findsOneWidget);
    });
  });

  group('where you are (R-88)', () {
    testWidgets('no save: Play, and no route', (tester) async {
      await pumpStories(tester, page(lowWaterId), stories: stories);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Your route'), findsNothing);
    });

    testWidgets('a save: Continue at its scene, and the route under it (P18a)', (tester) async {
      await pumpStories(tester, page(lowWaterId), stories: stories, saves: saved(lowStory, saveAt(lowWater, ['ch_follow', 'ch_wait'])));
      expect(find.text('Continue · The Vigil'), findsOneWidget);
      expect(find.text('1.2 GB'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('now'), 200);
      expect(find.text('Your route'), findsOneWidget);
      expect(find.text('The drowned quarter'), findsOneWidget);
      expect(find.text('Follow the lantern'), findsOneWidget);
      expect(find.text('Wait for low water'), findsOneWidget);
      expect(find.text('Choose again'), findsNWidgets(2));
      expect(find.text('1:12'), findsOneWidget, reason: 'a scene’s length is what it plays');
      expect(find.textContaining('key'), findsNothing, reason: 'facts are never shown');
    });

    testWidgets('a route an update broke, or a save that cannot be read, gives way to Start again; the old save is kept', (tester) async {
      final broken = saveAt(ring, ['ch_light'])..['route'] = ['ch_light', 'ch_drop'];
      final saves = saved(ringStory, broken);
      await pumpStories(tester, page(ringOnceId), stories: stories, saves: saves);
      expect(find.text('Start again'), findsOneWidget);
      expect(find.textContaining('Continue'), findsNothing);
      expect(find.text('Your route'), findsNothing);
      expect(saves.kept, isEmpty, reason: 'nothing overwrites the old route until Start again is pressed');

      await pumpStories(tester, page(ringOnceId), stories: stories, saves: saved(ringStory, {'version': 7}));
      expect(find.text('Start again'), findsOneWidget);
    });

    testWidgets('Start again begins a new route, and the player opens at the start', (tester) async {
      final saves = saved(ringStory, {'version': 7});
      await pumpStories(tester, page(ringOnceId), stories: stories, saves: saves, reel: PictureReel.new);
      await tester.tap(find.text('Start again'));
      await tester.pumpAndSettle();
      expect(saves.kept.first!['route'], isEmpty);
      expect(saves.kept.first!['scene'], 'sc_harbour');
      expect(find.text('The harbour at dusk'), findsOneWidget);
    });

    testWidgets('a changed document that still takes the route continues it', (tester) async {
      await pumpStories(
        tester,
        page(ringOnceId),
        stories: stories,
        saves: saved(ringStory, saveAt(ring, ['ch_light', 'ch_keep'], fingerprint: 'sha256:${'0' * 64}')),
      );
      expect(find.text('Continue · The bell tower'), findsOneWidget);
    });
  });

  group('the choices (R-84, R-85)', () {
    testWidgets('a 16:9 movie upright is whole at 300 from the top, two choices stacked under it, the first in focus (P18b)', (tester) async {
      await pumpStories(tester, Routes.story(worldId, lowWaterId), stories: stories, saves: saved(lowStory, saveAt(lowWater, const [])));
      final picture = find.byKey(const ValueKey('reel'));
      expect(tester.getRect(picture), const Rect.fromLTWH(0, 300, 390, 219.375));
      final shown = cards(tester);
      expect([for (final card in shown) (card.option.label, card.number, card.focus)], [('Follow the lantern', 1, true), ('Stay with the boat', 2, false)]);
      final first = tester.getRect(find.byType(ChoiceCard).at(0));
      final second = tester.getRect(find.byType(ChoiceCard).at(1));
      expect(first.height, 58);
      expect((first.left, first.right), (16, 374));
      expect(second.top - first.bottom, 10);
      expect(find.text('Replay scene'), findsOneWidget);
      expect(find.byTooltip('Route'), findsOneWidget);
      expect(find.byTooltip('Captions'), findsNothing, reason: 'a story document carries no captions');
    });

    testWidgets('turned, two sit side by side (P18c); three or more are always one list', (tester) async {
      await pumpStories(
        tester,
        Routes.story(worldId, lowWaterId),
        stories: stories,
        size: const Size(844, 390),
        saves: saved(lowStory, saveAt(lowWater, const [])),
      );
      final rects = [for (var i = 0; i < 2; i++) tester.getRect(find.byType(ChoiceCard).at(i))];
      expect(rects[0].top, rects[1].top);
      expect(rects[1].left - rects[0].right, 12);

      await pumpStories(
        tester,
        Routes.story(worldId, ringOnceId),
        stories: stories,
        size: const Size(844, 390),
        saves: saved(ringStory, saveAt(ring, ['ch_light', 'ch_leave'])),
      );
      final listed = [for (var i = 0; i < 4; i++) tester.getRect(find.byType(ChoiceCard).at(i))];
      expect(listed.map((rect) => rect.left).toSet(), hasLength(1));
    });

    testWidgets('a closed choice keeps its place with a dash and its reason; the open ones are numbered around it; one with no reason is hidden (P18d)', (
      tester,
    ) async {
      await pumpStories(tester, Routes.story(worldId, ringOnceId), stories: stories, saves: saved(ringStory, saveAt(ring, ['ch_light', 'ch_leave'])));
      expect(
        [for (final card in cards(tester)) (card.option.label, card.number, card.option.open)],
        [('Ring once', 1, true), ('Use the tenth key', null, false), ('Signal with the lamp', 2, true), ('Wait for the tide', 3, true)],
      );
      expect(find.text('–'), findsOneWidget);
      expect(find.text('Left at the weigh house'), findsOneWidget);
      expect(find.text('Swim for the vault'), findsNothing, reason: 'closed, with no reason written');

      // In the dark the lamp's choice closes too, under the author's own label for it.
      await pumpStories(tester, Routes.story(worldId, ringOnceId), stories: stories, saves: saved(ringStory, saveAt(ring, ['ch_dark', 'ch_leave'])));
      expect(
        [for (final card in cards(tester)) (card.option.label, card.number)],
        [('Ring once', 1), ('Use the tenth key', null), ('Signal the boats', null), ('Wait for the tide', 2), ('Swim for the vault', 3)],
      );
      expect(find.text('No light to signal with'), findsOneWidget);
      // A closed choice cannot be taken.
      await tester.tap(find.text('Use the tenth key'));
      await tester.pumpAndSettle();
      expect(find.text('The bell tower'), findsOneWidget);
    });

    testWidgets('choosing keeps the route and plays where it leads; at the scene’s end its choices', (tester) async {
      final saves = saved(lowStory, saveAt(lowWater, const []));
      await pumpStories(tester, Routes.story(worldId, lowWaterId), stories: stories, saves: saves, reel: () => PictureReel(instant: true));
      await tester.tap(find.text('Follow the lantern'));
      await tester.pumpAndSettle();
      expect(find.text('The causeway'), findsOneWidget);
      expect([for (final card in cards(tester)) card.option.label], ['Cross before the tide', 'Wait for low water']);
      expect(saves.kept.last!['route'], ['ch_follow']);
      expect(saves.kept.last!['choosing'], isTrue);
      expect(saves.kept.any((save) => save!.containsKey('facts')), isFalse);
    });
  });

  group('the route (R-86)', () {
    testWidgets('Choose again at the weigh house takes the key back, and the tenth key opens again', (tester) async {
      final saves = saved(ringStory, saveAt(ring, ['ch_dark', 'ch_leave']));
      await pumpStories(
        tester,
        Routes.story(worldId, ringOnceId),
        stories: stories,
        saves: saves,
        reel: () => PictureReel(instant: true, shape: const Size(1080, 1920)),
      );
      expect(find.text('Left at the weigh house'), findsOneWidget);
      await tester.tap(find.byTooltip('Route'));
      await tester.pumpAndSettle();
      expect(find.text('3 scenes'), findsOneWidget);
      expect(find.text('Start over'), findsOneWidget);
      // The second taken choice: Leave the key.
      await tester.tap(find.text('Choose again').at(1));
      await tester.pumpAndSettle();
      expect(find.text('The weigh house'), findsOneWidget);
      expect(saves.kept.last!['route'], ['ch_dark']);
      await tester.tap(find.text('Keep the key'));
      await tester.pumpAndSettle();
      final key = cards(tester).singleWhere((card) => card.option.choice.id == 'ch_key');
      expect((key.option.open, key.number), (true, 2));
      expect(find.text('Left at the weigh house'), findsNothing);
    });

    testWidgets('Choose again on the page cuts the route there and opens the player at that decision', (tester) async {
      final saves = saved(ringStory, saveAt(ring, ['ch_dark', 'ch_leave'], place: const StoryAt(Duration(seconds: 4))));
      await pumpStories(tester, page(ringOnceId), stories: stories, saves: saves, stills: const {'sc_bell': 'char-odile.jpg'});
      await tester.scrollUntilVisible(find.text('now'), 200);
      await tester.tap(find.text('Choose again').first);
      await tester.pumpAndSettle();
      expect(saves.kept.first!['route'], isEmpty);
      expect([for (final card in cards(tester)) card.option.label], ['Light the lamp', 'Go on in the dark']);
    });

    testWidgets('a route of more than five scenes folds its middle into N more scenes, which opens it', (tester) async {
      final chain = readStoryJson(chainStory([for (var n = 1; n <= 8; n++) ('sc_step-$n', 'Step $n', 48000)], [for (var n = 1; n < 8; n++) 'Go to $n']));
      final story = loadedStory(storyProduction('steps', 'Steps', chain), chain);
      await pumpStories(tester, page('steps'), stories: [story], saves: saved(story, saveAt(chain, [for (var n = 0; n < 7; n++) 'ch_step-$n'])));
      await tester.scrollUntilVisible(find.text('now'), 200);
      expect(find.text('5 more scenes'), findsOneWidget);
      expect([for (var n = 1; n <= 8; n++) find.text('Step $n').evaluate().isNotEmpty], [true, false, false, false, false, false, true, true]);
      expect(find.text('Choose again'), findsNWidgets(2));
      await tester.tap(find.text('5 more scenes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Step 4'), -100);
      expect(find.text('5 more scenes'), findsNothing);
      expect(find.text('Step 4'), findsOneWidget);
    });
  });

  group('an ending (P4c)', () {
    testWidgets('its variant’s title and text, Start again and Back to last choice', (tester) async {
      final saves = saved(ringStory, saveAt(ring, ['ch_light', 'ch_keep', 'ch_ring']));
      await pumpStories(tester, Routes.story(worldId, ringOnceId), stories: stories, saves: saves);
      expect(find.text('ENDING'), findsOneWidget);
      expect(find.text('The boats come in'), findsOneWidget);
      expect(find.text('The lamp brings them home.'), findsOneWidget);
      expect(find.text('Light the lamp · Keep the key · Ring once'), findsOneWidget);
      await tester.tap(find.text('Back to last choice'));
      await tester.pumpAndSettle();
      expect(find.text('Ring once'), findsOneWidget);
      expect(saves.kept.last!['route'], ['ch_light', 'ch_keep']);
      await tester.tap(find.byTooltip('Route'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start over'));
      await tester.pumpAndSettle();
      expect(saves.kept.last!['route'], isEmpty);
    });
  });

  group('a visual novel (R-87)', () {
    testWidgets('a beat’s Tall picture fills the phone; tap for the next; a voiced line is heard; at a choice the last line stays', (tester) async {
      final voice = HeardVoice();
      final saves = MemorySaves();
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, saves: saves, voice: voice);
      expect(find.text('The lamp market opens at dusk, a hundred small fires on the water.'), findsOneWidget);
      expect(voice.played, hasLength(1));
      final picture = tester.widget<Image>(find.byType(Image).first);
      expect((picture.image as FileImage).file.path, endsWith('maren-ledger-tall.jpg'));
      expect(tester.getSize(find.byType(Image).first), const Size(390, 844));
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Log'), findsOneWidget);

      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(find.text('MARA'), findsOneWidget);
      expect(find.text('You came back. I said you would.'), findsOneWidget);
      expect(voice.played, hasLength(2));
      expect(saves.kept.last!['beat'], 1);

      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect([for (final card in cards(tester)) card.option.label], ['Buy a lantern', 'Walk on without one']);
      expect(find.text('You came back. I said you would.'), findsOneWidget, reason: 'the last line stays');
      expect(find.text('Replay scene'), findsOneWidget);
    });

    testWidgets('the log holds what the scene has said', (tester) async {
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories);
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();
      expect(find.text('Scene 1'), findsOneWidget);
      expect(find.text('The lamp market opens at dusk, a hundred small fires on the water.'), findsNWidgets(1));
      expect(find.text('You came back. I said you would.'), findsNWidgets(2));
    });
  });
}
