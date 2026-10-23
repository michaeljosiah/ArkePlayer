import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:test/test.dart';

// SPEC-058 R-16: these fixtures are the ones ArkeStudio's contracts read too, so both readers
// agree on every verdict and on which picture and phrase show when.
final _fixtures = '${Directory.current.path}/test/fixtures/listening';
final _media = '${Directory.current.path}/../arke_media/test/fixtures';

Map<String, WorldAsset> _assets() => {
  for (final MapEntry(:key, value: raw) in (jsonDecode(File('$_fixtures/assets.json').readAsStringSync()) as Map<String, Object?>).entries)
    if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
      key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
};

/// A listening world over real media: two chapters whose audio is arke_media's M4B, pictures of a
/// few bytes (nothing reads their pixels), and the book.
Future<WorldSpec> _spec(Directory dir, {String edition = '2026-10-21'}) async {
  for (final name in ['ch1.m4a', 'ch2.m4a']) {
    await File('$_media/chapters.m4b').copy('${dir.path}/$name');
  }
  for (final name in ['art.jpg', 'p1.jpg', 'p2.jpg']) {
    await File('${dir.path}/$name').writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, name.length, 0xFF, 0xD9]);
  }
  return WorldSpec(
    id: 'undersong',
    edition: edition,
    name: 'The Undersong',
    keyArt: '${dir.path}/art.jpg',
    productions: [
      ProductionSpec(
        id: 'ledger-of-nights',
        title: 'The Ledger of Nights',
        book: '$_media/book.epub',
        listening: {
          'title': 'The Ledger of Nights',
          'chapters': [
            {
              'id': 'neap',
              'title': 'Neap',
              'audio': '${dir.path}/ch1.m4a',
              'book': 'OEBPS/chapter-1.xhtml',
              'pictures': [
                {
                  'at': 0,
                  'picture': '${dir.path}/p1.jpg',
                  'focus': {'x': 0.4, 'y': 0.3},
                },
                {'at': 2000, 'picture': '${dir.path}/p2.jpg'},
              ],
              'phrases': [
                {'at': 100, 'end': 1500, 'text': 'The tide-clock keeps the drowned god’s hours.'},
              ],
            },
            {
              'id': 'the-rail-book',
              'title': 'The rail book',
              'audio': '${dir.path}/ch2.m4a',
              // The same picture twice ships once.
              'pictures': [
                {'at': 0, 'picture': '${dir.path}/p1.jpg'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

void main() {
  group('the shared cases (SPEC-058 R-13, R-15, R-16)', () {
    final cases = (jsonDecode(File('$_fixtures/cases.json').readAsStringSync()) as Map<String, Object?>)['cases']! as List<Object?>;
    for (final raw in cases.cast<Map<String, Object?>>()) {
      final file = raw['file']! as String;
      test(file, () {
        final read = readListening(File('$_fixtures/$file').readAsStringSync(), _assets());
        switch (raw['expect']) {
          case 'ok':
            final document = (read as ListeningOk).document;
            for (final probe in (raw['at'] as List<Object?>? ?? const []).cast<Map<String, Object?>>()) {
              final chapter = document.chapters.singleWhere((c) => c.id == probe['chapter']);
              final time = Duration(milliseconds: probe['ms']! as int);
              expect(chapter.pictureAt(time)?.picture, probe['picture'], reason: '${chapter.id} @ ${probe['ms']}: picture');
              // The Tall picture showing then, where the case says (SPEC-058 R-37).
              if (probe.containsKey('tall')) expect(chapter.pictureAt(time)?.tall, probe['tall'], reason: '${chapter.id} @ ${probe['ms']}: tall');
              final phrase = chapter.phraseAt(time);
              expect(phrase == null ? null : chapter.phrases.indexOf(phrase), probe['phrase'], reason: '${chapter.id} @ ${probe['ms']}: phrase');
            }
          case 'newerArke':
            expect(read, isA<ListeningRefused>().having((r) => r.refusal, 'refusal', WorldRefusal.newerArke));
          case 'notAPackage':
            expect(read, isA<ListeningRefused>().having((r) => r.refusal, 'refusal', WorldRefusal.notAPackage));
        }
      });
    }

    test('the book clock puts chapters back to back', () {
      final document = (readListening(File('$_fixtures/valid.json').readAsStringSync(), _assets()) as ListeningOk).document;
      expect(document.duration, const Duration(seconds: 90));
      expect(document.starts, [Duration.zero, const Duration(seconds: 60)]);
      expect(document.chapters.first.pictures[1].hold, const Duration(seconds: 15));
      expect(document.chapters.first.phrases.first.words, hasLength(2));
    });
  });

  group('a schema 2 package added from a file (SPEC-058 R-17 – R-21)', () {
    late Directory dir;
    late LibraryStore store;
    late WorldInstaller installer;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('arke_listening_');
      store = LibraryStore(Directory('${dir.path}/library'));
      await store.load();
      installer = WorldInstaller(store: store, freeBytes: (_) async => null);
    });
    tearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });

    Future<PreparedWorld> prepare(String zip, {List<InstallStep>? steps}) async {
      final file = File(zip);
      return installer.prepareFile(size: await file.length(), open: file.openRead, onStep: steps?.add);
    }

    test('packs as schema 2, checks every file, and adds one listening item with its chapters', () async {
      final packed = await packWorld(await _spec(dir), '${dir.path}/world.zip');
      expect(packed.manifest.schemaVersion, 2);
      // Two audio files, two pictures (one shipped once), the key art, the book, the document.
      expect(packed.manifest.assets, hasLength(7));

      final steps = <InstallStep>[];
      final prepared = await prepare('${dir.path}/world.zip', steps: steps);
      expect(steps.whereType<Copying>(), isNotEmpty);
      expect(steps.whereType<Checking>().last.checked, 7);
      expect(prepared.installed, isNull);
      expect(store.worlds, isEmpty, reason: 'nothing joins the library before Add to library');

      final world = await installer.commit(prepared);
      final production = world.productions.single;
      final narration = store.items.singleWhere((item) => item.id == production.narration);
      expect(narration.format, FileFormat.listening);
      expect(narration.kind, LibraryKind.listen);
      expect(narration.chapters.map((c) => c.title), ['Neap', 'The rail book']);
      expect(narration.chapters[1].start, narration.duration! ~/ 2);
      expect(store.items.singleWhere((item) => item.id == production.book).format, FileFormat.epub);

      // The world keeps its manifest, so a player reads the listening document against it.
      final folder = store.worldDirectory('undersong').path;
      final manifest = readWorldManifest(File('$folder/world.json').readAsStringSync());
      final assets = (manifest as WorldManifestOk).manifest.assets;
      final document = (readListening(File(store.resolve(narration.file)).readAsStringSync(), assets) as ListeningOk).document;
      expect(document.chapters.first.pictures, hasLength(2));
      expect(File('$folder/${assets[document.chapters.first.audio]!.path}').existsSync(), isTrue);
    });

    test('the same edition again is Already in Library; another edition replaces it and keeps its places (P10)', () async {
      await packWorld(await _spec(dir), '${dir.path}/one.zip');
      final first = await installer.commit(await prepare('${dir.path}/one.zip'));
      final narration = first.productions.single.narration!;
      await store.keepPlace(
        narration,
        Place(progress: 0.25, locator: 'the-rail-book', position: const Duration(seconds: 1), updatedAt: DateTime.utc(2026, 10, 21)),
      );

      final again = await prepare('${dir.path}/one.zip');
      expect(again.sameEdition, isTrue);
      await installer.discard(again);
      expect(again.staging.existsSync(), isFalse);

      await packWorld(await _spec(dir, edition: '2026-10-22'), '${dir.path}/two.zip');
      final next = await prepare('${dir.path}/two.zip');
      expect(next.installed?.edition, '2026-10-21');
      expect(next.sameEdition, isFalse);
      await installer.commit(next);
      expect(store.worlds.single.edition, '2026-10-22');
      expect(store.items.singleWhere((item) => item.id == narration).place?.locator, 'the-rail-book');
      expect(store.items.where((item) => item.worldId == 'undersong'), hasLength(2));
    });

    test('a listening document naming a file the package lacks is not an Arke package', () async {
      await packWorld(await _spec(dir), '${dir.path}/world.zip');
      final entries = await _rewrite('${dir.path}/world.zip', (name, bytes) {
        if (!name.endsWith('listening.json')) return bytes;
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
        (((json['chapters']! as List).first as Map)['pictures']! as List).first['picture'] = 'nope';
        return utf8.encode(jsonEncode(json));
      });
      await File('${dir.path}/bad.zip').writeAsBytes(entries);
      // The rewritten document no longer matches its digest either; its reference is refused
      // first, before anything is extracted.
      await expectLater(prepare('${dir.path}/bad.zip'), throwsA(isA<NotAPackage>()));
    });
  });
}

/// The package with one entry changed, still stored.
Future<List<int>> _rewrite(String zip, List<int> Function(String name, List<int> bytes) change) async {
  final out = Archive();
  for (final file in ZipDecoder().decodeBytes(await File(zip).readAsBytes()).files) {
    out.add(ArchiveFile.bytes(file.name, change(file.name, file.readBytes()!))..compression = CompressionType.none);
  }
  return ZipEncoder().encodeBytes(out);
}
