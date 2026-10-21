/// Reads what a file carries before it is added, with no Flutter: title, author, length, chapters
/// and cover from MP4/M4B/M4A/MOV atoms, MP3 ID3v2 tags, and EPUB packages.
library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:arke_publication/arke_publication.dart';

import 'src/epub.dart';
import 'src/info.dart';
import 'src/mp3.dart';
import 'src/mp4.dart';

export 'src/info.dart';

/// Reads [path] as [format]. PDF and video posters need a renderer and are read by the app;
/// for them this returns what the container says (an MP4's length), or nothing.
///
/// Throws [UnreadableFile] when the file is not a well-formed instance of [format].
MediaInfo readMediaInfo(String path, FileFormat format) {
  switch (format) {
    case FileFormat.m4b || FileFormat.m4a || FileFormat.mp4 || FileFormat.mov:
      final file = File(path).openSync();
      try {
        return readMp4(file);
      } finally {
        file.closeSync();
      }
    case FileFormat.mp3:
      final file = File(path).openSync();
      try {
        return readMp3(file);
      } finally {
        file.closeSync();
      }
    case FileFormat.epub:
      final input = InputFileStream(path);
      try {
        return readEpub(ZipDecoder().decodeStream(input));
      } on UnreadableFile {
        rethrow;
      } on Exception catch (error) {
        throw UnreadableFile('not a readable EPUB: $error');
      } finally {
        input.closeSync();
      }
    case FileFormat.pdf || FileFormat.cbz || FileFormat.arkePackage || FileFormat.srt || FileFormat.vtt || FileFormat.listening:
      return const MediaInfo();
  }
}
