import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/features/players/presentation/chrome.dart';
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

  // P19 rules 1, 2 and 5: a visual novel plays itself, a voiced beat until its voice ends and 0.6 s
  // more, any other for its reading time; a tap shows or hides the controls and never moves on.
  // HeardVoice speaks a line until the test ends it, and the clock is the test's own.
  group('a visual novel plays itself (R-87; P19 rules 1, 2, 5)', () {
    const first = 'The lamp market opens at dusk, a hundred small fires on the water.';
    const second = 'You came back. I said you would.';
    Finder pressable(String text) => find.text(text).hitTestable();

    testWidgets('a beat’s Tall picture fills the phone; it opens playing, heard, and moves on 0.6 s after the voice ends; at a choice the last line stays', (
      tester,
    ) async {
      final voice = HeardVoice();
      final saves = MemorySaves();
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, saves: saves, voice: voice);
      expect(find.text(first), findsOneWidget);
      expect(voice.played, hasLength(1));
      final picture = tester.widget<Image>(find.byType(Image).first);
      expect((picture.image as FileImage).file.path, endsWith('maren-ledger-tall.jpg'));
      expect(tester.getSize(find.byType(Image).first), const Size(390, 844));
      expect(find.text('Auto'), findsNothing, reason: 'Play and Pause replace it');
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing, reason: 'nothing in the box asks for a tap');

      // A voice speaks for as long as it lasts, and nothing moves on before it ends.
      await tester.pump(const Duration(seconds: 30));
      expect(find.text(first), findsOneWidget);
      voice.end();
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.text(first), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('MARA'), findsOneWidget);
      expect(find.text(second), findsOneWidget);
      expect(voice.played, hasLength(2));
      expect(saves.kept.last!['beat'], 1);

      // The third beat is a picture held without a line, for 1.5 s; then the choice of two.
      voice.end();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 1499));
      expect(cards(tester), isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect([for (final card in cards(tester)) card.option.label], ['Buy a lantern', 'Walk on without one']);
      expect(find.text(second), findsOneWidget, reason: 'the last line stays');
      expect(find.text('Replay scene'), findsOneWidget);
      expect(pressable('Log'), findsOneWidget, reason: 'Log beside Replay scene (P19e)');
      expect(find.byType(PlayPause), findsNothing, reason: 'the choices take the transport’s place');
      expect(saves.kept.last!['choosing'], isTrue);
    });

    testWidgets('a tap shows or hides the controls and never moves on, and the box never moves (P19a, P19b)', (tester) async {
      final voice = HeardVoice();
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, voice: voice);
      // It opens with its controls, which rest after 2.5 s while it plays.
      expect(pressable('Back'), findsOneWidget);
      expect(pressable('Log'), findsOneWidget);
      expect(pressable('Narration'), findsOneWidget);
      expect(find.byType(PlayPause).hitTestable(), findsOneWidget);
      final line = tester.getRect(find.text(first));
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();
      expect(pressable('Back'), findsNothing);
      expect(pressable('Narration'), findsNothing);
      expect(tester.getRect(find.text(first)), line);
      for (var tap = 1; tap <= 3; tap++) {
        await tester.tapAt(const Offset(200, 400));
        await tester.pumpAndSettle();
        expect(find.text(first), findsOneWidget, reason: 'a tap never moves on');
        expect(pressable('Back'), tap.isOdd ? findsOneWidget : findsNothing);
        expect(tester.getRect(find.text(first)), line, reason: 'the box is the story, not a control');
      }
      // The box too: a tap on it is a tap on the story.
      await tester.tap(find.text(first));
      await tester.pumpAndSettle();
      expect(find.text(first), findsOneWidget);
      expect(voice.played, hasLength(1));
    });

    testWidgets('Pause holds a beat and its voice, and the controls stay; Play goes on; Back plays the beat before', (tester) async {
      final voice = HeardVoice();
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, voice: voice);
      await tester.tap(find.byType(PlayPause));
      await tester.pump();
      expect((voice.paused, tester.widget<PlayPause>(find.byType(PlayPause)).playing), (true, false));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text(first), findsOneWidget);
      expect(pressable('Back'), findsOneWidget, reason: 'paused, the controls never rest');
      await tester.tap(find.byType(PlayPause));
      await tester.pump();
      expect(voice.paused, isFalse);
      voice.end();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(second), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(find.text(first), findsOneWidget);
      expect(voice.played, hasLength(3), reason: 'the beat before is heard again');

      // A line read without a voice: paused, it waits; played again, it is given its time to read.
      // The road's first line is 37 characters, 3.165 s.
      await pumpStories(
        tester,
        Routes.story(worldId, lanternId),
        stories: stories,
        voice: HeardVoice(),
        saves: saved(lanternStory, saveAt(lantern, ['ch_buy'], place: const StoryAtBeat(0))),
      );
      const road = 'The road runs dark between the reeds.';
      expect(find.text(road), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(PlayPause));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text(road), findsOneWidget);
      await tester.tap(find.byType(PlayPause));
      await tester.pump(const Duration(milliseconds: 3164));
      expect(find.text(road), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('The lantern throws your shadow long across the water.'), findsOneWidget);
    });

    testWidgets('an unvoiced beat moves on after 1.5 s and 45 ms a character', (tester) async {
      final saves = saved(lanternStory, saveAt(lantern, ['ch_buy'], place: const StoryAtBeat(0)));
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, saves: saves);
      // Back at a scene's first beat starts it again, so its clock starts here. 37 characters: 3.165 s;
      // then 53: 3.885 s, and with a lantern Mara's line does not play, so then the choice.
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3164));
      expect(find.text('The road runs dark between the reeds.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('The lantern throws your shadow long across the water.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3884));
      expect(cards(tester), isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect([for (final card in cards(tester)) card.option.label], ['Wade the ford', 'Take the old bridge']);
    });

    testWidgets('Narration off: no voice, each beat held for its reading time, and off for this story when it opens again', (tester) async {
      final voice = HeardVoice();
      final saves = MemorySaves();
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, saves: saves, voice: voice);
      expect(tester.widget<NarrationSwitch>(find.byType(NarrationSwitch)).on, isTrue);
      await tester.tap(find.text('Narration'));
      await tester.pump();
      expect(tester.widget<NarrationSwitch>(find.byType(NarrationSwitch)).on, isFalse);
      expect(voice.speaking, isFalse, reason: 'the line stops');
      expect(saves.kept.last!['narration'], false);
      // 66 characters: 4.47 s; the next beat is voiced, and still read, not heard.
      await tester.pump(const Duration(milliseconds: 4469));
      expect(find.text(first), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(second), findsOneWidget);
      expect(voice.played, hasLength(1));
      expect(saves.kept.last!['narration'], false);

      // Opened again, it is still off, and nothing is heard; on again, the beat is heard from its start.
      final again = HeardVoice();
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, saves: saved(lanternStory, saves.kept.last!), voice: again);
      expect(find.text(second), findsOneWidget);
      expect(tester.widget<NarrationSwitch>(find.byType(NarrationSwitch)).on, isFalse);
      expect(again.played, isEmpty);
      await tester.tap(find.text('Narration'));
      await tester.pump();
      expect(again.played, hasLength(1));
      // The story's page keeps it off through Start again too.
      final page = MemorySaves({
        lanternStory.key: saves.kept.last!..['route'] = ['ch_gone'],
      });
      await pumpStories(tester, Routes.production(world, lanternId), stories: stories, saves: page);
      await tester.tap(find.text('Start again'));
      await tester.pumpAndSettle();
      expect(page.kept.first!['route'], isEmpty);
      expect(page.kept.first!['narration'], false);
    });

    testWidgets('a story without voices has no Narration, and every beat is read (P19d)', (tester) async {
      final quiet = readStoryJson(_firstContact);
      final story = loadedStory(storyProduction('first-contact', 'First Contact', quiet), quiet, fallback: 'red-quiet-cover.jpg');
      await pumpStories(tester, Routes.story(worldId, 'first-contact'), stories: [story]);
      expect(find.text('Stop. They are not shooting.'), findsOneWidget);
      expect(find.byType(NarrationSwitch), findsNothing);
      expect(pressable('Back'), findsOneWidget);
      // 28 characters: 2.76 s, then the narration under it, then the choice of two.
      await tester.pump(const Duration(milliseconds: 2760));
      expect(find.text('Dev puts his hand on the emergency barrier.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500 + 45 * 43));
      await tester.pumpAndSettle();
      expect([for (final card in cards(tester)) card.option.label], ['Return with Ana for Elsie', 'Seal the shaft and leave Elsie']);
    });

    testWidgets('the log holds what the scene has said, and the story waits under it', (tester) async {
      final voice = HeardVoice();
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, voice: voice);
      voice.end();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();
      expect(find.text('Scene 1'), findsOneWidget);
      expect(find.text(first), findsNWidgets(1));
      expect(find.text(second), findsNWidgets(2));
      expect(voice.paused, isTrue);
      await tester.pump(const Duration(seconds: 30));
      // Closed, the story goes on where it was.
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
      expect(find.text('Scene 1'), findsNothing);
      expect(voice.paused, isFalse);
      expect(find.text(second), findsOneWidget);
    });
  });

  // P19 rules 3 and 4: a lone way on is never shown, and is still a step of the route.
  group('a lone way (P19 rules 3, 4)', () {
    testWidgets('is never shown: the story plays straight through it, and the route keeps it as a step with no row (P19h)', (tester) async {
      final saves = saved(lanternStory, saveAt(lantern, ['ch_buy', 'ch_bridge'], place: const StoryAtBeat(0)));
      final voice = HeardVoice();
      await pumpStories(tester, Routes.story(worldId, lanternId), stories: stories, saves: saves, voice: voice);
      expect(find.text('Half the boards are gone. The lantern finds the rest.'), findsOneWidget);
      // From its start again: 53 characters, 3.885 s, then straight on into Home, with no stop and no
      // Cross the bridge.
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3884));
      expect(find.text('Half the boards are gone. The lantern finds the rest.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(cards(tester), isEmpty);
      expect(find.text('Cross the bridge'), findsNothing);
      expect(find.text('The door is where you left it.'), findsOneWidget);
      expect(voice.played, hasLength(1));
      expect(saves.kept.last!['route'], ['ch_buy', 'ch_bridge', 'ch_cross'], reason: 'a step of the route, so it replays');

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();
      expect(find.text('4 scenes'), findsOneWidget);
      expect(find.text('Take the old bridge'), findsOneWidget);
      expect(find.text('Cross the bridge'), findsNothing);
      expect(find.text('Choose again'), findsNWidgets(2));
    });

    testWidgets('a save kept at one goes on through it; an ending lists only the choices made, and Back to last choice goes to the last', (tester) async {
      final saves = saved(lowStory, saveAt(lowWater, ['ch_follow', 'ch_wait']));
      await pumpStories(tester, Routes.story(worldId, lowWaterId), stories: stories, saves: saves, reel: () => PictureReel(instant: true));
      expect(find.text('Climb to the lamp'), findsNothing);
      expect(find.text('The harbour, level'), findsOneWidget);
      expect(find.text('Follow the lantern · Wait for low water'), findsOneWidget);
      expect(saves.kept.last!['route'], ['ch_follow', 'ch_wait', 'ch_climb']);
      await tester.tap(find.text('Back to last choice'));
      await tester.pumpAndSettle();
      expect([for (final card in cards(tester)) card.option.label], ['Cross before the tide', 'Wait for low water']);
      expect(saves.kept.last!['route'], ['ch_follow']);
    });

    testWidgets('a production’s route leaves it out, and its fold keeps the last choice made in view (P19h)', (tester) async {
      final chain = readStoryJson(
        chainStory([for (var n = 1; n <= 7; n++) ('sc_step-$n', 'Step $n', 48000)], [for (var n = 1; n < 7; n++) 'Go to ${n + 1}'], lone: const {0, 5}),
      );
      final story = loadedStory(storyProduction('steps', 'Steps', chain), chain);
      await pumpStories(tester, page('steps'), stories: [story], saves: saved(story, saveAt(chain, [for (var n = 0; n < 6; n++) 'ch_step-$n'])));
      await tester.scrollUntilVisible(find.text('now'), 200);
      expect(find.text('3 more scenes'), findsOneWidget);
      expect([for (var n = 1; n <= 7; n++) find.text('Step $n').evaluate().isNotEmpty], [true, false, false, false, true, true, true]);
      expect(find.text('Go to 2'), findsNothing, reason: 'a lone way');
      expect(find.text('Go to 6'), findsOneWidget);
      expect(find.text('Go to 7'), findsNothing, reason: 'a lone way');
      expect(find.text('Choose again'), findsOneWidget);
    });
  });

  // P19 call 27: an interactive movie's controls are a film's.
  group('an interactive movie (P19f)', () {
    testWidgets('back 10 and forward 10 within the scene; the controls rest while it plays, and a tap shows them', (tester) async {
      final reel = PictureReel();
      final saves = saved(lowStory, saveAt(lowWater, const [], place: const StoryAt(Duration(seconds: 20))));
      await pumpStories(tester, Routes.story(worldId, lowWaterId), stories: stories, saves: saves, reel: () => reel);
      expect(reel.position, const Duration(seconds: 20));
      await tester.tap(find.byTooltip('Forward 10 seconds'));
      await tester.pump();
      expect(reel.position, const Duration(seconds: 30));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Back 10 seconds'));
        await tester.pump();
      }
      expect(reel.position, Duration.zero, reason: 'never before the scene’s start');
      expect(find.text('Log'), findsNothing, reason: 'a movie has no beats, Log or Narration');
      expect(find.byType(NarrationSwitch), findsNothing);

      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Forward 10 seconds').hitTestable(), findsNothing);
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Forward 10 seconds').hitTestable(), findsOneWidget);
      expect(reel.position, Duration.zero, reason: 'a tap never moves on');
    });
  });
}

/// First Contact as P19d and P19e draw it: a visual novel with no voices, Imani's line, the narration
/// under it, and a choice of two.
final _firstContact = {
  'format': 'arke-story',
  'version': 1,
  'kind': 'novel',
  'shape': '16:9',
  'start': 'sc_open-hands',
  'fingerprint': 'sha256:${'f' * 64}',
  'facts': <Object?>[],
  'scenes': [
    {
      'id': 'sc_open-hands',
      'title': 'Open hands',
      'beats': [
        {'picture': 'fc-hands', 'speaker': 'Imani Okoro', 'line': 'Stop. They are not shooting.'},
        {'picture': 'fc-hands', 'line': 'Dev puts his hand on the emergency barrier.'},
      ],
    },
    {
      'id': 'sc_board',
      'title': 'The first name on the board',
      'beats': [
        {'picture': 'fc-board', 'line': 'Ana waits.'},
      ],
    },
  ],
  'presentation': <Object?>[],
  'choices': [
    {'id': 'ch_return', 'from': 'sc_open-hands', 'to': 'sc_board', 'label': 'Return with Ana for Elsie', 'effects': <Object?>[]},
    {'id': 'ch_seal', 'from': 'sc_open-hands', 'to': 'sc_board', 'label': 'Seal the shaft and leave Elsie', 'effects': <Object?>[]},
  ],
  'endings': <Object?>[],
};
