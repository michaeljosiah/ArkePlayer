import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

// The book and narration are arke_media's fixtures, made by ffmpeg (tool/make_fixtures.py): an
// EPUB, and an M4B with three chapter markers.
final _fixtures = '${Directory.current.path}/../arke_media/test/fixtures';

Future<Directory> _temp() => Directory.systemTemp.createTemp('arke_world_');

/// A world spec over the fixtures, with a key art of a few bytes (nothing reads a picture's pixels).
Future<WorldSpec> _spec(Directory dir) async {
  final art = File('${dir.path}/key-art.jpg');
  await art.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 0xFF, 0xD9]);
  return WorldSpec(
    id: 'undersong',
    edition: '2026-10-21',
    name: 'The Undersong',
    logline: 'A drowned god still sings beneath the harbour.',
    keyArt: art.path,
    productions: [ProductionSpec(id: 'ledger-of-nights', title: 'The Ledger of Nights', book: '$_fixtures/book.epub', narration: '$_fixtures/chapters.m4b')],
  );
}

/// A ZIP of exactly these entries, stored.
List<int> _zip(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in entries.entries) {
    archive.add(ArchiveFile.bytes(key, value)..compression = CompressionType.none);
  }
  return ZipEncoder().encodeBytes(archive, level: 0);
}

/// A served package. [halfThenHang] sends half and never finishes; [halfThenDrop] sends half and
/// closes the connection.
class _Server {
  _Server._(this._server, this.bytes);

  final HttpServer _server;
  List<int> bytes;
  int hits = 0;
  bool halfThenHang = false;
  bool halfThenDrop = false;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/world.zip');

  static Future<_Server> start(List<int> bytes) async {
    final server = _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0), bytes);
    server._server.listen(server._handle);
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    hits++;
    final response = request.response..contentLength = bytes.length;
    if (halfThenHang || halfThenDrop) {
      response.add(bytes.sublist(0, bytes.length ~/ 2));
      await response.flush();
      if (halfThenDrop) await _server.close(force: true);
      return;
    }
    response.add(bytes);
    await response.close();
  }

  Future<void> close() => _server.close(force: true);
}

CatalogueWorld _entry(Uri url, List<int> bytes, {String? sha256Override}) => CatalogueWorld(
  id: 'undersong',
  name: 'The Undersong',
  productions: const [CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook · Book')],
  package: CataloguePackage(url: url, byteLength: bytes.length, sha256: sha256Override ?? sha256.convert(bytes).toString()),
);

void main() {
  group('the packer and the reader agree', () {
    test('a packed world reads back, its assets stored', () async {
      final dir = await _temp();
      addTearDown(() => dir.delete(recursive: true));
      final packed = await packWorld(await _spec(dir), '${dir.path}/world.zip', url: 'https://example.org/world.zip');
      final manifest = readWorldPackage('${dir.path}/world.zip');
      expect(manifest.id, 'undersong');
      expect(manifest.productions.single.book, isNotNull);
      expect(manifest.productions.single.narration, isNotNull);
      expect(packed.byteLength, await File('${dir.path}/world.zip').length());
      final entry = packed.catalogueEntry;
      expect((entry['productions']! as List).single, containsPair('kind', startsWith('Audiobook · Book · ')));
      expect(entry['package'], containsPair('url', 'https://example.org/world.zip'));
      // The entry the packer prints is one the app reads.
      expect(
        readCatalogue(
          jsonEncode({
            'version': 1,
            'worlds': [entry],
          }),
        ).single.package!.sha256,
        packed.sha256,
      );
    });
  });

  group('world.json is read strictly (SPEC-048 R-17)', () {
    Map<String, Object?> valid() => {
      'format': 'arke-world-package',
      'schemaVersion': 1,
      'id': 'undersong',
      'edition': '1',
      'name': 'The Undersong',
      'productions': [
        {'id': 'ledger', 'title': 'The Ledger of Nights', 'book': 'book'},
      ],
      'assets': {
        'book': {'path': 'ledger/book.epub', 'mediaType': 'application/epub+zip', 'byteLength': 3, 'sha256': 'a' * 64},
      },
    };
    WorldManifestRead read(Map<String, Object?> json) => readWorldManifest(jsonEncode(json));

    test('a valid manifest', () => expect(read(valid()), isA<WorldManifestOk>()));
    test('a newer schema, a required capability or an unknown key: made with a newer Arke', () {
      for (final json in [
        valid()..['schemaVersion'] = 5,
        valid()..['requires'] = ['narrated-book-v1'],
        valid()..['chapters'] = <Object?>[],
      ]) {
        expect(read(json), isA<WorldManifestRefused>().having((r) => r.refusal, 'refusal', WorldRefusal.newerArke));
      }
    });
    test('metadata is ignorable', () => expect(read(valid()..['metadata'] = {'x': 1}), isA<WorldManifestOk>()));
    test('traversal, an unused asset, a book that is not an EPUB, nothing to play: not an Arke package', () {
      final traversal = valid();
      ((traversal['assets']! as Map)['book']! as Map)['path'] = '../book.epub';
      final unused = valid();
      (unused['assets']! as Map)['extra'] = {'path': 'x.jpg', 'mediaType': 'image/jpeg', 'byteLength': 1, 'sha256': 'b' * 64};
      final wrongType = valid();
      ((wrongType['assets']! as Map)['book']! as Map)['mediaType'] = 'audio/mpeg';
      final nothing = valid()
        ..['productions'] = [
          {'id': 'ledger', 'title': 'The Ledger of Nights'},
        ];
      for (final json in [traversal, unused, wrongType, nothing, valid()..['format'] = 'arke-publication']) {
        expect(read(json), isA<WorldManifestRefused>().having((r) => r.refusal, 'refusal', WorldRefusal.notAPackage));
      }
    });
  });

  group('the catalogue the app ships', () {
    final text = '''{"version": 1, "worlds": [
      {"id": "undersong", "name": "The Undersong", "productions": [{"title": "The Ledger of Nights", "kind": "Audiobook · Book"}], "package": null},
      {"id": "meridian", "name": "Meridian Dust", "productions": [{"title": "Dust Line", "kind": "Book"}],
       "package": {"url": "https://example.org/m.zip", "byteLength": 10, "sha256": "${'c' * 64}"}}]}''';

    test('a world with no published package is not offered', () {
      final catalogue = readCatalogue(text);
      expect(catalogue, hasLength(2));
      expect(availableWorlds(catalogue, const []).map((world) => world.id), ['meridian']);
    });
    test('an installed world leaves Available', () {
      final installed = LibraryWorld(
        id: 'meridian',
        edition: '1',
        name: 'Meridian Dust',
        byteLength: 10,
        installedAt: DateTime.utc(2026),
        productions: const [],
      );
      expect(availableWorlds(readCatalogue(text), [installed]), isEmpty);
    });
    test('a package not over HTTPS is a build error', () {
      expect(() => readCatalogue(text.replaceFirst('https://', 'http://')), throwsFormatException);
    });
  });

  group('installing (P9 rules 4–6)', () {
    late Directory dir;
    late LibraryStore store;
    late List<int> package;
    late _Server server;

    setUp(() async {
      dir = await _temp();
      await packWorld(await _spec(dir), '${dir.path}/world.zip');
      package = await File('${dir.path}/world.zip').readAsBytes();
      store = LibraryStore(Directory('${dir.path}/library'));
      await store.load();
      server = await _Server.start(package);
    });
    tearDown(() async {
      await server.close();
      await store.close();
      await dir.delete(recursive: true);
    });

    WorldInstaller installer({int? free, Duration idle = const Duration(seconds: 30)}) =>
        WorldInstaller(store: store, freeBytes: (_) async => free, idle: idle);
    Future<List<String>> leftovers() async =>
        (await store.root.list(recursive: true).toList()).map((e) => e.path).where((p) => p.contains('.installing-')).toList();

    test('downloads, checks every file, and adds the world and its items in one write', () async {
      final steps = <InstallStep>[];
      final world = await installer().install(_entry(server.url, package), onStep: steps.add);

      expect(steps.whereType<Downloading>().last.received, package.length);
      final checks = steps.whereType<Checking>().toList();
      expect(checks.last.checked, checks.last.total);
      expect(checks.last.total, 3);

      expect(store.worlds.single.id, 'undersong');
      expect(world.logline, 'A drowned god still sings beneath the harbour.');
      final production = world.productions.single;
      final narration = store.items.singleWhere((item) => item.id == production.narration);
      final book = store.items.singleWhere((item) => item.id == production.book);
      expect(narration.worldId, 'undersong');
      expect(narration.chapters, hasLength(3));
      expect(narration.title, 'The Ledger of Nights');
      expect(book.format.name, 'epub');
      expect(File(store.resolve(narration.file)).existsSync(), isTrue);
      expect(File(store.resolve(book.file)).existsSync(), isTrue);
      expect(File(store.resolve(world.keyArt!)).existsSync(), isTrue);
      expect(await leftovers(), isEmpty);
      expect(File('${store.worldDirectory('undersong').path}/package.zip').existsSync(), isFalse);

      // A world's items are not files: not in Added, Library's rows or the chips (P9 rule 6).
      expect(addedShelf(store.items), isEmpty);
      expect(libraryRows(store.items), isEmpty);
      expect(bytesUsed(store.items, store.worlds), world.byteLength);

      // They keep places and join Continue as files do.
      await store.keepPlace(narration.id, Place(progress: 0.3, position: const Duration(seconds: 2), updatedAt: DateTime.utc(2026, 10, 21)));
      expect(continueShelf(store.items).single.id, narration.id);

      // The index holds it across a reload.
      final reloaded = LibraryStore(store.root);
      await reloaded.load();
      expect(reloaded.worlds.single.productions.single.title, 'The Ledger of Nights');
      await reloaded.close();
    });

    test('Remove deletes the world, its items and its places', () async {
      await installer().install(_entry(server.url, package));
      await store.removeWorld('undersong');
      expect(store.worlds, isEmpty);
      expect(store.items, isEmpty);
      expect(store.worldDirectory('undersong').existsSync(), isFalse);
    });

    test('too little space is refused before the first byte', () async {
      await expectLater(installer(free: 1000).install(_entry(server.url, package)), throwsA(isA<NeedsSpace>()));
      expect(server.hits, 0);
    });

    test('no server: No connection', () async {
      final url = server.url;
      await server.close();
      await expectLater(installer().install(_entry(url, package)), throwsA(isA<NoConnection>()));
      expect(await leftovers(), isEmpty);
    });

    test('a connection dropped halfway: Download stopped, nothing kept', () async {
      server.halfThenDrop = true;
      await expectLater(installer().install(_entry(server.url, package)), throwsA(isA<DownloadStopped>()));
      expect(store.worlds, isEmpty);
      expect(await leftovers(), isEmpty);
    });

    test('a download that goes quiet has stopped', () async {
      server.halfThenHang = true;
      await expectLater(installer(idle: const Duration(milliseconds: 300)).install(_entry(server.url, package)), throwsA(isA<DownloadStopped>()));
    });

    test('Cancel deletes what has come', () async {
      server.halfThenHang = true;
      final cancel = InstallCancel();
      final install = installer().install(
        _entry(server.url, package),
        cancel: cancel,
        onStep: (step) {
          if (step is Downloading) cancel.cancel();
        },
      );
      await expectLater(install, throwsA(isA<InstallCancelled>()));
      expect(await leftovers(), isEmpty);
    });

    test('not the package the app was built for: 1 file does not match', () async {
      await expectLater(
        installer().install(_entry(server.url, package, sha256Override: 'd' * 64)),
        throwsA(isA<FilesDoNotMatch>().having((r) => r.clause, 'clause', '1 file does not match')),
      );
    });

    group('a package whose contents are wrong', () {
      late Map<String, List<int>> entries;
      setUp(() {
        entries = {for (final file in ZipDecoder().decodeBytes(package).files) file.name: file.readBytes()!};
      });
      Future<InstallRefusal> refusalFor(Map<String, List<int>> changed) async {
        server.bytes = _zip(changed);
        try {
          await installer().install(_entry(server.url, server.bytes));
        } on InstallRefusal catch (refusal) {
          return refusal;
        }
        fail('installed');
      }

      test('a file that differs from its manifest: N files do not match', () async {
        final book = entries.keys.singleWhere((name) => name.endsWith('book.epub'));
        final bytes = [...entries[book]!];
        bytes[bytes.length - 1] ^= 0xFF;
        expect((await refusalFor({...entries, book: bytes})).clause, '1 file does not match');
        expect(store.worlds, isEmpty);
      });
      test('a file the manifest does not name: Not an Arke package', () async {
        expect(
          await refusalFor({
            ...entries,
            'extra.txt': [1],
          }),
          isA<NotAPackage>(),
        );
      });
      test('a path that climbs out: Not an Arke package', () async {
        expect(
          await refusalFor({
            ...entries,
            '../escape.txt': [1],
          }),
          isA<NotAPackage>(),
        );
      });
      test('a newer schema: Made with a newer Arke', () async {
        final json = jsonDecode(utf8.decode(entries['world.json']!)) as Map<String, Object?>;
        json['schemaVersion'] = 5;
        expect(await refusalFor({...entries, 'world.json': utf8.encode(jsonEncode(json))}), isA<NewerArke>());
      });
      test('not a ZIP: Not an Arke package', () async {
        server.bytes = utf8.encode('not a zip at all');
        await expectLater(installer().install(_entry(server.url, server.bytes)), throwsA(isA<NotAPackage>()));
      });
    });

    test('an install a crash interrupted is cleared on the next load', () async {
      final staged = await store.stageWorld();
      await File('${staged.path}/package.zip').writeAsBytes([1, 2, 3]);
      final reloaded = LibraryStore(store.root);
      await reloaded.load();
      expect(staged.existsSync(), isFalse);
      await reloaded.close();
    });
  });
}
