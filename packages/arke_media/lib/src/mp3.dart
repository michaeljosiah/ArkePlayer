import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'info.dart';

/// Reads an MP3: its ID3v2.3 or v2.4 tag (title `TIT2`, author `TPE1`, album `TALB`, cover `APIC`,
/// chapters `CHAP` with their `TIT2`), and its length from the first frame's Xing or Info header,
/// else from a constant bitrate. A tag that is not v2.3 or v2.4 is skipped, not guessed at.
MediaInfo readMp3(RandomAccessFile file) {
  final length = file.lengthSync();
  file.setPositionSync(0);
  final head = file.readSync(10);
  var audioStart = 0;
  String? title, author, album;
  MediaCover? cover;
  final chapters = <MediaChapter>[];

  if (head.length == 10 && ascii.decode(head.sublist(0, 3), allowInvalid: true) == 'ID3') {
    final major = head[3];
    final tagSize = _syncsafe(head, 6);
    audioStart = 10 + tagSize + ((head[5] & 0x10) != 0 ? 10 : 0);
    if (major == 3 || major == 4) {
      final tag = file.readSync(tagSize);
      for (final frame in _frames(tag, major)) {
        switch (frame.id) {
          case 'TIT2':
            title ??= _text(frame.body);
          case 'TPE1':
            author ??= _text(frame.body);
          case 'TALB':
            album ??= _text(frame.body);
          case 'APIC':
            cover ??= _picture(frame.body);
          case 'CHAP':
            final chapter = _chapter(frame.body, major);
            if (chapter != null) chapters.add(chapter);
        }
      }
    }
  }

  chapters.sort((a, b) => a.start.compareTo(b.start));
  return MediaInfo(
    title: cleanText(title),
    author: cleanText(author),
    album: cleanText(album),
    duration: _duration(file, audioStart, length),
    chapters: chapters,
    cover: cover,
  );
}

int _syncsafe(List<int> bytes, int at) => (bytes[at] & 0x7F) << 21 | (bytes[at + 1] & 0x7F) << 14 | (bytes[at + 2] & 0x7F) << 7 | (bytes[at + 3] & 0x7F);

class _Frame {
  _Frame(this.id, this.body);
  final String id;
  final Uint8List body;
}

Iterable<_Frame> _frames(Uint8List tag, int major) sync* {
  var at = 0;
  while (at + 10 <= tag.length) {
    final id = latin1.decode(tag.sublist(at, at + 4));
    if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(id)) return; // padding
    final size = major == 4 ? _syncsafe(tag, at + 4) : ByteData.sublistView(tag).getUint32(at + 4);
    final end = at + 10 + size;
    if (size <= 0 || end > tag.length) return;
    yield _Frame(id, Uint8List.sublistView(tag, at + 10, end));
    at = end;
  }
}

/// A text frame: an encoding byte, then the text.
String? _text(Uint8List body) => body.isEmpty ? null : _decode(body[0], Uint8List.sublistView(body, 1));

String _decode(int encoding, Uint8List bytes) {
  switch (encoding) {
    case 0:
      return latin1.decode(bytes);
    case 1:
    case 2:
      var units = bytes;
      var bigEndian = encoding == 2;
      if (encoding == 1 && units.length >= 2) {
        bigEndian = units[0] == 0xFE && units[1] == 0xFF;
        if ((units[0] == 0xFF && units[1] == 0xFE) || bigEndian) units = Uint8List.sublistView(units, 2);
      }
      final codes = <int>[];
      for (var i = 0; i + 1 < units.length; i += 2) {
        codes.add(bigEndian ? units[i] << 8 | units[i + 1] : units[i + 1] << 8 | units[i]);
      }
      return String.fromCharCodes(codes);
    default:
      return utf8.decode(bytes, allowMalformed: true);
  }
}

/// `APIC`: encoding, a MIME type ended by a zero, a picture type, a description ended by a zero
/// (two for UTF-16), then the picture.
MediaCover? _picture(Uint8List body) {
  if (body.length < 4) return null;
  final encoding = body[0];
  var at = 1;
  final mimeEnd = body.indexOf(0, at);
  if (mimeEnd < 0) return null;
  final mime = latin1.decode(body.sublist(at, mimeEnd)).toLowerCase();
  at = mimeEnd + 2; // past the zero and the picture type
  if (encoding == 1 || encoding == 2) {
    while (at + 1 < body.length && !(body[at] == 0 && body[at + 1] == 0)) {
      at += 2;
    }
    at += 2;
  } else {
    final end = body.indexOf(0, at);
    if (end < 0) return null;
    at = end + 1;
  }
  if (at >= body.length) return null;
  return MediaCover(Uint8List.fromList(body.sublist(at)), mime.contains('png') ? 'image/png' : 'image/jpeg');
}

/// `CHAP`: an element id ended by a zero, start and end in milliseconds, two offsets, then
/// sub-frames — of which `TIT2` is the title.
MediaChapter? _chapter(Uint8List body, int major) {
  final idEnd = body.indexOf(0);
  if (idEnd < 0 || idEnd + 17 > body.length) return null;
  final view = ByteData.sublistView(body);
  final startMs = view.getUint32(idEnd + 1);
  String? title;
  for (final sub in _frames(Uint8List.sublistView(body, idEnd + 17), major)) {
    if (sub.id == 'TIT2') title = _text(sub.body);
  }
  return MediaChapter(cleanText(title) ?? latin1.decode(body.sublist(0, idEnd)), Duration(milliseconds: startMs));
}

const _bitrates = {
  1: [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0], // MPEG-1 Layer III
  2: [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0], // MPEG-2 and 2.5 Layer III
};
const _rates = {
  3: [44100, 48000, 32000], // MPEG-1
  2: [22050, 24000, 16000], // MPEG-2
  0: [11025, 12000, 8000], // MPEG-2.5
};

/// The length from the first frame: frames × samples per frame ÷ rate when a Xing or Info header
/// counts them, else the audio's bytes at the first frame's bitrate.
Duration? _duration(RandomAccessFile file, int from, int length) {
  file.setPositionSync(from);
  final window = file.readSync(64 * 1024);
  for (var i = 0; i + 4 <= window.length; i++) {
    if (window[i] != 0xFF || (window[i + 1] & 0xE0) != 0xE0) continue;
    final version = (window[i + 1] >> 3) & 0x3; // 3 MPEG-1, 2 MPEG-2, 0 MPEG-2.5
    final layer = (window[i + 1] >> 1) & 0x3; // 1 Layer III
    final bitrateIndex = window[i + 2] >> 4;
    final rateIndex = (window[i + 2] >> 2) & 0x3;
    if (version == 1 || layer != 1 || bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) continue;
    final rate = _rates[version]![rateIndex];
    final bitrate = _bitrates[version == 3 ? 1 : 2]![bitrateIndex] * 1000;
    final mono = (window[i + 3] >> 6) == 3;
    final samplesPerFrame = version == 3 ? 1152 : 576;
    final sideInfo = version == 3 ? (mono ? 17 : 32) : (mono ? 9 : 17);
    final xing = i + 4 + sideInfo;
    if (xing + 12 <= window.length) {
      final marker = ascii.decode(window.sublist(xing, xing + 4), allowInvalid: true);
      if (marker == 'Xing' || marker == 'Info') {
        final flags = ByteData.sublistView(window).getUint32(xing + 4);
        if (flags & 1 != 0) {
          final frames = ByteData.sublistView(window).getUint32(xing + 8);
          return Duration(microseconds: frames * samplesPerFrame * 1000000 ~/ rate);
        }
      }
    }
    if (bitrate == 0) return null;
    return Duration(microseconds: (length - from - i) * 8 * 1000000 ~/ bitrate);
  }
  return null;
}
