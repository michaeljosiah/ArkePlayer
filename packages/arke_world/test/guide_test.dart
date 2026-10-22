import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
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

  group('a guide alone, fetched and kept (SPEC-059 R-10, R-18, R-22)', () {
    late Directory dir;
    late LibraryStore store;
    late HttpServer server;
    late List<int> bytes;
    var hits = 0;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('arke-guide-fetch-');
      store = LibraryStore(Directory('${dir.path}/library'));
      await store.load();
      bytes = guideAloneZip();
      hits = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        hits++;
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
    });
    tearDown(() async {
      await server.close(force: true);
      await store.close();
      await dir.delete(recursive: true);
    });

    CatalogueWorld world({String? sha}) => CatalogueWorld(
      id: 'undersong',
      name: 'The Undersong',
      productions: const [],
      guide: CataloguePackage(
        url: Uri.parse('http://127.0.0.1:${server.port}/guide.zip'),
        byteLength: bytes.length,
        sha256: sha ?? sha256.convert(bytes).toString(),
      ),
    );
    WorldInstaller installer() => WorldInstaller(store: store, freeBytes: (_) async => null);

    test('is checked, kept under guides/ and read from there', () async {
      final kept = await installer().fetchGuide(world());
      expect(store.guides.single.worldId, 'undersong');
      final folder = store.guideDirectory('undersong').path;
      final manifest = (readWorldManifest(File('$folder/world.json').readAsStringSync()) as WorldManifestOk).manifest;
      final guide = (readGuide(File(store.resolve(kept.guide)).readAsStringSync(), manifest.assets) as GuideOk).guide;
      expect(guide.characters.first.name, 'Maren Kest');
      expect(File('$folder/guide/maren-kest.jpg').existsSync(), isTrue);
    });

    test('is fetched once for its pin', () async {
      await installer().fetchGuide(world());
      await installer().fetchGuide(world());
      expect(hits, 1);
    });

    test('a world installed with its guide names it, and the guide fetched alone gives way', () async {
      await installer().fetchGuide(world());
      final epub = File('${Directory.current.path}/../arke_media/test/fixtures/book.epub').readAsBytesSync();
      final full = guideAloneZip(book: epub);
      final prepared = await installer().prepareFile(size: full.length, open: () => Stream.value(full));
      final installed = await installer().commit(prepared);
      expect(installed.guide, 'worlds/undersong/guide/guide.json');
      expect(File(store.resolve(installed.guide!)).existsSync(), isTrue);
      expect(store.guides, isEmpty);
    });

    test('a guide that is not the one pinned is refused and nothing is kept', () async {
      await expectLater(installer().fetchGuide(world(sha: 'b' * 64)), throwsA(isA<FilesDoNotMatch>()));
      expect(store.guides, isEmpty);
      expect(store.guideDirectory('undersong').existsSync(), isFalse);
    });
  });

  group('the catalogue pins a guide (SPEC-059 R-23)', () {
    test('beside the package, over HTTPS', () {
      String catalogue(String url) => jsonEncode({
        'version': 1,
        'worlds': [
          {
            'id': 'undersong',
            'name': 'The Undersong',
            'productions': const <Object?>[],
            'guide': {'url': url, 'byteLength': 10, 'sha256': 'a' * 64},
          },
        ],
      });
      expect(readCatalogue(catalogue('https://example.org/guide.zip')).single.guide?.byteLength, 10);
      expect(() => readCatalogue(catalogue('http://example.org/guide.zip')), throwsFormatException);
    });
  });

  group('what a reader has reached (SPEC-059 R-20)', () {
    final guide = (readGuide(_read('valid.json'), _assets()) as GuideOk).guide;
    final ledger = guide.productions.single;
    final listening = ListeningDocument(
      title: 'The Ledger of Nights',
      chapters: [
        for (final (id, order, book) in [('neap', 1, 'OEBPS/chapter-1.xhtml'), ('the-rail-book', 2, 'OEBPS/chapter-2.xhtml'), ('independent-record', 6, null)])
          ListeningChapter(id: id, order: order, title: id, duration: const Duration(minutes: 10), audio: 'a', book: book),
      ],
    );
    LibraryItem item(FileFormat format, {Place? place, bool finished = false}) => LibraryItem(
      id: format.name,
      format: format,
      title: 'The Ledger of Nights',
      byteLength: 1,
      addedAt: DateTime.utc(2026, 10, 22),
      file: 'f',
      place: place,
      finished: finished,
    );
    Place heard(String chapter, Duration offset) => Place(locator: chapter, position: offset, progress: 0.2, updatedAt: DateTime.utc(2026, 10, 22));
    Place read(String cfi) => Place(locator: cfi, progress: 0.2, updatedAt: DateTime.utc(2026, 10, 22));
    const spine = ['OEBPS/title.xhtml', 'OEBPS/chapter-1.xhtml', 'OEBPS/chapter-2.xhtml', 'OEBPS/interlude.xhtml'];

    test('a CFI names its document by its first step', () {
      expect(spineIndexOfCfi('epubcfi(/6/4!/4/2/1:0)'), 1);
      expect(spineIndexOfCfi('epubcfi(/6/8[interlude]!/4)'), 3);
      expect(spineIndexOfCfi('not a cfi'), isNull);
      expect(spineIndexOfCfi(null), isNull);
    });

    test('heard: a chapter is reached once its start is passed', () {
      expect(
        reachedIn(
          ledger,
          listening: listening,
          narration: item(FileFormat.listening, place: heard('the-rail-book', Duration.zero)),
        ),
        (at: 2, through: 1),
      );
      expect(
        reachedIn(
          ledger,
          listening: listening,
          narration: item(FileFormat.listening, place: heard('the-rail-book', const Duration(seconds: 1))),
        ),
        (at: 2, through: 2),
      );
      // Numbered as the guide numbers them, so the chapter after 2 is 6.
      expect(
        reachedIn(
          ledger,
          listening: listening,
          narration: item(FileFormat.listening, place: heard('independent-record', const Duration(seconds: 1))),
        ).through,
        6,
      );
    });

    test('read: being in a chapter\'s document is past its start; a page between chapters is in the one before', () {
      expect(
        reachedIn(
          ledger,
          listening: listening,
          book: item(FileFormat.epub, place: read('epubcfi(/6/2!/4)')),
          spine: spine,
        ),
        (at: 0, through: 0),
      );
      expect(
        reachedIn(
          ledger,
          listening: listening,
          book: item(FileFormat.epub, place: read('epubcfi(/6/6!/4)')),
          spine: spine,
        ),
        (at: 2, through: 2),
      );
      expect(
        reachedIn(
          ledger,
          book: item(FileFormat.epub, place: read('epubcfi(/6/8!/4)')),
          spine: spine,
        ).through,
        2,
      );
    });

    test('the further of heard and read counts, and a finished production reaches every chapter', () {
      final reached = reachedIn(
        ledger,
        listening: listening,
        narration: item(FileFormat.listening, place: heard('neap', const Duration(minutes: 3))),
        book: item(FileFormat.epub, place: read('epubcfi(/6/6!/4)')),
        spine: spine,
      );
      expect(reached.through, 2);
      expect(reachedIn(ledger, narration: item(FileFormat.listening, finished: true)).through, reachedAll);
    });

    test('shown when reached or revealed, and nothing else', () {
      final six = (guide.characters.firstWhere((character) => character.id == 'the-chorister')).after;
      final reach = GuideReach(reached: {ledger.id: (at: 3, through: 3)});
      expect(reach.shows(null), isTrue);
      expect(reach.shows(six), isFalse);
      expect(reach.at(ledger.id), 3);
      expect(GuideReach(reached: {ledger.id: (at: 3, through: 3)}, revealed: {ledger.id: 6}).shows(six), isTrue);
      expect(GuideReach.none.shows(six), isFalse);
      expect(GuideReach.none.at(ledger.id), isNull);
    });
  });
}

/// A guide alone as the Studio writes it, over the shared fixtures, every file's digest true; with
/// [book], a full package carrying a book and the guide.
List<int> guideAloneZip({List<int>? book}) {
  final files = <String, List<int>>{
    'the-ledger-of-nights/book.epub': ?book,
    'guide/guide.json': utf8.encode(_read('valid.json')),
    'guide/maren-kest.jpg': [0xFF, 0xD8, 0xFF, 0xD9],
    'guide/bray-half-hitch.png': [0x89, 0x50, 0x4E, 0x47],
    'guide/the-vigil.jpg': [0xFF, 0xD8, 0xFF, 0xDA, 0xFF, 0xD9],
    'guide/maren-kest.m4a': [0, 0, 0, 8, 0x66, 0x74, 0x79, 0x70],
  };
  final world = jsonDecode(_read(book == null ? 'world-guide-alone.json' : 'world-guide-and-book.json')) as Map<String, Object?>;
  final assets = (world['assets']! as Map<String, Object?>)..remove('key-art');
  world.remove('keyArt');
  for (final asset in assets.values.cast<Map<String, Object?>>()) {
    final content = files[asset['path']]!;
    asset['byteLength'] = content.length;
    asset['sha256'] = sha256.convert(content).toString();
  }
  final archive = Archive()..add(ArchiveFile.bytes('world.json', utf8.encode(jsonEncode(world)))..compression = CompressionType.none);
  for (final MapEntry(:key, :value) in files.entries) {
    archive.add(ArchiveFile.bytes(key, value)..compression = CompressionType.none);
  }
  return ZipEncoder().encodeBytes(archive);
}
