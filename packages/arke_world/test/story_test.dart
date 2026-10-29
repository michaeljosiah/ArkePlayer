import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

// SPEC-058 R-79 – R-82: these fixtures are the ones ArkeStudio's contracts write and read, so both
// readers agree on every verdict, and both evaluators on every step of every route (R-81). A change to
// either evaluator lands with regenerated fixtures, or not at all.
final _fixtures = '${Directory.current.path}/test/fixtures/story';

String _read(String name) => File('$_fixtures/$name').readAsStringSync();

Map<String, WorldAsset> _assets() => {
  for (final MapEntry(:key, value: raw) in (jsonDecode(_read('assets.json')) as Map<String, Object?>).entries)
    if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
      key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
};

StoryDocument _document(String name) => switch (readStory(_read(name), _assets())) {
  StoryOk(:final document) => document,
  StoryRefused(:final reason) => throw StateError('$name: $reason'),
};

/// Every complete route through [document], each a list of choice ids, taking open choices in
/// authored order: what the Studio's fixtures list when they say they are complete. A route ends at an
/// ending; a scene that is no ending and offers nothing is a dead end the Studio's export refuses.
List<List<String>> _completeRoutes(StoryDocument document, {int limit = 100000}) {
  final routes = <List<String>>[];
  void walk(StoryStep step) {
    if (routes.length > limit) throw StateError('more than $limit routes');
    if (step.ending != null) {
      routes.add(step.route);
      return;
    }
    if (step.open.isEmpty) throw StateError('${step.route.join(' → ')} stops at ${step.scene}, which is no ending');
    for (final choice in step.open) {
      walk(chooseStory(document, step, choice.id));
    }
  }

  walk(startStory(document));
  return routes;
}

Map<String, Object?> _stepJson(StoryStep step) => {
  'scene': step.scene,
  'facts': step.facts,
  'open': [for (final choice in step.open) choice.id],
  'closed': [
    for (final option in step.closed) {'id': option.choice.id, 'label': option.label, 'reason': option.reason},
  ],
  'play': step.play,
};

Map<String, Object?>? _endingJson(StoryEndingResolved? ending) =>
    ending == null ? null : {'scene': ending.scene, 'variant': ending.variant, 'title': ending.title, 'text': ending.text};

void main() {
  group('the shared story cases (SPEC-058 R-79, R-80)', () {
    final shared = jsonDecode(_read('cases.json')) as Map<String, Object?>;
    final cases = shared['cases']! as List<Object?>;

    // The bounds every reader keeps, as contracts writes them beside the cases.
    test('the same bounds', () {
      final limits = shared['limits']! as Map<String, Object?>;
      expect(
        {
          'facts': limits['facts'],
          'values': limits['values'],
          'effects': limits['effects'],
          'conditionDepth': limits['conditionDepth'],
          'conditionNodes': limits['conditionNodes'],
          'scenes': limits['scenes'],
          'items': limits['items'],
          'choices': limits['choices'],
          'presentation': limits['presentation'],
          'endings': limits['endings'],
          'variants': limits['variants'],
        },
        {
          'facts': maxStoryFacts,
          'values': maxStoryFactValues,
          'effects': maxStoryEffects,
          'conditionDepth': maxStoryConditionDepth,
          'conditionNodes': maxStoryConditionNodes,
          'scenes': maxStoryScenes,
          'items': maxStorySceneItems,
          'choices': maxStoryChoices,
          'presentation': maxStoryPresentation,
          'endings': maxStoryEndings,
          'variants': maxStoryVariants,
        },
      );
      expect(limits['text'], {
        'sceneId': maxStoryIdLength,
        'choiceId': maxStoryIdLength,
        'factId': maxStoryFactLength,
        'value': maxStoryFactLength,
        'variantId': maxStoryVariantIdLength,
        'sceneTitle': maxStorySceneTitleLength,
        'label': maxStoryLabelLength,
        'closedLabel': maxStoryClosedLabelLength,
        'reason': maxStoryReasonLength,
        'endingTitle': maxStoryEndingTitleLength,
        'variantText': maxStoryTextLength,
        'speaker': maxStorySpeakerLength,
        'line': maxStoryTextLength,
      });
    });

    for (final raw in cases.cast<Map<String, Object?>>()) {
      final file = raw['file']! as String;
      test(file, () {
        if (raw['reader'] == 'manifest') {
          final read = readWorldManifest(_read(file));
          _verdict(raw['expect']! as String, read is WorldManifestRefused ? read.refusal : null, read is WorldManifestRefused ? read.reason : null);
          if (read case WorldManifestOk(:final manifest)) {
            expect(manifest.alone, raw['alone'] ?? false);
            expect(manifest.productions.single.story, raw['story']);
            expect(manifest.productions.single.tall, raw['tall']);
          }
          return;
        }
        final read = readStory(_read(file), _assets());
        _verdict(raw['expect']! as String, read is StoryRefused ? read.refusal : null, read is StoryRefused ? read.reason : null);
        if (read case StoryOk(:final document)) {
          if (raw['kind'] case final String kind) expect(document.kind.name, kind);
          if (raw['shape'] case final String shape) expect(document.shape.label, shape);
          if (raw['start'] case final String start) expect(document.start, start);
          if (raw['facts'] case final List<Object?> facts) expect(document.facts.map((fact) => fact.id), facts);
          if (raw['scenes'] case final List<Object?> scenes) expect(document.scenes.keys, scenes);
          if (raw['choices'] case final List<Object?> choices) expect(document.choices.map((choice) => choice.id), choices);
          if (raw['routes'] case final String routes) expect((jsonDecode(_read(routes)) as Map<String, Object?>)['document'], file);
        }
      });
    }
  });

  // The point of the slice (R-81): every step of every route the Studio's evaluator walked, walked
  // again here, to the same scene, facts, choices, projection and ending.
  group('every route, as the Studio walks it (SPEC-058 R-81)', () {
    final routeFiles = Directory(_fixtures).listSync().whereType<File>().where((file) => file.path.endsWith('.routes.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('the fixtures hold the public stories, and every route file a case names', () {
      final names = routeFiles.map((file) => file.uri.pathSegments.last).toSet();
      expect(names, containsAll(['synthetic.routes.json', 'low-water.routes.json', 'lantern-road.routes.json']));
      final cases = (jsonDecode(_read('cases.json')) as Map<String, Object?>)['cases']! as List<Object?>;
      expect({for (final raw in cases.cast<Map<String, Object?>>()) ?raw['routes']}, names);
    });

    for (final file in routeFiles) {
      final name = file.uri.pathSegments.last;
      final fixture = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final document = _document(fixture['document']! as String);
      final routes = (fixture['routes']! as List<Object?>).cast<Map<String, Object?>>();

      test('$name: every step of its ${routes.length} routes', () {
        expect(routes, isNotEmpty);
        for (final (number, route) in routes.indexed) {
          final choices = (route['choices']! as List<Object?>).cast<String>();
          final steps = (route['steps']! as List<Object?>).cast<Map<String, Object?>>();
          expect(steps, hasLength(choices.length + 1), reason: 'route ${number + 1}: a step for each scene arrived at');
          for (var k = 0; k <= choices.length; k++) {
            final step = evaluateStory(document, choices.sublist(0, k));
            expect(_stepJson(step), steps[k], reason: 'route ${number + 1} ${choices.take(k).join(' → ')}');
            if (k < choices.length) expect(step.ending, isNull, reason: 'route ${number + 1}: no ending before its end');
          }
          if (route.containsKey('ending')) {
            expect(_endingJson(evaluateStory(document, choices).ending), route['ending'], reason: 'route ${number + 1} ending');
          }
        }
      });

      if (fixture['complete'] == true) {
        test('$name: its routes are every complete route through it', () {
          final ours = [for (final route in _completeRoutes(document)) route.join(' ')];
          final theirs = [for (final route in routes) (route['choices']! as List<Object?>).join(' ')];
          expect(ours.toSet(), theirs.toSet());
          expect(theirs, hasLength(theirs.toSet().length), reason: 'no route twice');
          expect(routes.every((route) => route['ending'] != null), isTrue, reason: 'a complete route ends');
        });
      } else {
        // A loop is legitimate (SPEC-063 R-6), so a walk may stop at a bound: a route that reaches its
        // `choices` without ending is kept unended, and the walk stops at `routes` routes.
        test('$name: its routes are within its bound', () {
          final bound = fixture['bound']! as Map<String, Object?>;
          final (choices, count) = (bound['choices']! as int, bound['routes']! as int);
          expect(routes.length, lessThanOrEqualTo(count));
          for (final route in routes) {
            final length = (route['choices']! as List<Object?>).length;
            expect(length, lessThanOrEqualTo(choices));
            if (route['ending'] == null) expect(length, choices, reason: 'only the bound leaves a route unended');
          }
        });
      }
    }
  });

  // On the synthetic story, Ring Once: the lamp is lit or not at the harbour, the key kept, left or
  // dropped at the weigh house, and at the bell the tenth key and the signal close with their reasons.
  group('the rules for a player (SPEC-063 R-6, R-11, R-13; SPEC-058 R-86, R-88)', () {
    final document = _document('synthetic.json');

    test('a route is refused at its first step that is not legal, and where it stood is kept', () {
      for (final (route, at) in [
        (['ch_nothing'], 0), // a choice that is not there
        (['ch_light', 'ch_ring'], 1), // not from the scene the route is in
        (['ch_light', 'ch_drop'], 1), // its guard fails: the lamp is lit
        (['ch_dark', 'ch_leave', 'ch_key'], 2), // and here the key was left
        (['ch_dark', 'ch_drop', 'ch_swim', 'ch_ring'], 3), // nothing after an ending
      ]) {
        final broken = replayStory(document, route) as StoryRouteBroken;
        expect((broken.at, broken.choice), (at, route[at]));
        expect(broken.before.route, route.sublist(0, at));
        expect(() => evaluateStory(document, route), throwsA(isA<StoryRouteRefused>()));
      }
    });

    test('a closed choice keeps its place in authored order, with its reason; one without a reason is hidden', () {
      final dark = evaluateStory(document, ['ch_dark', 'ch_leave']);
      expect(
        [for (final option in dark.options) (option.choice.id, option.open)],
        [('ch_ring', true), ('ch_key', false), ('ch_signal', false), ('ch_wait', true), ('ch_swim', true)],
      );
      expect(
        [for (final option in dark.closed) (option.label, option.reason)],
        [('Use the tenth key', 'Left at the weigh house'), ('Signal the boats', 'No light to signal with')],
      );
      // With the lamp lit and the key kept, the swim's guard fails and it has no reason: it is hidden.
      final lit = evaluateStory(document, ['ch_light', 'ch_keep']);
      expect(lit.open.map((choice) => choice.id), ['ch_ring', 'ch_key', 'ch_signal', 'ch_wait']);
      expect(lit.closed, isEmpty);
      expect(lit.play, [0, 1, 2]);
    });

    test('Choose again cuts the route before the choice and replays what is kept', () {
      final route = ['ch_light', 'ch_keep', 'ch_key', 'ch_take'];
      expect(evaluateStory(document, route).facts, {'key': 'lost', 'lamp': true, 'ledger': true});
      final vault = chooseStoryAgain(document, route, 3);
      expect((vault.scene, vault.facts['key'], vault.facts['ledger']), ('sc_vault', 'held', false));
      expect(vault.open.map((choice) => choice.id), ['ch_take', 'ch_seal']);
      final weigh = chooseStoryAgain(document, route, 1);
      expect((weigh.scene, weigh.route.length, weigh.facts['lamp']), ('sc_weigh', 1, true));
      final harbour = chooseStoryAgain(document, route, 0);
      expect((harbour.scene, harbour.facts['lamp']), ('sc_harbour', false));
      expect(() => chooseStoryAgain(document, route, 4), throwsRangeError);
    });

    test('a saved route replayed on an updated document reports its first step that is no longer legal', () {
      final updated = jsonDecode(_read('synthetic.json')) as Map<String, Object?>;
      (updated['choices']! as List<Object?>).removeWhere((choice) => (choice! as Map<String, Object?>)['id'] == 'ch_key');
      final next = (readStory(jsonEncode(updated), _assets()) as StoryOk).document;
      final broken = replayStory(next, ['ch_light', 'ch_keep', 'ch_key', 'ch_take']) as StoryRouteBroken;
      expect((broken.at, broken.choice, broken.before.scene), (2, 'ch_key', 'sc_bell'));
      expect(replayStory(next, ['ch_dark', 'ch_keep', 'ch_wait']), isA<StoryReplayed>());
    });

    test('an ending resolves to the one variant that holds, else its fallback; two, or none, break its rule', () {
      StoryDocument changed(void Function(List<Object?> variants) change) {
        final json = jsonDecode(_read('synthetic.json')) as Map<String, Object?>;
        final ending = (json['endings']! as List<Object?>).cast<Map<String, Object?>>().singleWhere((ending) => ending['variants'] != null);
        change(ending['variants']! as List<Object?>);
        return (readStory(jsonEncode(json), _assets()) as StoryOk).document;
      }

      final boats = evaluateStory(document, ['ch_light', 'ch_keep', 'ch_ring']).ending!;
      expect((boats.scene, boats.variant, boats.title, boats.text), ('sc_end', 'ev_boats', 'The boats come in', 'The lamp brings them home.'));
      expect(evaluateStory(document, ['ch_dark', 'ch_keep', 'ch_ring']).ending?.variant, 'ev_twice');
      // An ending with no variants is its title.
      final drowned = evaluateStory(document, ['ch_dark', 'ch_drop', 'ch_swim']).ending!;
      expect((drowned.variant, drowned.title, drowned.text), (null, 'Under the harbour', null));
      expect(evaluateStory(document, ['ch_light', 'ch_keep']).ending, isNull);

      final overlapping = changed((variants) => (variants[0]! as Map<String, Object?>)['when'] = {'op': 'eq', 'fact': 'key', 'value': 'held'});
      expect(() => evaluateStory(overlapping, ['ch_light', 'ch_keep', 'ch_ring']), throwsA(isA<StoryRuleError>()));
      final uncovered = changed((variants) => variants.removeWhere((variant) => (variant! as Map<String, Object?>)['fallback'] == true));
      expect(() => evaluateStory(uncovered, ['ch_dark', 'ch_keep', 'ch_ring']), throwsA(isA<StoryRuleError>()));
      expect(evaluateStory(uncovered, ['ch_light', 'ch_keep', 'ch_ring']).ending?.variant, 'ev_boats');
    });
  });

  // P19 rules 3 and 4, presentation over the rules above: a choice is two or more, a closed choice
  // shown with its reason counting as one, and a lone way on is taken without stopping, yet stays a
  // step of the route. The fixtures are unchanged: they pin the rules, not this.
  group('a lone way (P19 rules 3, 4)', () {
    final low = _document('low-water.json');
    final lantern = _document('lantern-road.json');
    final ring = _document('synthetic.json');

    test('is the one open choice where no closed one shows; a choice of two, an ending or nothing open has none', () {
      // Low Water's vigil has one way on, the climb; its quarter and causeway have two.
      expect(evaluateStory(low, ['ch_follow', 'ch_wait']).loneWay?.id, 'ch_climb');
      expect(startStory(low).loneWay, isNull);
      expect(evaluateStory(low, ['ch_follow']).loneWay, isNull);
      expect(evaluateStory(low, ['ch_stay', 'ch_ring']).loneWay, isNull, reason: 'an ending');
      // The Lantern Road's bridge has one; its road without a lantern has one open and one closed
      // with its reason, which counts as a choice of two.
      expect(evaluateStory(lantern, ['ch_buy', 'ch_bridge']).loneWay?.id, 'ch_cross');
      final dark = evaluateStory(lantern, ['ch_walk']);
      expect((dark.open.length, dark.closed.length, dark.loneWay), (1, 1, null));
      // A closed choice with no reason is hidden, and does not count: Ring Once's weigh house without
      // its Keep the key, with the lamp lit, offers only Leave the key, since Drop it is closed.
      final json = jsonDecode(_read('synthetic.json')) as Map<String, Object?>;
      (json['choices']! as List<Object?>).removeWhere((choice) => (choice! as Map<String, Object?>)['id'] == 'ch_keep');
      final keyless = (readStory(jsonEncode(json), _assets()) as StoryOk).document;
      final weigh = evaluateStory(keyless, ['ch_light']);
      expect((weigh.options.length, weigh.loneWay?.id), (1, 'ch_leave'));
      expect(evaluateStory(keyless, ['ch_dark']).loneWay, isNull, reason: 'in the dark Drop it opens too');
      expect(evaluateStory(ring, ['ch_dark', 'ch_leave']).loneWay, isNull);
    });

    test('is taken to where something plays, a choice of two or an end; each is a step of the route, with its effects', () {
      final vigil = evaluateStory(low, ['ch_follow', 'ch_wait']);
      final pier = takeLoneWays(low, vigil);
      expect((pier.scene, pier.route.join(' ')), ('sc_pier', 'ch_follow ch_wait ch_climb'));
      expect(pier.ending?.title, 'The harbour, level');
      final bridge = evaluateStory(lantern, ['ch_buy', 'ch_bridge']);
      final home = takeLoneWays(lantern, bridge);
      expect((home.scene, home.route.last, home.facts['lantern']), ('sc_home', 'ch_cross', true));
      // A route that took it replays, as any route does.
      expect(evaluateStory(lantern, home.route).scene, 'sc_home');
      // Where there is a choice of two, nothing is taken.
      final quarter = startStory(low);
      expect(takeLoneWays(low, quarter), same(quarter));
    });

    // The harbour's lone way into a pier that plays nothing until it has been seen, the pier's on into
    // the causeway, which plays, and there a choice of two. With [loop], the harbour's lone way leads
    // instead into two scenes that play nothing, each the other's only way on.
    StoryDocument lone({bool loop = false}) {
      Map<String, Object?> scene(String id, String asset) => {
        'id': id,
        'title': id,
        'clips': [
          {'asset': asset, 'from': 0, 'to': 1000},
        ],
      };
      Map<String, Object?> way(String id, String from, String to, {List<Object?> effects = const []}) => {
        'id': id,
        'from': from,
        'to': to,
        'label': id,
        'effects': effects,
      };
      final unseen = {'op': 'eq', 'fact': 'seen', 'value': true};
      final json = {
        'format': 'arke-story',
        'version': 1,
        'kind': 'movie',
        'shape': '16:9',
        'start': 'sc_harbour',
        'fingerprint': 'sha256:${'e' * 64}',
        'facts': [
          {'id': 'seen', 'type': 'boolean', 'default': false},
          {'id': 'passed', 'type': 'boolean', 'default': false},
        ],
        'scenes': [
          scene('sc_harbour', 'lw-quarter'),
          scene('sc_pier', 'lw-causeway'),
          scene('sc_causeway', 'lw-towers'),
          scene('sc_left', 'lw-vigil'),
          scene('sc_right', 'lw-pier'),
          scene('sc_round-1', 'lw-bell'),
          scene('sc_round-2', 'lw-bell'),
        ],
        'presentation': [
          for (final id in ['sc_pier', 'sc_round-1', 'sc_round-2']) {'scene': id, 'index': 0, 'when': unseen},
        ],
        'choices': [
          if (loop)
            way('ch_round', 'sc_harbour', 'sc_round-1')
          else
            way(
              'ch_pier',
              'sc_harbour',
              'sc_pier',
              effects: [
                {'fact': 'passed', 'value': true},
              ],
            ),
          way('ch_causeway', 'sc_pier', 'sc_causeway'),
          way('ch_left', 'sc_causeway', 'sc_left'),
          way('ch_right', 'sc_causeway', 'sc_right'),
          way('ch_back', 'sc_round-1', 'sc_round-2'),
          way('ch_again', 'sc_round-2', 'sc_round-1'),
        ],
        'endings': [
          {'scene': 'sc_left', 'title': 'Left'},
          {'scene': 'sc_right', 'title': 'Right'},
        ],
      };
      return (readStory(jsonEncode(json), _assets()) as StoryOk).document;
    }

    test('goes on through a scene that plays nothing, and stops at the first that plays', () {
      final document = lone();
      final harbour = startStory(document);
      final causeway = takeLoneWays(document, harbour);
      expect((causeway.scene, causeway.route.join(' '), causeway.facts['passed']), ('sc_causeway', 'ch_pier ch_causeway', true));
      expect(causeway.loneWay, isNull);
      expect(storyChoicesMade(storyPath(document, [...causeway.route, 'ch_left'])), [2], reason: 'only the choice of two was chosen');
    });

    test('round a loop of scenes that play nothing, gives up at a lone way after as many steps as a story has scenes', () {
      final document = lone(loop: true);
      final stuck = takeLoneWays(document, startStory(document));
      expect(stuck.route, hasLength(maxStoryScenes));
      expect(stuck.play, isEmpty);
      expect(stuck.loneWay, isNotNull);
    });

    test('a route’s choices made leave out its lone ways', () {
      expect(storyChoicesMade(storyPath(low, ['ch_follow', 'ch_wait', 'ch_climb'])), [0, 1]);
      expect(storyChoicesMade(storyPath(lantern, ['ch_buy', 'ch_bridge', 'ch_cross'])), [0, 1]);
      expect(storyChoicesMade(storyPath(ring, ['ch_light', 'ch_keep', 'ch_ring'])), [0, 1, 2]);
      expect(storyChoicesMade(storyPath(low, const [])), isEmpty);
    });
  });

  group('a story package on disk (SPEC-058 R-79, R-80)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('story-package-'));
    tearDown(() => dir.deleteSync(recursive: true));

    // Packs world.json and the given files, stored, as the Studio writes a package.
    String pack(Map<String, Object?> world, Map<String, List<int>> files) {
      final assets = <String, Object?>{};
      for (final MapEntry(:key, :value) in (world['assets']! as Map<String, Object?>).entries) {
        final path = (value! as Map<String, Object?>)['path']! as String;
        final bytes = files[path]!;
        assets[key] = {...value as Map<String, Object?>, 'byteLength': bytes.length, 'sha256': sha256.convert(bytes).toString()};
      }
      final archive = Archive()
        ..add(ArchiveFile.bytes(worldManifestFile, utf8.encode(jsonEncode({...world, 'assets': assets})))..compression = CompressionType.none);
      for (final MapEntry(:key, :value) in files.entries) {
        archive.add(ArchiveFile.bytes(key, value)..compression = CompressionType.none);
      }
      final zip = '${dir.path}/story.zip';
      File(zip).writeAsBytesSync(ZipEncoder().encode(archive));
      return zip;
    }

    // The world.json fixture, which holds the synthetic story and every file it names, and [extra].
    (Map<String, Object?>, Map<String, List<int>>) world(String storyText, {Set<String> extra = const {}}) {
      final world = jsonDecode(_read('world-story.json')) as Map<String, Object?>;
      final all = _assets();
      final named = {...(world['assets']! as Map<String, Object?>).keys, ...extra};
      world['assets'] = {for (final id in named) id: all[id]!.toJson()};
      return (
        world,
        {
          for (final id in named)
            all[id]!.path: id == (world['productions']! as List<Object?>).cast<Map<String, Object?>>().single['story']
                ? utf8.encode(storyText)
                : [id.length, 1, 2],
        },
      );
    }

    test('reads its story document, and every file it names is used', () {
      final (manifest, files) = world(_read('synthetic.json'));
      final read = readWorldPackage(pack(manifest, files));
      expect((read.alone, read.schemaVersion), (true, 6));
      final production = read.productions.single;
      expect((production.story, production.tall), ('story', 'cover-tall'));
      expect(read.stories[production.id]!.scenes, hasLength(6));
      expect(read.stories[production.id]!.assetIds, {for (final id in read.assets.keys) id}.difference({'story', 'cover', 'cover-tall'}));
    });

    test('a clip nothing names is refused', () {
      final (manifest, files) = world(_read('synthetic.json'), extra: {'lw-quarter'});
      expect(() => readWorldPackage(pack(manifest, files)), throwsA(isA<WorldPackageRefused>()));
    });

    test('a story document that is not one refuses the package', () {
      final (manifest, files) = world(_read('when-unknown-fact.json'));
      expect(
        () => readWorldPackage(pack(manifest, files)),
        throwsA(isA<WorldPackageRefused>().having((refused) => refused.refusal, 'refusal', WorldRefusal.notAPackage)),
      );
    });

    test('pin_world prints it as the production’s story, with its version, never as its package', () async {
      final (manifest, files) = world(_read('synthetic.json'));
      final zip = pack(manifest, files);
      final run = await Process.run(Platform.resolvedExecutable, ['run', 'bin/pin_world.dart', zip, 'https://example.org/low-water.zip', '--production']);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      final printed = (jsonDecode(run.stdout as String) as Map<String, Object?>)['production']! as Map<String, Object?>;
      expect(printed.keys, unorderedEquals(['id', 'story']));
      final story = printed['story']! as Map<String, Object?>;
      expect((story['url'], story['version'], story['edition']), ('https://example.org/low-water.zip', 1, '2026-10-28'));
      expect(story['fingerprint'], editionFingerprint(readWorldPackage(zip)));
      // And the list reads what it printed as a story this Player plays.
      final listed = parseCatalogue(
        jsonEncode({
          'version': 2,
          'serial': 1,
          'worlds': [
            {
              'id': 'the-undersong',
              'name': 'The Undersong',
              'productions': [
                {'id': 'low-water', 'title': 'Low Water', 'kind': 'Interactive · 16:9', 'story': story},
              ],
            },
          ],
        }),
      ).worlds.single.productions.single;
      expect((listed.story?.playable, listed.package), (true, null));
    });
  });

  // SPEC-058 R-82: a story is listed under its own key, with the version of its document.
  group('a production’s story in Arke’s list', () {
    final pin = {'url': 'https://example.org/low-water.zip', 'byteLength': 9, 'sha256': 'b' * 64, 'edition': '2026-10-28', 'fingerprint': 'c' * 64};
    String list({required int serial, Object? story, Object? package}) => jsonEncode({
      'version': 2,
      'serial': serial,
      'worlds': [
        {
          'id': 'the-undersong',
          'name': 'The Undersong',
          'package': {'url': 'https://example.org/undersong.zip', 'byteLength': 10, 'sha256': 'a' * 64},
          'productions': [
            {'id': 'low-water', 'title': 'Low Water', 'kind': 'Interactive · 16:9', 'story': ?story, 'package': ?package},
          ],
        },
      ],
    });

    test('reads the pin and its version, and whether this Player plays it', () {
      final story = parseCatalogue(list(serial: 1, story: {...pin, 'version': 1})).worlds.single.productions.single.story!;
      expect((story.url.host, story.edition, story.fingerprint, story.version, story.playable), ('example.org', '2026-10-28', 'c' * 64, 1, true));
      final later = parseCatalogue(list(serial: 1, story: {...pin, 'version': 2})).worlds.single.productions.single.story!;
      expect((later.version, later.playable), (2, false));
      expect(supportedStoryVersions, {1});
    });

    test('a story without its version or fingerprint, or over HTTP, is not a list', () {
      expect(() => parseCatalogue(list(serial: 1, story: pin)), throwsFormatException);
      expect(() => parseCatalogue(list(serial: 1, story: {...pin, 'version': 0})), throwsFormatException);
      expect(() => parseCatalogue(list(serial: 1, story: {...pin, 'version': '1'})), throwsFormatException);
      expect(() => parseCatalogue(list(serial: 1, story: {...pin, 'version': 1}..remove('fingerprint'))), throwsFormatException);
      expect(() => parseCatalogue(list(serial: 1, story: {...pin, 'version': 1, 'url': 'http://example.org/low-water.zip'})), throwsFormatException);
    });

    // A revision 11 Player installs every `package` it reads, so a story is never one. This Player
    // installs it under its own key, and only in a version it plays (R-83).
    test('it is never the production’s package; it is installed as its story, when this Player plays it', () {
      final installed = LibraryWorld(
        id: 'the-undersong',
        edition: '2026-10-22',
        name: 'The Undersong',
        byteLength: 1,
        installedAt: DateTime.utc(2026, 10, 28),
        productions: const [],
      );
      final listed = parseCatalogue(list(serial: 1, story: {...pin, 'version': 1})).worlds.single;
      expect(listed.productions.single.package, isNull);
      expect(listed.productions.single.alone, same(listed.productions.single.story));
      expect(missingProductions(listed, installed).single.id, 'low-water');
      final later = parseCatalogue(list(serial: 1, story: {...pin, 'version': 2})).worlds.single;
      expect((later.productions.single.alone, later.productions.single.needsNewerApp), (null, true));
      expect(missingProductions(later, installed), isEmpty);
      expect(productionUpdates(later, installed), isEmpty);
    });

    test('a production package beside it reads as before', () {
      final production = parseCatalogue(list(serial: 1, package: pin)).worlds.single.productions.single;
      expect((production.package?.fingerprint, production.story), ('c' * 64, null));
    });

    test('it is the newer list’s, as a pin is an address', () {
      final shipped = parseCatalogue(list(serial: 1));
      final production = newestCatalogue(shipped, parseCatalogue(list(serial: 2, story: {...pin, 'version': 1}))).worlds.single.productions.single;
      expect(production.story?.sha256, 'b' * 64);
    });
  });
}

void _verdict(String expected, WorldRefusal? refusal, String? reason) {
  switch (expected) {
    case 'ok':
      expect(refusal, isNull, reason: reason);
    case 'newerArke':
      expect(refusal, WorldRefusal.newerArke, reason: reason);
    case 'notAPackage':
      expect(refusal, WorldRefusal.notAPackage, reason: reason);
    default:
      fail('unknown expectation $expected');
  }
}
