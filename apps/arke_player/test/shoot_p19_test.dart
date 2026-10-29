// Renders P19's screens — a visual novel playing with its controls resting, the controls after a tap
// with Narration, paused on a wide picture, a story without voices, its choice of two, an interactive
// movie with a film's controls, turned, and the route with a lone way — and saves PNGs to compare with
// the design's frames (P19a – P19h). The samples are the frames' own: The Lantern Road (voiced), First
// Contact (no voices; its lines, scene names and choice labels the author's) and Low Water, read as
// story documents. Not a gate, like shoot_test.dart, so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_p19_test.dart   (from apps/arke_player; PNGs in build/shots)
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/features/players/presentation/chrome.dart';
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

const _maren = 'The lamp in the quarter is lit again. I wrote it down, so it happened.';

/// The Lantern Road's market, voiced (P19a, P19b, P19c, P19g): six beats, Maren's line fourth on its
/// Tall picture, her line on the wide one second, and Ilo's third.
StoryDocument _lantern({required bool tall}) => readStoryJson({
  'format': 'arke-story',
  'version': 1,
  'kind': 'novel',
  'shape': '16:9',
  'start': 'sc_market',
  'fingerprint': 'sha256:${tall ? 'c' * 64 : 'd' * 64}',
  'facts': <Object?>[],
  'scenes': [
    {
      'id': 'sc_market',
      'title': 'The lamp market',
      'beats': [
        for (final (n, speaker, line) in [
          (0, 'Maren', 'The market shut at the second bell.'),
          (1, 'Maren', 'Somebody lit a window down there. Nobody lives in the quarter now.'),
          (2, 'Ilo', 'Then somebody lives there.'),
          (3, 'Maren', _maren),
          (4, 'Maren', 'Line 4.'),
          (5, 'Maren', 'Line 5.'),
        ])
          {'picture': 'lr-wide', if (tall) 'tall': 'lr-tall', 'speaker': speaker, 'line': line, 'voice': 'lr-voice-$n'},
      ],
    },
  ],
  'presentation': <Object?>[],
  'choices': [
    for (final (id, label) in [('ch_lamp', 'Take the lamp road'), ('ch_ilo', 'Go back for Ilo')])
      {'id': id, 'from': 'sc_market', 'to': 'sc_market', 'label': label, 'effects': <Object?>[]},
  ],
  'endings': <Object?>[],
});

Map<String, Object?> _scene(String id, String title, List<(String?, String)> lines) => {
  'id': id,
  'title': title,
  'beats': [
    for (final (speaker, line) in lines) {'picture': 'fc-picture', 'speaker': ?speaker, 'line': line},
  ],
};

Map<String, Object?> _way(String id, String from, String to, String label) => {'id': id, 'from': from, 'to': to, 'label': label, 'effects': <Object?>[]};

/// The Red Quiet's First Contact, as P19d, P19e and P19h draw it: no voices; Open hands, the first
/// name on the board and its choice of two, and the second lift's lone way down the service ladder.
/// The table's lone way is the one P19 is for: `Several weeks later` was shown as the only button.
final _firstContact = readStoryJson({
  'format': 'arke-story',
  'version': 1,
  'kind': 'novel',
  'shape': '16:9',
  'start': 'sc_table',
  'fingerprint': 'sha256:${'f' * 64}',
  'facts': <Object?>[],
  'scenes': [
    _scene('sc_table', 'Six places at the table', [(null, 'Six places at the table.')]),
    _scene('sc_hands', 'Open hands', [for (var n = 0; n < 9; n++) n == 5 ? ('Imani Okoro', 'Stop. They are not shooting.') : (null, 'Line $n.')]),
    _scene('sc_shift', 'The last ordinary shift', [(null, 'Several weeks later.')]),
    _scene('sc_shaft', 'The shaft', [(null, 'The shaft.')]),
    _scene('sc_board', 'The first name on the board', [
      (null, 'The board lights.'),
      (null, 'Dev puts his hand on the emergency barrier. Ana waits beside me with the trauma case. The telemetry gives Elsie’s name in full.'),
    ]),
    _scene('sc_lift', 'The second lift', [(null, 'The second lift.')]),
    _scene('sc_sealed', 'The sealed shaft', [(null, 'Sealed.')]),
    _scene('sc_ladder', 'The service ladder', [(null, 'The service ladder.')]),
  ],
  'presentation': <Object?>[],
  'choices': [
    _way('ch_table', 'sc_table', 'sc_hands', 'Sit with them'),
    _way('ch_hands', 'sc_hands', 'sc_shift', 'Open hands'),
    _way('ch_fire', 'sc_hands', 'sc_shift', 'Hold the line'),
    _way('ch_shift', 'sc_shift', 'sc_shaft', 'Go down'),
    _way('ch_stay', 'sc_shift', 'sc_shaft', 'Stay up'),
    _way('ch_shaft', 'sc_shaft', 'sc_board', 'Read the board'),
    _way('ch_wait', 'sc_shaft', 'sc_board', 'Wait'),
    _way('ch_return', 'sc_board', 'sc_lift', 'Return with Ana for Elsie'),
    _way('ch_seal', 'sc_board', 'sc_sealed', 'Seal the shaft and leave Elsie'),
    _way('ch_ladder', 'sc_lift', 'sc_ladder', 'Down the ladder'),
  ],
  'endings': <Object?>[],
});

void main() {
  if (!_shoot) {
    test('shots are taken only with SHOOT=1', () {}, skip: 'set SHOOT=1 to render the screens');
    return;
  }

  setUpAll(_loadFonts);

  const pictures = ['drowned-quarter.jpg', 'maren-ledger-tall.jpg', 'art-direction-illustrated.jpg', 'red-quiet-cover.jpg'];

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
    Future<void> Function(WidgetTester tester)? act,
  }) async {
    await preload(tester);
    final key = GlobalKey();
    await pumpStories(tester, location, stories: stories, size: size, ratio: 2, brightness: brightness, saves: saves, reel: reel, stills: stills, key: key);
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

  LoadedStory lantern(StoryDocument document) => loadedStory(
    storyProduction(lanternId, 'The Lantern Road', document, picture: 'art-direction-illustrated.jpg'),
    document,
    pictures: const {'lr-tall': 'maren-ledger-tall.jpg'},
    fallback: 'art-direction-illustrated.jpg',
  );
  final tall = lantern(_lantern(tall: true));
  final wide = lantern(_lantern(tall: false));
  final firstContact = loadedStory(
    storyProduction('first-contact', 'First Contact', _firstContact, picture: 'red-quiet-cover.jpg'),
    _firstContact,
    fallback: 'red-quiet-cover.jpg',
  );
  final lowWater = readStoryJson(storyJson('low-water.json'));
  final low = loadedStory(storyProduction(lowWaterId, 'Low Water', lowWater, picture: 'drowned-quarter.jpg'), lowWater);
  MemorySaves at(LoadedStory story, List<String> route, StoryPlace place) => MemorySaves({story.key: saveAt(story.document, route, place: place)});
  final contact = Routes.story(worldId, 'first-contact');
  final stills = {for (final scene in _firstContact.scenes.keys) scene: 'red-quiet-cover.jpg'};

  // The controls show as a story opens, and rest after 2.5 s while it plays.
  Future<void> rest(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

  for (final brightness in Brightness.values) {
    final suffix = brightness == Brightness.dark ? '-dark' : '-light';
    testWidgets(
      'P19a playing, its controls resting$suffix',
      (t) => shoot(
        t,
        'p19a$suffix',
        Routes.story(worldId, lanternId),
        stories: [tall],
        brightness: brightness,
        saves: at(tall, const [], const StoryAtBeat(3)),
        act: rest,
      ),
    );
    testWidgets(
      'P19b a tap: the controls, with Narration$suffix',
      (t) => shoot(
        t,
        'p19b$suffix',
        Routes.story(worldId, lanternId),
        stories: [tall],
        brightness: brightness,
        saves: at(tall, const [], const StoryAtBeat(3)),
        act: (tester) async {
          await rest(tester);
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(200, 400));
        },
      ),
    );
    testWidgets(
      'P19c paused, on a wide picture$suffix',
      (t) => shoot(
        t,
        'p19c$suffix',
        Routes.story(worldId, lanternId),
        stories: [wide],
        brightness: brightness,
        saves: at(wide, const [], const StoryAtBeat(1)),
        act: (tester) => tester.tap(find.byType(PlayPause)),
      ),
    );
    testWidgets(
      'P19d a story without voices$suffix',
      (t) => shoot(
        t,
        'p19d$suffix',
        contact,
        stories: [firstContact],
        brightness: brightness,
        saves: at(firstContact, const ['ch_table'], const StoryAtBeat(5)),
        stills: stills,
      ),
    );
    testWidgets(
      'P19e it stops for a choice of two$suffix',
      (t) => shoot(
        t,
        'p19e$suffix',
        contact,
        stories: [firstContact],
        brightness: brightness,
        saves: at(firstContact, const ['ch_table', 'ch_hands', 'ch_shift', 'ch_shaft'], const StoryAtChoice()),
        stills: stills,
      ),
    );
    testWidgets(
      'P19f an interactive movie, a film’s controls$suffix',
      (t) => shoot(
        t,
        'p19f$suffix',
        Routes.story(worldId, lowWaterId),
        stories: [low],
        brightness: brightness,
        saves: at(low, const [], const StoryAt(Duration(seconds: 38))),
      ),
    );
    testWidgets(
      'P19g turned$suffix',
      (t) => shoot(
        t,
        'p19g$suffix',
        Routes.story(worldId, lanternId),
        stories: [wide],
        size: const Size(844, 390),
        brightness: brightness,
        saves: at(wide, const [], const StoryAtBeat(2)),
      ),
    );
    // Where P19 draws no frame: a choice on a Tall picture, where the choices take the transport's place
    // over the box, and turned.
    testWidgets(
      'a choice on a Tall picture$suffix',
      (t) => shoot(
        t,
        'p19-tall-choice$suffix',
        Routes.story(worldId, lanternId),
        stories: [tall],
        brightness: brightness,
        saves: at(tall, const [], const StoryAtChoice()),
      ),
    );
    testWidgets(
      'a choice, turned$suffix',
      (t) => shoot(
        t,
        'p19-turned-choice$suffix',
        Routes.story(worldId, lanternId),
        stories: [wide],
        size: const Size(844, 390),
        brightness: brightness,
        saves: at(wide, const [], const StoryAtChoice()),
      ),
    );
    testWidgets(
      'P19h the route: a lone way leaves no row$suffix',
      (t) => shoot(
        t,
        'p19h$suffix',
        contact,
        stories: [firstContact],
        brightness: brightness,
        saves: at(firstContact, const ['ch_table', 'ch_hands', 'ch_shift', 'ch_shaft', 'ch_return', 'ch_ladder'], const StoryAtBeat(0)),
        stills: stills,
        act: (tester) async {
          await tester.tap(find.byTooltip('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Route'));
        },
      ),
    );
  }
}
