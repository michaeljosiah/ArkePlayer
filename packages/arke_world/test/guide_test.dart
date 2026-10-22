import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_world/arke_world.dart';
import 'package:test/test.dart';

// SPEC-059 R-16: these fixtures are the ones ArkeStudio's contracts read too, so both readers agree
// on every verdict and on the chapter each entry waits for.
final _fixtures = '${Directory.current.path}/test/fixtures/guide';

String _read(String name) => File('$_fixtures/$name').readAsStringSync();

Map<String, WorldAsset> _assets() => {
  for (final MapEntry(:key, value: raw) in (jsonDecode(_read('assets.json')) as Map<String, Object?>).entries)
    if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
      key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
};

GuideAfter? _afterOf(Guide guide, String id, int? section) {
  final entry = guide.entry(id)!;
  if (section == null) return entry.after;
  return switch (entry) {
    GuideCharacter(:final sections) || GuidePlace(:final sections) => sections[section].after,
    GuideLore() => throw StateError('lore has no sections'),
  };
}

void main() {
  group('the shared guide cases (SPEC-059 R-9 – R-14, R-16)', () {
    final cases = (jsonDecode(_read('cases.json')) as Map<String, Object?>)['cases']! as List<Object?>;
    for (final raw in cases.cast<Map<String, Object?>>()) {
      final file = raw['file']! as String;
      test(file, () {
        final expected = raw['expect']! as String;
        final (refusal, guide) = raw['reader'] == 'manifest'
            ? switch (readWorldManifest(_read(file))) {
                WorldManifestOk() => (null, null),
                WorldManifestRefused(:final refusal) => (refusal, null),
              }
            : switch (readGuide(_read(file), _assets())) {
                GuideOk(:final guide) => (null, guide),
                GuideRefused(:final refusal) => (refusal, null),
              };
        switch (expected) {
          case 'ok':
            expect(refusal, isNull);
          case 'newerArke':
            expect(refusal, WorldRefusal.newerArke);
          case 'notAPackage':
            expect(refusal, WorldRefusal.notAPackage);
        }
        if (guide == null) return;
        if (raw['counts'] case {'characters': final int characters, 'places': final int places, 'lore': final int lore}) {
          expect((guide.characters.length, guide.places.length, guide.lore.length), (characters, places, lore));
        }
        for (final probe in (raw['after'] as List<Object?>? ?? const []).cast<Map<String, Object?>>()) {
          expect(
            _afterOf(guide, probe['entry']! as String, probe['section'] as int?)?.number,
            probe['number'],
            reason: '${probe['entry']} ${probe['section'] ?? ''}',
          );
        }
      });
    }

    test('a guide alone reads with no productions', () {
      final read = readWorldManifest(_read('world-guide-alone.json'));
      expect(read, isA<WorldManifestOk>());
      final manifest = (read as WorldManifestOk).manifest;
      expect(manifest.guide, 'guide');
      expect(manifest.isGuideAlone, isTrue);
    });

    test('what the valid guide carries', () {
      final guide = (readGuide(_read('valid.json'), _assets()) as GuideOk).guide;
      final maren = guide.characters.first;
      expect(maren.voice?.duration, const Duration(seconds: 8));
      expect(maren.links, ['bray-half-hitch', 'the-vigil']);
      expect(guide.lore.map((lore) => lore.kind), [LoreKind.lore, LoreKind.timeline]);
      expect(guide.productions.single.chapters.first.book, 'OEBPS/chapter-1.xhtml');
      expect(guide.assetIds, {'g-maren', 'g-maren-voice', 'g-bray', 'g-vigil'});
    });
  });

  group('a package carrying its guide (SPEC-059 R-14)', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('arke-guide-'));
    tearDown(() => dir.delete(recursive: true));

    /// A guide alone as the Studio writes it: stored entries, `world.json` first.
    String zip(Map<String, Object?> world, Map<String, List<int>> files) {
      final archive = Archive()..add(ArchiveFile.bytes('world.json', utf8.encode(jsonEncode(world)))..compression = CompressionType.none);
      for (final MapEntry(:key, :value) in files.entries) {
        archive.add(ArchiveFile.bytes(key, value)..compression = CompressionType.none);
      }
      final path = '${dir.path}/guide-alone.zip';
      File(path).writeAsBytesSync(ZipEncoder().encode(archive));
      return path;
    }

    Map<String, List<int>> files(Map<String, Object?> world) => {
      for (final asset in (world['assets']! as Map<String, Object?>).values.cast<Map<String, Object?>>())
        asset['path']! as String: asset['path'] == 'guide/guide.json' ? utf8.encode(_read('valid.json')) : [1],
    };

    test('reads the guide before anything is extracted', () {
      final world = jsonDecode(_read('world-guide-alone.json')) as Map<String, Object?>;
      final manifest = readWorldPackage(zip(world, files(world)));
      expect(manifest.guideDocument?.characters.map((character) => character.name), ['Maren Kest', 'Bray Half-Hitch', 'The Chorister']);
    });

    test('a file the guide does not name: Not an Arke package', () {
      final world = jsonDecode(_read('world-guide-alone.json')) as Map<String, Object?>;
      (world['assets']! as Map<String, Object?>)['g-extra'] = {'path': 'guide/extra.jpg', 'mediaType': 'image/jpeg', 'byteLength': 1, 'sha256': '0' * 64};
      expect(
        () => readWorldPackage(zip(world, files(world))),
        throwsA(isA<WorldPackageRefused>().having((refused) => refused.reason, 'reason', contains('unused'))),
      );
    });

    test('a guide that is not one: refused for what is wrong with it', () {
      final world = jsonDecode(_read('world-guide-alone.json')) as Map<String, Object?>;
      final bytes = files(world)..['guide/guide.json'] = utf8.encode(_read('link-to-nothing.json'));
      expect(
        () => readWorldPackage(zip(world, bytes)),
        throwsA(isA<WorldPackageRefused>().having((refused) => refused.refusal, 'refusal', WorldRefusal.notAPackage)),
      );
    });
  });
}
