import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'info.dart';

/// Reads an ISO base media file (MP4, M4A, M4B, MOV) by walking its atoms. Only headers and the
/// small boxes named below are read; media data is never touched, so a 2 GB film reads as fast as
/// a song.
///
/// - Length: `moov/mvhd`.
/// - Tags: iTunes `moov/udta/meta/ilst` — `©nam` title, `©ART` or `aART` author, `©alb` album,
///   `covr` cover.
/// - Chapters: Nero `moov/udta/chpl`, else the QuickTime chapter track a `tref/chap` points at
///   (what ffmpeg and most audiobook tools write), whose text samples are the titles.
MediaInfo readMp4(RandomAccessFile file) {
  final length = file.lengthSync();
  final moov = _children(file, 0, length).where((atom) => atom.type == 'moov').firstOrNull;
  if (moov == null) throw const UnreadableFile('no moov atom');
  final top = _children(file, moov.body, moov.end).toList();

  Duration? duration;
  final mvhd = top.where((atom) => atom.type == 'mvhd').firstOrNull;
  if (mvhd != null) duration = _mvhdDuration(_read(file, mvhd.body, mvhd.end - mvhd.body));

  String? title, author, albumArtist, album;
  MediaCover? cover;
  var chapters = <MediaChapter>[];
  final udta = top.where((atom) => atom.type == 'udta').firstOrNull;
  if (udta != null) {
    for (final box in _children(file, udta.body, udta.end)) {
      if (box.type == 'chpl') chapters = _chpl(_read(file, box.body, box.end - box.body));
      if (box.type != 'meta') continue;
      // iTunes' meta is a full box (version and flags first); QuickTime's is not. Its first child is hdlr.
      final peek = _read(file, box.body + 4, 4);
      final start = ascii.decode(peek, allowInvalid: true) == 'hdlr' ? box.body : box.body + 4;
      for (final metaChild in _children(file, start, box.end)) {
        if (metaChild.type != 'ilst') continue;
        for (final tag in _children(file, metaChild.body, metaChild.end)) {
          final data = _children(file, tag.body, tag.end).where((atom) => atom.type == 'data').firstOrNull;
          if (data == null || data.end - data.body < 8) continue;
          final bytes = _read(file, data.body, data.end - data.body);
          final typeCode = ByteData.sublistView(bytes).getUint32(0) & 0xFFFFFF;
          final payload = Uint8List.sublistView(bytes, 8);
          switch (tag.type) {
            case '©nam':
              title = utf8.decode(payload, allowMalformed: true);
            case '©ART':
              author = utf8.decode(payload, allowMalformed: true);
            case 'aART':
              albumArtist = utf8.decode(payload, allowMalformed: true);
            case '©alb':
              album = utf8.decode(payload, allowMalformed: true);
            case 'covr':
              if (payload.isNotEmpty) cover = MediaCover(Uint8List.fromList(payload), typeCode == 14 ? 'image/png' : 'image/jpeg');
          }
        }
      }
    }
  }

  if (chapters.isEmpty) chapters = _quickTimeChapters(file, top);
  return MediaInfo(
    title: cleanText(title),
    author: cleanText(author) ?? cleanText(albumArtist),
    album: cleanText(album),
    duration: duration,
    chapters: chapters,
    cover: cover,
  );
}

class _Atom {
  _Atom(this.type, this.start, this.header, this.size);

  final String type;
  final int start;
  final int header;
  final int size;

  int get body => start + header;
  int get end => start + size;
}

/// The atoms between [from] and [to]. Stops at the first malformed header rather than guessing.
Iterable<_Atom> _children(RandomAccessFile file, int from, int to) sync* {
  var at = from;
  while (at + 8 <= to) {
    final head = _read(file, at, 16);
    if (head.length < 8) return;
    final view = ByteData.sublistView(head);
    var size = view.getUint32(0);
    final type = latin1.decode(head.sublist(4, 8));
    var header = 8;
    if (size == 1) {
      if (head.length < 16) return;
      size = view.getUint64(8);
      header = 16;
    } else if (size == 0) {
      size = to - at;
    }
    if (size < header || at + size > to) return;
    yield _Atom(type, at, header, size);
    at += size;
  }
}

Uint8List _read(RandomAccessFile file, int at, int count) {
  file.setPositionSync(at);
  return file.readSync(count);
}

Duration? _mvhdDuration(Uint8List body) {
  if (body.isEmpty) return null;
  final view = ByteData.sublistView(body);
  final version = body[0];
  final int timescale, units;
  if (version == 1) {
    if (body.length < 32) return null;
    timescale = view.getUint32(20);
    units = view.getUint64(24);
  } else {
    if (body.length < 20) return null;
    timescale = view.getUint32(12);
    units = view.getUint32(16);
  }
  if (timescale == 0) return null;
  return Duration(microseconds: units * 1000000 ~/ timescale);
}

/// Nero chapters: version, flags, (four reserved bytes from version 1), a count, then each start
/// in 100-nanosecond units and a length-prefixed title.
List<MediaChapter> _chpl(Uint8List body) {
  if (body.length < 5) return const [];
  final view = ByteData.sublistView(body);
  var at = 4;
  if (body[0] > 0) at += 4;
  if (at >= body.length) return const [];
  final count = body[at++];
  final chapters = <MediaChapter>[];
  for (var i = 0; i < count && at + 9 <= body.length; i++) {
    final start = view.getUint64(at);
    final titleLength = body[at + 8];
    at += 9;
    if (at + titleLength > body.length) break;
    final title = utf8.decode(body.sublist(at, at + titleLength), allowMalformed: true);
    at += titleLength;
    chapters.add(MediaChapter(cleanText(title) ?? 'Chapter ${i + 1}', Duration(microseconds: start ~/ 10)));
  }
  return chapters;
}

/// The QuickTime chapter track: a text track whose samples are the titles, timed by its `stts`.
List<MediaChapter> _quickTimeChapters(RandomAccessFile file, List<_Atom> moovChildren) {
  final tracks = <int, _Atom>{};
  int? chapterTrackId;
  for (final trak in moovChildren.where((atom) => atom.type == 'trak')) {
    final children = _children(file, trak.body, trak.end).toList();
    final tkhd = children.where((atom) => atom.type == 'tkhd').firstOrNull;
    if (tkhd == null) continue;
    final body = _read(file, tkhd.body, 24);
    if (body.length < 24) continue;
    final id = ByteData.sublistView(body).getUint32(body[0] == 1 ? 20 : 12);
    tracks[id] = trak;
    final tref = children.where((atom) => atom.type == 'tref').firstOrNull;
    if (tref == null) continue;
    for (final reference in _children(file, tref.body, tref.end)) {
      if (reference.type == 'chap' && reference.end - reference.body >= 4) {
        chapterTrackId ??= ByteData.sublistView(_read(file, reference.body, 4)).getUint32(0);
      }
    }
  }
  final chapterTrak = chapterTrackId == null ? null : tracks[chapterTrackId];
  if (chapterTrak == null) return const [];

  final mdia = _child(file, chapterTrak, 'mdia');
  final mdhd = mdia == null ? null : _child(file, mdia, 'mdhd');
  final stbl = mdia == null ? null : _path(file, mdia, ['minf', 'stbl']);
  if (mdhd == null || stbl == null) return const [];
  final mdhdBody = _read(file, mdhd.body, 32);
  final timescale = ByteData.sublistView(mdhdBody).getUint32(mdhdBody[0] == 1 ? 20 : 12);
  if (timescale == 0) return const [];

  final starts = <int>[];
  final stts = _child(file, stbl, 'stts');
  if (stts != null) {
    final body = _read(file, stts.body, stts.end - stts.body);
    final view = ByteData.sublistView(body);
    var time = 0;
    for (var i = 0, entries = view.getUint32(4); i < entries && 16 + i * 8 <= body.length; i++) {
      final count = view.getUint32(8 + i * 8), delta = view.getUint32(12 + i * 8);
      for (var j = 0; j < count; j++) {
        starts.add(time);
        time += delta;
      }
    }
  }

  final sizes = <int>[];
  final stsz = _child(file, stbl, 'stsz');
  if (stsz != null) {
    final body = _read(file, stsz.body, stsz.end - stsz.body);
    final view = ByteData.sublistView(body);
    final fixed = view.getUint32(4), count = view.getUint32(8);
    for (var i = 0; i < count; i++) {
      sizes.add(fixed != 0 ? fixed : (12 + i * 4 + 4 <= body.length ? view.getUint32(12 + i * 4) : 0));
    }
  }

  final chunkOffsets = <int>[];
  final stco = _child(file, stbl, 'stco') ?? _child(file, stbl, 'co64');
  if (stco != null) {
    final body = _read(file, stco.body, stco.end - stco.body);
    final view = ByteData.sublistView(body);
    final wide = stco.type == 'co64';
    for (var i = 0, count = view.getUint32(4); i < count; i++) {
      chunkOffsets.add(wide ? view.getUint64(8 + i * 8) : view.getUint32(8 + i * 4));
    }
  }

  final runs = <(int firstChunk, int samplesPerChunk)>[];
  final stsc = _child(file, stbl, 'stsc');
  if (stsc != null) {
    final body = _read(file, stsc.body, stsc.end - stsc.body);
    final view = ByteData.sublistView(body);
    for (var i = 0, count = view.getUint32(4); i < count; i++) {
      runs.add((view.getUint32(8 + i * 12), view.getUint32(12 + i * 12)));
    }
  }

  // Each sample's file offset: walk the chunks, each holding the samples its run says.
  final offsets = <int>[];
  for (var chunk = 0; chunk < chunkOffsets.length && offsets.length < sizes.length; chunk++) {
    final run = runs.lastWhere((run) => run.$1 <= chunk + 1, orElse: () => (1, 1));
    var at = chunkOffsets[chunk];
    for (var s = 0; s < run.$2 && offsets.length < sizes.length; s++) {
      offsets.add(at);
      at += sizes[offsets.length - 1];
    }
  }

  final chapters = <MediaChapter>[];
  for (var i = 0; i < offsets.length && i < starts.length; i++) {
    final sample = _read(file, offsets[i], sizes[i]);
    if (sample.length < 2) continue;
    final textLength = ByteData.sublistView(sample).getUint16(0);
    final text = sample.length >= 2 + textLength ? utf8.decode(sample.sublist(2, 2 + textLength), allowMalformed: true) : '';
    chapters.add(MediaChapter(cleanText(text) ?? 'Chapter ${i + 1}', Duration(microseconds: starts[i] * 1000000 ~/ timescale)));
  }
  return chapters;
}

_Atom? _child(RandomAccessFile file, _Atom parent, String type) => _children(file, parent.body, parent.end).where((atom) => atom.type == type).firstOrNull;

_Atom? _path(RandomAccessFile file, _Atom from, List<String> types) {
  _Atom? at = from;
  for (final type in types) {
    if (at == null) return null;
    at = _child(file, at, type);
  }
  return at;
}
