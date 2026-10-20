import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:arke_library/arke_library.dart';
import 'package:arke_media/arke_media.dart';
import 'package:arke_publication/arke_publication.dart';

import '../domain/added_file.dart';

/// What a PDF says about itself, read by a renderer the app supplies: its pages, a picture of
/// the first, and whether it needs a password (DRM).
class PdfFacts {
  const PdfFacts({required this.pages, this.firstPage, this.protectedFile = false});

  final int pages;
  final Uint8List? firstPage;
  final bool protectedFile;
}

abstract interface class PdfPeek {
  /// Throws when the file is not a PDF a renderer can open.
  Future<PdfFacts> peek(String path);
}

/// Brings picked files into the library, in the order the design binds (P7 rule 3):
///
/// 1. Recognise the file from its first bytes and name (`probeFile`); refuse what is not an MVP
///    format in one clause.
/// 2. Check the space before copying, and refuse a file that would not fit with both numbers.
/// 3. Copy it into a reserved folder of the library, the Player's own copy.
/// 4. Open it and read what it carries (`readMediaInfo`, or the PDF renderer); refuse DRM and what
///    cannot be opened, deleting the copy.
///
/// Nothing joins the library until [add]: a read file waits in its reserved folder, and [discard]
/// deletes it. A crash between the two leaves a folder the index does not name, which the
/// library clears on its next load.
class FileImporter {
  FileImporter({required this.store, required this.freeBytes, required this.pdf});

  final LibraryStore store;
  final Future<int?> Function(String path) freeBytes;
  final PdfPeek pdf;

  /// Space kept free beyond the file itself, so a full phone is never the Player's doing.
  static const reserve = 64 * 1000 * 1000;

  static const _videoFormats = {FileFormat.mp4, FileFormat.mov};

  Future<List<AddCandidate>> read(List<PickedFile> picked, {void Function(int done, int total)? onProgress}) async {
    final probes = <PickedFile, Probe>{};
    for (final file in picked) {
      probes[file] = await _probe(file);
    }
    // Captions travel with the film of the same name (P7 rule 1), never on their own.
    String base(String name) => name.contains('.') ? name.substring(0, name.lastIndexOf('.')).toLowerCase() : name.toLowerCase();
    final captionsFor = <String, PickedFile>{};
    for (final MapEntry(key: file, value: probe) in probes.entries) {
      if (probe is ProbeFormat && probe.format.isSidecar) captionsFor[base(file.name)] = file;
    }

    final candidates = <AddCandidate>[];
    var done = 0;
    for (final MapEntry(key: file, value: probe) in probes.entries) {
      if (probe is ProbeFormat && probe.format.isSidecar) {
        final hasFilm = probes.entries.any(
          (entry) =>
              entry.key != file &&
              base(entry.key.name) == base(file.name) &&
              entry.value is ProbeFormat &&
              _videoFormats.contains((entry.value as ProbeFormat).format),
        );
        if (!hasFilm) candidates.add(Refused(file.name, Refused.captionsAlone));
      } else {
        candidates.add(await _readOne(file, probe, captionsFor[base(file.name)]));
      }
      onProgress?.call(++done, probes.length);
    }
    return candidates;
  }

  /// Adds what was read. Returns how many joined the library.
  Future<int> add(List<AddCandidate> candidates) async {
    final readable = candidates.whereType<Readable>().toList();
    for (final candidate in readable.reversed) {
      await store.add(candidate.item);
    }
    return readable.length;
  }

  /// Deletes the copies of files that were read but not added.
  Future<void> discard(List<AddCandidate> candidates) async {
    for (final candidate in candidates.whereType<Readable>()) {
      await store.discard(candidate.item.id);
    }
  }

  Future<Probe> _probe(PickedFile file) async {
    final head = BytesBuilder(copy: false);
    try {
      await for (final chunk in file.open()) {
        head.add(chunk);
        if (head.length >= 256) break;
      }
    } on Object {
      return const ProbeRefused(ProbeRefusal.cannotOpen, 'unreadable');
    }
    return probeFile(head.takeBytes(), name: file.name);
  }

  static Future<void> _copy(PickedFile file, String to) async {
    final sink = File(to).openWrite();
    try {
      await sink.addStream(file.open());
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<AddCandidate> _readOne(PickedFile file, Probe probe, PickedFile? captions) async {
    if (probe is ProbeRefused) {
      return Refused(file.name, switch (probe.refusal) {
        ProbeRefusal.protectedFile => Refused.protectedFile,
        ProbeRefusal.cannotOpen => Refused.cannotOpen,
        ProbeRefusal.notSupported => Refused.notSupported,
      });
    }
    final format = (probe as ProbeFormat).format;
    if (format == FileFormat.arkePackage) return Refused(file.name, Refused.packageLater);
    if (format == FileFormat.cbz) return Refused(file.name, Refused.notSupported);

    final needed = file.size + (captions?.size ?? 0);
    final free = await freeBytes(store.root.parent.path);
    if (free != null && needed + reserve > free) return Refused(file.name, Refused.needsSpace(needed, free));

    final id = await store.reserve();
    try {
      final folder = store.itemDirectory(id);
      final stored = 'media.${_extension(file.name, format)}';
      await _copy(file, '${folder.path}${Platform.pathSeparator}$stored');
      String? captionsPath;
      if (captions != null) {
        captionsPath = 'captions.${_extension(captions.name, FileFormat.vtt)}';
        await _copy(captions, '${folder.path}${Platform.pathSeparator}$captionsPath');
      }
      final copied = '${folder.path}${Platform.pathSeparator}$stored';

      MediaInfo info;
      int? pages;
      Uint8List? coverBytes;
      var coverExtension = 'jpg';
      if (format == FileFormat.pdf) {
        final facts = await pdf.peek(copied);
        if (facts.protectedFile) {
          await store.discard(id);
          return Refused(file.name, Refused.protectedFile);
        }
        pages = facts.pages;
        coverBytes = facts.firstPage;
        coverExtension = 'png';
        info = const MediaInfo();
      } else {
        info = await Isolate.run(() => readMediaInfo(copied, format));
        if (info.protectedFile) {
          await store.discard(id);
          return Refused(file.name, Refused.protectedFile);
        }
        coverBytes = info.cover?.bytes;
        coverExtension = info.cover?.extension ?? 'jpg';
      }

      String? cover;
      if (coverBytes != null && coverBytes.isNotEmpty) {
        cover = 'cover.$coverExtension';
        await File('${folder.path}${Platform.pathSeparator}$cover').writeAsBytes(coverBytes, flush: true);
      }

      final relative = 'items/$id';
      return Readable(
        file.name,
        LibraryItem(
          id: id,
          format: format,
          title: info.title ?? _titleFromName(file.name),
          author: info.author,
          duration: info.duration,
          pages: pages,
          byteLength: needed,
          addedAt: DateTime.now().toUtc(),
          file: '$relative/$stored',
          cover: cover == null ? null : '$relative/$cover',
          captions: captionsPath == null ? null : '$relative/$captionsPath',
          chapters: [for (final chapter in info.chapters) Chapter(title: chapter.title, start: chapter.start)],
        ),
      );
    } on UnreadableFile {
      await store.discard(id);
      return Refused(file.name, Refused.cannotOpen);
    } on FileSystemException catch (error) {
      await store.discard(id);
      // ENOSPC mid-copy: the space ran out after it was checked.
      final full = error.osError?.errorCode == 28 || error.osError?.errorCode == 112;
      return Refused(file.name, full ? Refused.needsSpace(needed, await freeBytes(store.root.parent.path) ?? 0) : Refused.cannotOpen);
    } on Object {
      await store.discard(id);
      return Refused(file.name, Refused.cannotOpen);
    }
  }

  static String _extension(String name, FileFormat format) {
    final dot = name.lastIndexOf('.');
    final given = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(given) ? given : format.name;
  }

  /// A file with no title of its own is named by its file name, without the extension.
  static String _titleFromName(String name) {
    final dot = name.lastIndexOf('.');
    final stem = (dot > 0 ? name.substring(0, dot) : name).replaceAll(RegExp(r'[_]+'), ' ').trim();
    return stem.isEmpty ? name : stem;
  }
}
