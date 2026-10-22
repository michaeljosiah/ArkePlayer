import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arke_media/arke_media.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:test/test.dart';

// The fixtures are made by tool/make_fixtures.py with ffmpeg, so these read what real tools write.
String fixture(String name) => 'test${Platform.pathSeparator}fixtures${Platform.pathSeparator}$name';

void main() {
  test('an M4B: tags, cover, length and its three chapters', () {
    final info = readMediaInfo(fixture('chapters.m4b'), FileFormat.m4b);
    expect(info.title, 'Tidewater Sessions');
    expect(info.author, 'Amaal Reyes');
    expect(info.duration!.inMilliseconds, closeTo(6000, 150));
    expect([for (final chapter in info.chapters) chapter.title], ['The Weigh House', 'The Weir', 'The Tenth Key']);
    expect(info.chapters[1].start.inMilliseconds, closeTo(2000, 50));
    expect(info.cover!.bytes.take(2), [0xFF, 0xD8], reason: 'a JPEG cover');
  });

  test('an MP3: ID3 tags, cover, CHAP chapters and its length', () {
    final info = readMediaInfo(fixture('tagged.mp3'), FileFormat.mp3);
    expect(info.title, 'Tidewater Sessions');
    expect(info.author, 'Amaal Reyes');
    expect(info.duration!.inMilliseconds, closeTo(6000, 200));
    expect([for (final chapter in info.chapters) chapter.title], ['The Weigh House', 'The Weir', 'The Tenth Key']);
    expect(info.cover, isNotNull);
  });

  test('a film: its length and title from the container', () {
    final info = readMediaInfo(fixture('reel.mp4'), FileFormat.mp4);
    expect(info.title, 'Lighthouse reel');
    expect(info.duration!.inMilliseconds, closeTo(2000, 150));
    expect(readMediaInfo(fixture('clip.mov'), FileFormat.mov).duration!.inMilliseconds, closeTo(1000, 150));
  });

  test('an EPUB: title, author and the cover its package names', () {
    final info = readMediaInfo(fixture('book.epub'), FileFormat.epub);
    expect(info.title, 'The Salt Almanac');
    expect(info.author, 'Ines Varga');
    expect(info.cover!.bytes.take(2), [0xFF, 0xD8]);
    expect(info.protectedFile, isFalse);
  });

  test('an EPUB\'s spine, as paths in the archive', () {
    expect(readEpubSpineAt(fixture('book.epub')), ['OEBPS/text/one.xhtml']);
  });

  test('DRM is refused, font obfuscation is not', () {
    expect(readMediaInfo(fixture('protected.epub'), FileFormat.epub).protectedFile, isTrue);
    expect(readMediaInfo(fixture('fonts-only.epub'), FileFormat.epub).protectedFile, isFalse);
  });

  test('a file that is not what it claims cannot be opened', () {
    final dir = Directory.systemTemp.createTempSync('arke-media-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final truncated = File('${dir.path}${Platform.pathSeparator}cut.mp4')..writeAsBytesSync(File(fixture('reel.mp4')).readAsBytesSync().sublist(0, 40));
    expect(() => readMediaInfo(truncated.path, FileFormat.mp4), throwsA(isA<UnreadableFile>()));
    final notZip = File('${dir.path}${Platform.pathSeparator}book.epub')..writeAsStringSync('not a zip');
    expect(() => readMediaInfo(notZip.path, FileFormat.epub), throwsA(isA<UnreadableFile>()));
  });

  test('Nero chapters (chpl) are read when there is no chapter track', () {
    // moov > [mvhd, udta > chpl]: two chapters at 0 s and 90 s.
    Uint8List atom(String type, List<int> body) =>
        Uint8List.fromList([...(ByteData(4)..setUint32(0, body.length + 8)).buffer.asUint8List(), ...ascii.encode(type), ...body]);
    final mvhd = Uint8List(100)..buffer.asByteData().setUint32(12, 1000);
    mvhd.buffer.asByteData().setUint32(16, 180000);
    List<int> entry(int seconds, String title) => [
      ...(ByteData(8)..setUint64(0, seconds * 10000000)).buffer.asUint8List(),
      title.length,
      ...utf8.encode(title),
    ];
    final chpl = atom('chpl', [1, 0, 0, 0, 0, 0, 0, 0, 2, ...entry(0, 'Opening'), ...entry(90, 'The Weir')]);
    final file = [
      ...atom('ftyp', ascii.encode('M4B 0000')),
      ...atom('moov', [...atom('mvhd', mvhd), ...atom('udta', chpl)]),
    ];
    final dir = Directory.systemTemp.createTempSync('arke-media-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}nero.m4b';
    File(path).writeAsBytesSync(file);

    final info = readMediaInfo(path, FileFormat.m4b);
    expect(info.duration, const Duration(minutes: 3));
    expect([for (final chapter in info.chapters) (chapter.title, chapter.start)], [('Opening', Duration.zero), ('The Weir', const Duration(seconds: 90))]);
  });
}
