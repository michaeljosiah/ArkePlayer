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
    final cases = (jsonDecode(_read('cases.json')) as Map<String, Object?>)['cases']! as List<Object?>;
    for (final raw in cases.cast<Map<String, Object?>>()) {
      final file = raw['file']! as String;
      test(file, () {
        if (raw['reader'] == 'manifest') {
          final read = readWorldManifest(_read(file));
          _verdict(raw['expect']! as String, read is WorldManifestRefused ? read.refusal : null, read is WorldManifestRefused ? read.reason : null);
          if (read case WorldManifestOk(:final manifest)) {
            expect(manifest.alone, raw['alone'] ?? false);
            if (raw['story'] case final String story) expect(manifest.productions.single.story, story);
          }
          return;
        }
        final read = readStory(_read(file), _assets());
        _verdict(raw['expect']! as String, read is StoryRefused ? read.refusal : null, read is StoryRefused ? read.reason : null);
        if (read case StoryOk(:final document)) {
          if (raw['kind'] case final String kind) expect(document.kind.name, kind);
          if (raw['scenes'] case final int scenes) expect(document.scenes, hasLength(scenes));
          if (raw['choices'] case final int choices) expect(document.choices, hasLength(choices));
        }
      });
    }
  });

  // The point of the slice (R-81): every step of every route the Studio's evaluator walked, walked
  // again here, to the same scene, facts, choices, projection and ending.
  group('every route, as the Studio walks it (SPEC-058 R-81)', () {
    final routeFiles = Directory(_fixtures).listSync().whereType<File>().where((file) => file.path.endsWith('.routes.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('the fixtures hold the public stories', () {
      expect(routeFiles.map((file) => file.uri.pathSegments.last), containsAll(['synthetic.routes.json', 'low-water.routes.json', 'lantern-road.routes.json']));
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

  group('the rules for a player (SPEC-063 R-6, R-11, R-13; SPEC-058 R-86, R-88)', () {
    final document = _document('synthetic.json');

    test('a route is refused at its first step that is not legal, and where it stood is kept', () {
      for (final (route, at) in [
        (['ch_nothing'], 0), // a choice that is not there
        (['ch_keep-key', 'ch_climb'], 1), // not from the scene the route is in
        (['ch_leave-key', 'ch_key'], 1), // its guard fails: the key was left
        (['ch_light', 'ch_light'], 1), // the lamp is lit once
      ]) {
        final broken = replayStory(document, route) as StoryRouteBroken;
        expect((broken.at, broken.choice), (at, route[at]));
        expect(broken.before.route, route.sublist(0, at));
        expect(() => evaluateStory(document, route), throwsA(isA<StoryRouteRefused>()));
      }
    });

    test('a closed choice keeps its place in authored order, with its reason; one without a reason is hidden', () {
      final bell = evaluateStory(document, ['ch_leave-key']);
      expect([for (final option in bell.options) (option.choice.id, option.open)], [('ch_key', false), ('ch_ring', true), ('ch_wait', false)]);
      expect((bell.closed.first.label, bell.closed.first.reason), ('Use the tenth key', 'Left at the weigh house'));
      expect((bell.closed.last.label, bell.closed.last.reason), ('Wait in the dark', 'Too dark to wait'));
      expect(bell.options.any((option) => option.choice.id == 'ch_follow'), isFalse);
    });

    test('Choose again cuts the route before the choice and replays what is kept', () {
      final route = ['ch_leave-key', 'ch_ring', 'ch_climb'];
      final again = chooseStoryAgain(document, route, 0);
      expect((again.scene, again.route.length, again.facts['key']), ('sc_start', 0, 'held'));
      final atBell = chooseStoryAgain(document, ['ch_keep-key', 'ch_ring', 'ch_climb'], 1);
      expect((atBell.scene, atBell.facts['crew']), ('sc_bell', 'whole'));
      expect(atBell.open.map((choice) => choice.id), contains('ch_key'));
      expect(() => chooseStoryAgain(document, route, 3), throwsRangeError);
    });

    test('a saved route replayed on an updated document reports its first step that is no longer legal', () {
      final updated = jsonDecode(_read('synthetic.json')) as Map<String, Object?>;
      (updated['choices']! as List<Object?>).removeWhere((choice) => (choice! as Map<String, Object?>)['id'] == 'ch_ring');
      final next = (readStory(jsonEncode(updated), _assets()) as StoryOk).document;
      final broken = replayStory(next, ['ch_leave-key', 'ch_ring', 'ch_climb']) as StoryRouteBroken;
      expect((broken.at, broken.choice, broken.before.scene), (1, 'ch_ring', 'sc_bell'));
      expect(replayStory(next, ['ch_keep-key', 'ch_key']), isA<StoryReplayed>());
    });

    test('an ending two variants match, or none, is a rule the document breaks', () {
      StoryDocument changed(void Function(List<Object?> variants) change) {
        final json = jsonDecode(_read('synthetic.json')) as Map<String, Object?>;
        final ending = (json['endings']! as List<Object?>).cast<Map<String, Object?>>().singleWhere((ending) => ending['variants'] != null);
        change(ending['variants']! as List<Object?>);
        return (readStory(jsonEncode(json), _assets()) as StoryOk).document;
      }

      // The fallback covers what no variant does, and is not chosen beside one that holds.
      expect(evaluateStory(document, ['ch_leave-key', 'ch_ring', 'ch_climb']).ending?.variant, 'ev_loss');
      expect(evaluateStory(document, ['ch_keep-key', 'ch_wait', 'ch_climb']).ending?.variant, 'ev_all');
      final overlapping = changed((variants) => (variants[1]! as Map<String, Object?>)['when'] = {'op': 'eq', 'fact': 'key', 'value': 'held'});
      expect(() => evaluateStory(overlapping, ['ch_keep-key', 'ch_wait', 'ch_climb']), throwsA(isA<StoryRuleError>()));
      final uncovered = changed((variants) => variants.removeWhere((variant) => (variant! as Map<String, Object?>)['fallback'] == true));
      expect(() => evaluateStory(uncovered, ['ch_leave-key', 'ch_ring', 'ch_climb']), throwsA(isA<StoryRuleError>()));
      expect(evaluateStory(uncovered, ['ch_keep-key', 'ch_ring', 'ch_climb']).ending?.variant, 'ev_key');
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

    // The world.json fixture with every asset the synthetic story names in its inventory.
    (Map<String, Object?>, Map<String, List<int>>) world(String storyText) {
      final world = jsonDecode(_read('world-story.json')) as Map<String, Object?>;
      final all = _assets();
      final named = {...(world['assets']! as Map<String, Object?>).keys, ..._document('synthetic.json').assetIds};
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
      expect(read.stories[production.id]!.scenes, hasLength(5));
    });

    test('a clip nothing names is refused', () {
      final (manifest, files) = world(_read('low-water.json'));
      expect(() => readWorldPackage(pack(manifest, files)), throwsA(isA<WorldPackageRefused>()));
    });

    test('a story document that is not one refuses the package', () {
      final (manifest, files) = world(_read('guard-undeclared-fact.json'));
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

    test('it is never the production’s package: nothing installs it as one', () {
      final listed = parseCatalogue(list(serial: 1, story: {...pin, 'version': 1})).worlds.single;
      expect(listed.productions.single.package, isNull);
      final installed = LibraryWorld(
        id: 'the-undersong',
        edition: '2026-10-22',
        name: 'The Undersong',
        byteLength: 1,
        installedAt: DateTime.utc(2026, 10, 28),
        productions: const [],
      );
      expect(missingProductions(listed, installed), isEmpty);
      expect(productionUpdates(listed, installed), isEmpty);
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
