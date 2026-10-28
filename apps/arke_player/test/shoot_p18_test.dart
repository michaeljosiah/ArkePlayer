// Renders P18's screens — a movie's page and its route, Low Water at a choice upright, turned and on
// a Fold, Ring Once's closed choice and its route sheet, The Lantern Road on a Tall picture and at a
// choice, and an ending — over The Undersong's stories, and saves PNGs to compare with the design's
// frames (P18a – P18h, P4c). The samples are the frames' own words, read as story documents; a clip
// is the frame's picture. Not a gate, like shoot_test.dart, so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_p18_test.dart   (from apps/arke_player; PNGs in build/shots)
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/features/stories/application/stories.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'story_fixture.dart';

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

// ---- The frames' samples, as story documents ------------------------------------------------

/// Low Water's page (P18a): fourteen scenes, the route through three of them.
final _lowPage = readStoryJson(
  chainStory(
    [('sc_harbour', 'The harbour at dusk', 72000), ('sc_pier', 'Under the pier', 54000), ('sc_quarter', 'The drowned quarter', 72000)],
    ['Take the skiff', 'Follow the lantern'],
    shape: '16:9',
    extra: 11,
  ),
);

/// Ring Once at the bell tower (P18d): the key left at the weigh house closes the tenth key.
final _ring = readStoryJson({
  'format': 'arke-story',
  'version': 1,
  'kind': 'movie',
  'shape': '9:16',
  'start': 'sc_weigh',
  'fingerprint': 'sha256:${'b' * 64}',
  'facts': [
    {
      'id': 'key',
      'type': 'enum',
      'values': ['held', 'left'],
      'default': 'held',
    },
  ],
  'scenes': [
    {
      'id': 'sc_weigh',
      'title': 'The weigh house',
      'clips': [
        {'asset': 'ro-weigh', 'from': 0, 'to': 65000},
      ],
    },
    {
      'id': 'sc_bell',
      'title': 'The bell tower',
      'clips': [
        {'asset': 'ro-bell', 'from': 0, 'to': 41000},
      ],
    },
    {
      'id': 'sc_end',
      'title': 'The bell',
      'clips': [
        {'asset': 'ro-end', 'from': 0, 'to': 30000},
      ],
    },
  ],
  'presentation': <Object?>[],
  'choices': [
    {
      'id': 'ch_leave',
      'from': 'sc_weigh',
      'to': 'sc_bell',
      'label': 'Leave the key',
      'effects': [
        {'fact': 'key', 'value': 'left'},
      ],
    },
    {'id': 'ch_ring', 'from': 'sc_bell', 'to': 'sc_end', 'label': 'Ring the bell', 'effects': <Object?>[]},
    {'id': 'ch_wake', 'from': 'sc_bell', 'to': 'sc_end', 'label': 'Wake Maren', 'effects': <Object?>[]},
    {
      'id': 'ch_key',
      'from': 'sc_bell',
      'to': 'sc_end',
      'label': 'Use the tenth key',
      'when': {'op': 'eq', 'fact': 'key', 'value': 'held'},
      'effects': <Object?>[],
      'unavailable': {'reason': 'Left at the weigh house'},
    },
    {'id': 'ch_down', 'from': 'sc_bell', 'to': 'sc_end', 'label': 'Go down alone', 'effects': <Object?>[]},
  ],
  'endings': [
    {'scene': 'sc_end', 'title': 'The Bell Rings Twice'},
  ],
});

/// Ring Once's route (P18e): eight scenes, upright.
final _ringRoute = readStoryJson(
  chainStory(
    [
      ('sc_steps', 'The harbour steps', 48000),
      for (var n = 2; n <= 6; n++) ('sc_mid-$n', 'Scene $n', 40000),
      ('sc_weigh', 'The weigh house', 65000),
      ('sc_bell', 'The bell tower', 41000),
    ],
    ['Take the lamp', 'Go on', 'Go on', 'Go on', 'Go on', 'Go on', 'Leave the key'],
  ),
);

Map<String, Object?> _beat(String line, {String picture = 'lr-wide', String? tall}) => {'picture': picture, 'tall': ?tall, 'speaker': 'Maren', 'line': line};

/// The Lantern Road's market (P18f): six beats on Tall pictures.
final _lanternTall = readStoryJson({
  'format': 'arke-story',
  'version': 1,
  'kind': 'novel',
  'shape': '16:9',
  'start': 'sc_market',
  'fingerprint': 'sha256:${'c' * 64}',
  'facts': <Object?>[],
  'scenes': [
    {
      'id': 'sc_market',
      'title': 'The lamp market',
      'beats': [
        for (var n = 0; n < 6; n++) _beat(n == 3 ? 'The lamp in the quarter is lit again. I wrote it down, so it happened.' : 'Line $n.', tall: 'lr-tall'),
      ],
    },
  ],
  'presentation': <Object?>[],
  'choices': <Object?>[],
  'endings': <Object?>[],
});

/// The Lantern Road's choice (P18g): a wide picture, three roads.
final _lanternChoice = readStoryJson({
  'format': 'arke-story',
  'version': 1,
  'kind': 'novel',
  'shape': '16:9',
  'start': 'sc_market',
  'fingerprint': 'sha256:${'d' * 64}',
  'facts': <Object?>[],
  'scenes': [
    {
      'id': 'sc_market',
      'title': 'The lamp market',
      'beats': [_beat('Two roads out of the market. Only one has a lamp on it.')],
    },
    {
      'id': 'sc_road',
      'title': 'The lamp road',
      'beats': [_beat('On.')],
    },
  ],
  'presentation': <Object?>[],
  'choices': [
    for (final (id, label) in [('ch_lamp', 'Take the lamp road'), ('ch_ilo', 'Go back for Ilo'), ('ch_bell', 'Wait for the bell')])
      {'id': id, 'from': 'sc_market', 'to': 'sc_road', 'label': label, 'effects': <Object?>[]},
  ],
  'endings': <Object?>[],
});

void main() {
  if (!_shoot) {
    test('shots are taken only with SHOOT=1', () {}, skip: 'set SHOOT=1 to render the screens');
    return;
  }

  setUpAll(_loadFonts);

  const pictures = [
    'drowned-quarter.jpg',
    'launch-harbour.jpg',
    'scene4-shot15.jpg',
    'scene4-shot13.jpg',
    'char-odile.jpg',
    'char-maren.jpg',
    'char-bray.jpg',
    'maren-ledger-tall.jpg',
    'art-direction-illustrated.jpg',
    'world-undersong.jpg',
    'ledger-of-nights.jpg',
  ];

  Future<void> preload(WidgetTester tester) => tester.runAsync(() async {
    for (final name in pictures) {
      final loaded = Completer<void>();
      FileImage(File(designAsset(name)))
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
    String location, {
    required List<LoadedStory> stories,
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.dark,
    MemorySaves? saves,
    PictureReel Function()? reel,
    Map<String, String> stills = const {},
    CatalogueWorld? listed,
    Future<void> Function(WidgetTester tester)? act,
  }) async {
    await preload(tester);
    final key = GlobalKey();
    await pumpStories(
      tester,
      location,
      stories: stories,
      size: size,
      ratio: 2,
      brightness: brightness,
      saves: saves,
      reel: reel,
      stills: stills,
      listed: listed,
      key: key,
    );
    if (act != null) {
      await act(tester);
      await tester.pumpAndSettle();
    }
    // Let the pictures decode, then draw once more.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  final lowPage = loadedStory(storyProduction(lowWaterId, 'Low Water', _lowPage, picture: 'drowned-quarter.jpg'), _lowPage);
  final lowWater = readStoryJson(storyJson('low-water.json'));
  final low = loadedStory(storyProduction(lowWaterId, 'Low Water', lowWater, picture: 'drowned-quarter.jpg'), lowWater);
  final ring = loadedStory(storyProduction(ringOnceId, 'Ring Once', _ring, picture: 'char-odile.jpg'), _ring, fallback: 'char-odile.jpg');
  final ringRoute = loadedStory(storyProduction(ringOnceId, 'Ring Once', _ringRoute, picture: 'char-odile.jpg'), _ringRoute, fallback: 'char-odile.jpg');
  LoadedStory lantern(StoryDocument document) => loadedStory(
    storyProduction(lanternId, 'The Lantern Road', document, picture: 'art-direction-illustrated.jpg'),
    document,
    pictures: const {'lr-tall': 'maren-ledger-tall.jpg'},
    fallback: 'art-direction-illustrated.jpg',
  );
  MemorySaves at(LoadedStory story, List<String> route, {StoryPlace place = const StoryAtChoice()}) =>
      MemorySaves({story.key: saveAt(story.document, route, place: place)});
  final world = Routes.libraryWorld(worldId);
  PictureReel tall() => PictureReel(shape: const Size(1080, 1920));

  for (final brightness in Brightness.values) {
    final suffix = brightness == Brightness.dark ? '-dark' : '-light';
    testWidgets(
      'P18a a movie’s page$suffix',
      (t) => shoot(
        t,
        'p18a$suffix',
        Routes.production(world, lowWaterId),
        stories: [lowPage],
        brightness: brightness,
        saves: at(lowPage, ['ch_step-0', 'ch_step-1'], place: const StoryAt(Duration(seconds: 20))),
        stills: const {'sc_harbour': 'launch-harbour.jpg', 'sc_pier': 'scene4-shot15.jpg', 'sc_quarter': 'drowned-quarter.jpg'},
      ),
    );
    testWidgets(
      'P18b upright$suffix',
      (t) => shoot(t, 'p18b$suffix', Routes.story(worldId, lowWaterId), stories: [low], brightness: brightness, saves: at(low, const [])),
    );
    testWidgets(
      'P18c turned$suffix',
      (t) => shoot(
        t,
        'p18c$suffix',
        Routes.story(worldId, lowWaterId),
        stories: [low],
        size: const Size(844, 390),
        brightness: brightness,
        saves: at(low, const []),
      ),
    );
    testWidgets(
      'P18d a 9:16 movie, a choice closed$suffix',
      (t) => shoot(t, 'p18d$suffix', Routes.story(worldId, ringOnceId), stories: [ring], brightness: brightness, saves: at(ring, ['ch_leave']), reel: tall),
    );
    testWidgets(
      'P18e the route$suffix',
      (t) => shoot(
        t,
        'p18e$suffix',
        Routes.story(worldId, ringOnceId),
        stories: [ringRoute],
        brightness: brightness,
        saves: at(ringRoute, [for (var n = 0; n < 7; n++) 'ch_step-$n'], place: const StoryAt(Duration(seconds: 12))),
        reel: tall,
        stills: const {'sc_steps': 'char-maren.jpg', 'sc_weigh': 'char-bray.jpg', 'sc_bell': 'char-odile.jpg'},
        act: (tester) => tester.tap(find.byTooltip('Route')),
      ),
    );
    testWidgets(
      'P18f a novel on its Tall picture$suffix',
      (t) => shoot(
        t,
        'p18f$suffix',
        Routes.story(worldId, lanternId),
        stories: [lantern(_lanternTall)],
        brightness: brightness,
        saves: at(lantern(_lanternTall), const [], place: const StoryAtBeat(3)),
        act: (tester) => tester.tap(find.text('Auto')),
      ),
    );
    testWidgets(
      'P18g a novel’s choice$suffix',
      (t) => shoot(
        t,
        'p18g$suffix',
        Routes.story(worldId, lanternId),
        stories: [lantern(_lanternChoice)],
        brightness: brightness,
        saves: at(lantern(_lanternChoice), const []),
        act: (tester) => tester.tap(find.text('Auto')),
      ),
    );
    testWidgets(
      'P18h on a Fold$suffix',
      (t) => shoot(
        t,
        'p18h$suffix',
        Routes.story(worldId, lowWaterId),
        stories: [low],
        size: const Size(984, 1092),
        brightness: brightness,
        saves: at(low, const []),
      ),
    );
    testWidgets(
      'P4c an ending$suffix',
      (t) => shoot(
        t,
        'p18-ending$suffix',
        Routes.story(worldId, lowWaterId),
        stories: [low],
        brightness: brightness,
        saves: at(low, ['ch_stay', 'ch_ring']),
        stills: const {'sc_quarter': 'drowned-quarter.jpg', 'sc_towers': 'scene4-shot15.jpg', 'sc_bell': 'scene4-shot13.jpg'},
      ),
    );
    testWidgets(
      'a world’s Play, and Update app$suffix',
      (t) => shoot(
        t,
        'p18-world$suffix',
        world,
        stories: [low, ring],
        brightness: brightness,
        listed: listedStoryWorld([
          (lowWaterId, 'Low Water', 'Interactive movie · 6 scenes', 1),
          (ringOnceId, 'Ring Once', 'Interactive movie · 3 scenes', 1),
          ('first-contact', 'First Contact', 'Interactive movie · 202 scenes', 2),
        ]),
        act: (tester) async {
          final page = find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down).first;
          await tester.scrollUntilVisible(find.text('Play').first, 200, scrollable: page);
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(tester.element(find.text('Play').first), alignment: 0.3);
        },
      ),
    );
  }
}
