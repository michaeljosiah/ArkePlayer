import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/features/add_file/application/file_importer.dart';
import 'package:arke_player/features/add_file/domain/added_file.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:flutter_test/flutter_test.dart';

// Real files made by packages/arke_media/tool/make_fixtures.py with ffmpeg.
String fixture(String name) => ['..', '..', 'packages', 'arke_media', 'test', 'fixtures', name].join(Platform.pathSeparator);

class _Poster implements VideoPoster {
  @override
  Future<bool> save(String video, String jpeg) async {
    File(jpeg).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    return true;
  }
}

class _NoPdf implements PdfPeek {
  @override
  Future<PdfFacts> peek(String path) async => const PdfFacts(pages: 24);
}

void main() {
  late Directory root;
  late LibraryStore store;
  late Directory scratch;

  FileImporter importer({int? free}) => FileImporter(store: store, freeBytes: (_) async => free, pdf: _NoPdf(), poster: _Poster());
  PickedFile picked(String path, [String? name]) => PickedFile.path(path, name: name);
  Future<List<String>> folders() async =>
      (await store.itemDirectory('x').parent.exists()) ? [await for (final entry in store.itemDirectory('x').parent.list()) entry.path] : const <String>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('arke-player-library-');
    scratch = await Directory.systemTemp.createTemp('arke-player-picked-');
    store = LibraryStore(root);
    await store.load();
  });
  tearDown(() async {
    await root.delete(recursive: true);
    await scratch.delete(recursive: true);
  });

  test('a mixed batch: each read, the film takes its captions, Add joins them (P7 rules 1–3)', () async {
    final srt = File('${scratch.path}${Platform.pathSeparator}reel.srt')..writeAsStringSync('1\n00:00:00,500 --> 00:00:01,500\nThe tide is lower.\n');
    final candidates = await importer(
      free: 1 << 40,
    ).read([picked(fixture('chapters.m4b')), picked(fixture('book.epub')), picked(fixture('reel.mp4')), picked(srt.path)]);

    expect(candidates, everyElement(isA<Readable>()));
    expect(addLabel(candidates), 'Add 3');
    final items = {for (final candidate in candidates.cast<Readable>()) candidate.item.format: candidate.item};
    expect(items[FileFormat.m4b]!.title, 'Tidewater Sessions');
    expect(items[FileFormat.m4b]!.chapters.length, 3);
    expect(items[FileFormat.m4b]!.cover, isNotNull);
    expect(items[FileFormat.epub]!.author, 'Ines Varga');
    expect(items[FileFormat.mp4]!.captions, isNotNull);
    expect(items[FileFormat.mp4]!.cover, isNotNull, reason: 'a film with no cover gets a frame as its poster');
    expect(File(store.resolve(items[FileFormat.mp4]!.captions!)).existsSync(), isTrue);
    expect(store.items, isEmpty, reason: 'nothing joins before Add');

    expect(await importer().add(candidates), 3);
    expect((await LibraryStore(root).load()).length, 3);
  });

  test('DRM is refused as Protected file and its copy deleted', () async {
    final candidates = await importer(free: 1 << 40).read([picked(fixture('protected.epub'))]);
    expect((candidates.single as Refused).clause, Refused.protectedFile);
    expect(await folders(), isEmpty);
  });

  test('captions alone are refused; they travel with their film', () async {
    final vtt = File('${scratch.path}${Platform.pathSeparator}notes.vtt')..writeAsStringSync('WEBVTT\n\n');
    final candidates = await importer(free: 1 << 40).read([picked(vtt.path)]);
    expect((candidates.single as Refused).clause, Refused.captionsAlone);
  });

  test('a file that is not what it claims cannot be opened', () async {
    final bytes = File(fixture('reel.mp4')).readAsBytesSync().sublist(0, 40);
    final cut = File('${scratch.path}${Platform.pathSeparator}cut.mp4')..writeAsBytesSync(bytes);
    final candidates = await importer(free: 1 << 40).read([picked(cut.path)]);
    expect((candidates.single as Refused).clause, Refused.cannotOpen);
    expect(await folders(), isEmpty);
  });

  test('a file larger than the free space is refused before anything is copied, with both numbers', () async {
    final candidates = await importer(free: 50 * 1000 * 1000).read([picked(fixture('chapters.m4b'))]);
    expect((candidates.single as Refused).clause, startsWith('Needs '));
    expect((candidates.single as Refused).clause, endsWith('50 MB free'));
    expect(await folders(), isEmpty);
  });

  test('a MOBI and an Arke package are refused in one clause each', () async {
    final mobi = File('${scratch.path}${Platform.pathSeparator}dune.azw3')
      ..writeAsBytesSync([...List.filled(60, 0), ...'BOOKMOBI'.codeUnits, ...List.filled(200, 0)]);
    final package = File('${scratch.path}${Platform.pathSeparator}world.arke')..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, ...List.filled(200, 0)]);
    final candidates = await importer(free: 1 << 40).read([picked(mobi.path), picked(package.path)]);
    expect([for (final candidate in candidates) (candidate as Refused).clause], [Refused.notSupported, Refused.packageLater]);
  });

  test('Cancel deletes every copy; nothing is half-added', () async {
    final run = importer(free: 1 << 40);
    final candidates = await run.read([picked(fixture('tagged.mp3')), picked(fixture('clip.mov'))]);
    expect(await folders(), hasLength(2));
    await run.discard(candidates);
    expect(await folders(), isEmpty);
    expect(store.items, isEmpty);
  });
}
