import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:test/test.dart';

// SPEC-058 R-86, R-88; SPEC-063 R-12 – R-14: where a person is in a story, kept as a route, replayed
// on the document installed, and given up for `Start again` only when it cannot be replayed.
final _fixtures = '${Directory.current.path}/test/fixtures/story';

String _read(String name) => File('$_fixtures/$name').readAsStringSync();

Map<String, WorldAsset> _assets() => {
  for (final MapEntry(:key, value: raw) in (jsonDecode(_read('assets.json')) as Map<String, Object?>).entries)
    if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
      key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
};

StoryDocument _document(String name, {String Function(String text)? edit}) => switch (readStory((edit ?? (text) => text)(_read(name)), _assets())) {
  StoryOk(:final document) => document,
  StoryRefused(:final reason) => throw StateError('$name: $reason'),
};

void main() {
  final ring = _document('synthetic.json');
  final now = DateTime.utc(2026, 10, 28, 9);

  Map<String, Object?> save(List<String> route, String scene, {StoryPlace place = const StoryAt(Duration(seconds: 3)), String? fingerprint}) =>
      StorySave(route: route, scene: scene, place: place, fingerprint: fingerprint ?? ring.fingerprint, updatedAt: now).toJson();

  group('a save (SPEC-063 R-12)', () {
    test('keeps the route, the scene, the place, its version and the fingerprint, and reads back', () {
      for (final place in const [StoryAt(Duration(milliseconds: 4200)), StoryAtBeat(2), StoryAtChoice()]) {
        final written = save(['ch_light'], 'sc_weigh', place: place);
        expect(written['version'], storySaveVersion);
        expect(written.containsKey('facts'), isFalse, reason: 'what a story remembers follows from the route (P18 call 23)');
        final read = StorySave.read(jsonDecode(jsonEncode(written)))!;
        expect((read.route.join(' '), read.scene, read.fingerprint, read.updatedAt), ('ch_light', 'sc_weigh', ring.fingerprint, now));
        expect(read.place.runtimeType, place.runtimeType);
      }
    });

    test('anything else cannot be read', () {
      final good = save(['ch_light'], 'sc_weigh');
      for (final bad in <Object?>[
        'route',
        {...good, 'version': 2},
        {...good}..remove('version'),
        {...good, 'route': 'ch_light'},
        {
          ...good,
          'route': [1],
        },
        {...good}..remove('scene'),
        {...good, 'at': -1},
        {...good, 'beat': 2},
        {...good}..remove('at'),
        {...good, 'updatedAt': 'yesterday'},
      ]) {
        expect(StorySave.read(bad), isNull, reason: '$bad');
      }
    });
  });

  group('where you are (SPEC-058 R-88)', () {
    test('no save is Play from the start', () => expect(resumeStory(ring, null), isA<StoryFresh>()));

    test('Continue replays the route, at the saved place', () {
      final resumed = resumeStory(ring, save(['ch_light', 'ch_keep'], 'sc_bell')) as StoryContinue;
      expect((resumed.step.scene, resumed.step.route.join(' ')), ('sc_bell', 'ch_light ch_keep'));
      expect((resumed.place as StoryAt).at, const Duration(seconds: 3));
      expect([for (final choice in resumed.step.open) choice.id], contains('ch_key'));
    });

    test('a changed document that still takes the route goes on, from the scene’s start', () {
      final resumed = resumeStory(ring, save(['ch_light', 'ch_keep'], 'sc_bell', fingerprint: 'sha256:${'0' * 64}')) as StoryContinue;
      expect(resumed.step.scene, 'sc_bell');
      expect((resumed.place as StoryAt).at, Duration.zero);
    });

    test('a route an update broke, or one that cannot be read, gives way to Start again', () {
      // ch_drop opens only in the dark: with the lamp lit it is not a step this document takes.
      expect(resumeStory(ring, save(['ch_light', 'ch_drop'], 'sc_bell')), isA<StoryStartAgain>());
      expect(resumeStory(ring, save(['ch_gone'], 'sc_weigh')), isA<StoryStartAgain>());
      expect(resumeStory(ring, save(['ch_light'], 'sc_bell')), isA<StoryStartAgain>(), reason: 'a scene the route does not lead to');
      expect(resumeStory(ring, {'version': 1}), isA<StoryStartAgain>());
      expect(
        resumeStory(ring, {
          ...save(['ch_light'], 'sc_weigh'),
          'version': 2,
        }),
        isA<StoryStartAgain>(),
      );
      // An update that removes the choice the save took.
      final without = _document(
        'synthetic.json',
        edit: (text) {
          final json = jsonDecode(text) as Map<String, Object?>;
          json['choices'] = [
            for (final choice in json['choices']! as List<Object?>)
              if ((choice! as Map)['id'] != 'ch_keep') choice,
          ];
          return jsonEncode(json);
        },
      );
      expect(resumeStory(without, save(['ch_light', 'ch_keep'], 'sc_bell')), isA<StoryStartAgain>());
    });

    test('a beat kept on a movie is no place in it', () {
      final resumed = resumeStory(ring, save(['ch_light'], 'sc_weigh', place: const StoryAtBeat(1))) as StoryContinue;
      expect((resumed.place as StoryAt).at, Duration.zero);
    });
  });

  group('the route (SPEC-058 R-86)', () {
    test('every step along it, the start first', () {
      expect(
        [
          for (final step in storyPath(ring, ['ch_dark', 'ch_leave'])) step.scene,
        ],
        ['sc_harbour', 'sc_weigh', 'sc_bell'],
      );
      expect(storyPath(ring, const []).single.scene, ring.start);
    });

    test('a scene’s length is what it plays', () {
      final step = startStory(ring);
      final clips = ring.scenes[step.scene]!.clips;
      expect(sceneLength(ring, step), step.play.fold(Duration.zero, (Duration sum, index) => sum + clips[index].to - clips[index].from));
      expect(sceneLength(_document('lantern-road.json'), startStory(_document('lantern-road.json'))), Duration.zero);
    });

    test('Choose again at the weigh house takes the key back, and opens the tenth key again', () {
      final route = ['ch_dark', 'ch_leave'];
      final bell = evaluateStory(ring, route);
      expect(bell.closed.map((option) => (option.label, option.reason)), contains(('Use the tenth key', 'Left at the weigh house')));
      final again = chooseStoryAgain(ring, route, 1);
      expect((again.scene, again.route.join(' ')), ('sc_weigh', 'ch_dark'));
      final kept = chooseStory(ring, again, 'ch_keep');
      expect([for (final choice in kept.open) choice.id], contains('ch_key'));
    });
  });
}
