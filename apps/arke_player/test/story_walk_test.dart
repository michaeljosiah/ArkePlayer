import 'dart:io';

import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/features/stories/application/stories.dart';
import 'package:arke_player/features/stories/presentation/story_widgets.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'story_fixture.dart';

// P19 rules 3 and 4 (SPEC-063 R-11a, SPEC-058 R-87): a story stops only for a choice of two or more —
// a closed choice shown with its reason is one of them — and a lone way plays straight through. The
// rules are tested in arke_world; this walks every route of a story through the story screen itself,
// as a listener reaches each stop: from the start, at each choice again from the save kept there, and
// back from every ending by Back to last choice. Every stop it shows must show two choices or more,
// and the walk must reach every stop the rules say the story has.
//
// The shared fixtures are walked always. A published story package is walked too when
// ARKE_STORY_PACKAGE names one: a private story is checked that way, and never committed.

/// The app's own type, so a line wraps and a choice measures as it does on a phone.
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

/// The screens walked, the design's own: a phone upright and turned, and a Fold open. `small`, a
/// 360 × 640 phone the design does not draw, is walked only when STORY_WALK_SCREENS names it.
const _screens = {'upright': Size(390, 844), 'turned': Size(844, 390), 'fold': Size(984, 1092)};
const _more = {'small': Size(360, 640)};

void main() {
  setUpAll(_loadFonts);
  final screens = switch (Platform.environment['STORY_WALK_SCREENS']) {
    final String names => {for (final name in names.split(',')) name: _screens[name] ?? _more[name] ?? (throw ArgumentError(name))},
    null => _screens,
  };
  final fixtures = [
    for (final (id, title, file) in [
      (lowWaterId, 'Low Water', 'low-water.json'),
      (ringOnceId, 'Ring Once', 'synthetic.json'),
      (lanternId, 'The Lantern Road', 'lantern-road.json'),
    ])
      loadedStory(storyProduction(id, title, readStoryJson(storyJson(file))), readStoryJson(storyJson(file))),
  ];
  for (final story in fixtures) {
    for (final MapEntry(key: name, value: size) in screens.entries) {
      testWidgets('${story.production.title}, $name: every stop on every route shows two choices or more', (tester) async {
        await _walk(tester, story, size);
      });
    }
  }

  final package = Platform.environment['ARKE_STORY_PACKAGE'];
  final published = package == null ? const <String, StoryDocument>{} : readWorldPackage(package).stories;
  for (final MapEntry(key: name, value: size) in screens.entries) {
    testWidgets(
      'a published story package, $name: every stop on every route shows two choices or more',
      (tester) async {
        for (final MapEntry(key: id, value: document) in published.entries) {
          final walk = await _walk(tester, loadedStory(storyProduction(id, id, document), document), size);
          // ignore: avoid_print
          print(
            '$id, $name: ${walk.stops.length} stops showing ${walk.shown} choices, ${walk.seen} in view; ${walk.endings.length} endings, '
            '${walk.lone} lone ways played through, back from ${walk.backs} endings',
          );
        }
      },
      skip: package == null,
      timeout: const Timeout(Duration(minutes: 30)),
    );
  }
}

/// What a walk saw: each stop by its scene and facts, how many choices each showed and how many of
/// them were in view, the endings.
class _Walk {
  final stops = <String>{};
  final shown = <int, int>{};
  final seen = <int, int>{};
  final endings = <String>{};
  int backs = 0;
  int lone = 0;
}

String _place(StoryStep step) => '${step.scene} ${step.facts}';

/// Walks [story] through the story screen at [size], depth first, and returns what it saw.
Future<_Walk> _walk(WidgetTester tester, LoadedStory story, Size size) async {
  final document = story.document;
  final walk = _Walk();
  final voice = HeardVoice();
  var saves = MemorySaves();
  final cards = find.byType(ChoiceCard);
  final ending = find.byType(StoryEndingCard);

  Future<void> reopen(Map<String, Object?>? save) async {
    saves = MemorySaves({story.key: ?save});
    await pumpStories(
      tester,
      Routes.story(worldId, story.production.id),
      stories: [story],
      size: size,
      // A phone's own edges: the status bar and the gesture bar take their room.
      ratio: 2,
      saves: saves,
      voice: voice,
      reel: () => PictureReel(instant: true),
    );
  }

  // On until the screen stops: its choices, or an ending. A movie's clips play through at once; a
  // novel's beats by their reading time, and a voice is heard through as soon as it starts. The
  // press that led here is drawn first, so the choices it was pressed on are gone.
  Future<void> playOn() async {
    await tester.pump();
    for (var i = 0; i < 20000; i++) {
      if (cards.evaluate().isNotEmpty || ending.evaluate().isNotEmpty) return tester.pump();
      voice.end();
      await tester.pump(const Duration(milliseconds: 500));
    }
    fail('${story.production.title} never stopped');
  }

  List<String> route() => [...(saves.kept.last!['route']! as List<Object?>).cast<String>()];
  List<String> showing() => [for (final card in tester.widgetList<ChoiceCard>(cards)) card.option.choice.id];

  // The choices a listener sees as the stop opens, before any scrolling: each whole on the screen,
  // inside the list that holds them, and not covered.
  int inView() {
    final screen = Offset.zero & size;
    var count = 0;
    for (final element in cards.evaluate()) {
      final box = element.renderObject! as RenderBox;
      final rect = (box.localToGlobal(Offset.zero) & box.size).deflate(0.5);
      final list = Scrollable.maybeOf(element)?.context.findRenderObject() as RenderBox?;
      final within = list == null ? screen : screen.intersect(list.localToGlobal(Offset.zero) & list.size);
      final whole = within.contains(rect.topLeft) && within.contains(rect.bottomRight);
      if (whole && find.byWidget(element.widget).hitTestable().evaluate().isNotEmpty) count++;
    }
    return count;
  }

  Future<void> atStop(String how) async {
    final at = route();
    final step = evaluateStory(document, at);
    final shown = showing();
    final where = '${story.production.title}: ${document.scenes[step.scene]!.title}, route ${at.join(' > ')} ($how)';
    expect(shown.length, greaterThanOrEqualTo(2), reason: '$where shows ${shown.length}');
    expect(step.loneWay, isNull, reason: '$where stopped at a lone way');
    final seen = inView();
    expect(seen, greaterThanOrEqualTo(2), reason: '$where has ${shown.length} choices, but ${seen == 1 ? 'one is' : '$seen are'} in view');
    if (!walk.stops.add(_place(step))) return;
    walk.shown.update(shown.length, (n) => n + 1, ifAbsent: () => 1);
    walk.seen.update(seen, (n) => n + 1, ifAbsent: () => 1);
    final open = [
      for (final card in tester.widgetList<ChoiceCard>(cards))
        if (card.option.open) card.option.choice.id,
    ];
    for (final (k, id) in open.indexed) {
      if (k > 0) {
        // Continue from the save kept at this choice: the same choices.
        await reopen(saveAt(document, at));
        expect(showing(), shown, reason: '$where, continued');
      }
      final card = find.byWidgetPredicate((widget) => widget is ChoiceCard && widget.option.choice.id == id);
      await tester.ensureVisible(card);
      await tester.pump();
      await tester.tap(card);
      await playOn();
      final next = route();
      expect(next.take(at.length + 1), [...at, id], reason: '$where: $id pressed');
      walk.lone += next.length - at.length - 1;
      if (ending.evaluate().isEmpty) {
        await atStop('chosen');
        continue;
      }
      walk.endings.add(_place(evaluateStory(document, next)));
      // Back to last choice: the decision just made, its choices again.
      final back = find.text('Back to last choice');
      await tester.ensureVisible(back);
      await tester.pump();
      await tester.tap(back);
      await playOn();
      walk.backs++;
      expect(route(), at, reason: '$where, back from the ending');
      expect(showing(), shown, reason: '$where, back from the ending');
    }
  }

  await reopen(null);
  await playOn();
  if (ending.evaluate().isEmpty) await atStop('from the start');

  // The walk reached every stop the rules say the story has: each reachable state that shows a
  // choice, not a lone way and not an end.
  final expected = <String>{};
  final visited = <String>{};
  final queue = [startStory(document)];
  while (queue.isNotEmpty) {
    final step = queue.removeLast();
    if (!visited.add(_place(step))) continue;
    if (step.loneWay == null && step.open.isNotEmpty) expected.add(_place(step));
    for (final choice in step.open) {
      queue.add(chooseStory(document, step, choice.id));
    }
  }
  expect(walk.stops, expected, reason: '${story.production.title}: every stop walked');
  return walk;
}
