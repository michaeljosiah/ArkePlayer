import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:arke_media/arke_media.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:crypto/crypto.dart';

import 'catalogue.dart';
import 'listening.dart';
import 'manifest.dart';

/// A production to pack: its book (EPUB), its narration (M4B, M4A or MP3) or both, and a 16:9
/// picture. Paths are files on this machine.
///
/// Instead of one narration file it may carry [listening]: a listening document as an author writes
/// it (SPEC-058 R-10), times in milliseconds and files where the package has asset ids. The packer
/// gives each file its id and path, and each picture ships once.
class ProductionSpec {
  const ProductionSpec({required this.id, required this.title, this.author, this.picture, this.book, this.narration, this.listening});

  final String id;
  final String title;
  final String? author;
  final String? picture;
  final String? book;
  final String? narration;
  final Map<String, Object?>? listening;
}

/// A world to pack, as its author published it.
class WorldSpec {
  const WorldSpec({required this.id, required this.edition, required this.name, required this.productions, this.logline, this.keyArt});

  final String id;
  final String edition;
  final String name;
  final String? logline;
  final String? keyArt;
  final List<ProductionSpec> productions;

  /// Reads a spec file; relative paths in it are relative to the file.
  static WorldSpec fromJson(Map<String, Object?> json, {String base = '.'}) {
    String? path(Object? value) => value is String ? (File(value).isAbsolute ? value : '$base${Platform.pathSeparator}$value') : null;
    // A listening document's files are relative to the spec too.
    Object? resolved(Object? value, String key) => switch (value) {
      Map<String, Object?>() => {for (final MapEntry(key: k, value: v) in value.entries) k: resolved(v, k)},
      List<Object?>() => [for (final v in value) resolved(v, key)],
      String() when const {'audio', 'picture', 'tall', 'opening', 'cover', 'video'}.contains(key) => path(value),
      _ => value,
    };
    return WorldSpec(
      id: json['id']! as String,
      edition: json['edition']! as String,
      name: json['name']! as String,
      logline: json['logline'] as String?,
      keyArt: path(json['keyArt']),
      productions: [
        for (final raw in json['productions']! as List<Object?>)
          if (raw is Map<String, Object?>)
            ProductionSpec(
              id: raw['id']! as String,
              title: raw['title']! as String,
              author: raw['author'] as String?,
              picture: path(raw['picture']),
              book: path(raw['book']),
              narration: path(raw['narration']),
              listening: raw['listening'] is Map<String, Object?> ? resolved(raw['listening'], 'listening')! as Map<String, Object?> : null,
            ),
      ],
    );
  }
}

/// What [packWorld] wrote: the package's own length and digest, which the app's catalogue pins,
/// and the catalogue entry to paste into `assets/worlds/catalogue.json`.
class PackedWorld {
  const PackedWorld({required this.manifest, required this.byteLength, required this.sha256, required this.catalogueEntry});

  final WorldManifest manifest;
  final int byteLength;
  final String sha256;
  final Map<String, Object?> catalogueEntry;
}

const _mediaTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'epub': 'application/epub+zip',
  'm4b': 'audio/mp4',
  'm4a': 'audio/mp4',
  'mp3': 'audio/mpeg',
  'mp4': 'video/mp4',
};

/// Writes a world package — `world.json` and its files, stored, not compressed — to [outZip].
/// It reads its own manifest back through [readWorldManifest] before writing, so the packer can
/// never make a package the Player refuses. [url] is where the package will be published.
Future<PackedWorld> packWorld(WorldSpec spec, String outZip, {String url = 'https://'}) async {
  final assets = <String, WorldAsset>{};
  final sources = <String, String>{};
  Future<String> add(String assetId, String file, String stem, {String? mediaType, String? extension}) async {
    extension ??= file.split('.').last.toLowerCase();
    mediaType ??= _mediaTypes[extension] ?? (throw ArgumentError('$file: not a JPEG, PNG, EPUB, M4B, M4A, MP3 or MP4'));
    final source = File(file);
    final digest = await sha256.bind(source.openRead()).first;
    final path = '$stem.$extension';
    assets[assetId] = WorldAsset(path: path, mediaType: mediaType, byteLength: await source.length(), sha256: digest.toString());
    sources[path] = file;
    return assetId;
  }

  final keyArt = spec.keyArt == null ? null : await add('key-art', spec.keyArt!, 'key-art');
  final productions = <WorldProduction>[];
  final kinds = <String>[];
  for (final production in spec.productions) {
    final picture = production.picture == null ? null : await add('${production.id}-picture', production.picture!, '${production.id}/picture');
    final book = production.book == null ? null : await add('${production.id}-book', production.book!, '${production.id}/book');
    final narration = production.narration == null ? null : await add('${production.id}-narration', production.narration!, '${production.id}/narration');
    String? listening;
    Duration? length;
    if (production.listening != null) {
      final (document, total) = await _listening(production.id, production.listening!, add);
      final file = '${Directory.systemTemp.createTempSync('arke-listening-').path}${Platform.pathSeparator}listening.json';
      await File(file).writeAsString(const JsonEncoder.withIndent('  ').convert(document));
      listening = await add('${production.id}-listening', file, '${production.id}/listening', mediaType: listeningMediaType, extension: 'json');
      length = total;
    } else if (production.narration != null) {
      length = readMediaInfo(production.narration!, _audioFormat(production.narration!)).duration;
    }
    productions.add(
      WorldProduction(
        id: production.id,
        title: production.title,
        author: production.author,
        picture: picture,
        book: book,
        narration: narration,
        listening: listening,
      ),
    );
    kinds.add(productionKind(book: book != null, narration: narration != null || listening != null, length: length));
  }
  final manifest = WorldManifest(
    id: spec.id,
    edition: spec.edition,
    name: spec.name,
    logline: spec.logline,
    keyArt: keyArt,
    productions: productions,
    assets: assets,
    // Schema 1 while it suffices, so a Player that reads only schema 1 still opens it.
    schemaVersion: productions.any((production) => production.listening != null) ? 2 : 1,
  );
  final text = const JsonEncoder.withIndent('  ').convert(manifest.toJson());
  if (readWorldManifest(text) case WorldManifestRefused(:final reason)) throw StateError('the packer made a manifest the Player refuses: $reason');

  // Every entry is stored: the encoder deflates unless an entry says otherwise, whatever level it
  // is given, and the Player refuses compressed assets.
  final encoder = ZipFileEncoder()..create(outZip, level: ZipFileEncoder.store);
  encoder.addArchiveFile(ArchiveFile.bytes(worldManifestFile, utf8.encode(text))..compression = CompressionType.none);
  final inputs = <InputFileStream>[];
  for (final MapEntry(key: path, value: file) in sources.entries) {
    final input = InputFileStream(file);
    inputs.add(input);
    encoder.addArchiveFile(ArchiveFile.stream(path, input)..compression = CompressionType.none);
  }
  await encoder.close();
  for (final input in inputs) {
    await input.close();
  }

  final zip = File(outZip);
  final digest = (await sha256.bind(zip.openRead()).first).toString();
  final byteLength = await zip.length();
  String bundled(String? file, String name) => file == null ? '' : 'assets/worlds/${spec.id}/$name.${file.split('.').last.toLowerCase()}';
  return PackedWorld(
    manifest: manifest,
    byteLength: byteLength,
    sha256: digest,
    catalogueEntry: {
      'id': spec.id,
      'name': spec.name,
      if (spec.logline != null) 'logline': spec.logline,
      if (spec.keyArt != null) 'keyArt': bundled(spec.keyArt, 'key-art'),
      'productions': [
        for (final (i, production) in spec.productions.indexed)
          {'title': production.title, 'kind': kinds[i], if (production.picture != null) 'picture': bundled(production.picture, production.id)},
      ],
      'package': {'url': url, 'byteLength': byteLength, 'sha256': digest},
    },
  );
}

FileFormat _audioFormat(String file) => file.toLowerCase().endsWith('.mp3') ? FileFormat.mp3 : FileFormat.m4b;

/// Turns an authored listening document (times in milliseconds, files by path) into the package's
/// (ticks at 1000 a second, files by asset id), adding each file once. A chapter with no
/// `duration` is measured from its audio. Returns the document and the narration's whole length.
Future<(Map<String, Object?>, Duration)> _listening(
  String productionId,
  Map<String, Object?> authored,
  Future<String> Function(String assetId, String file, String stem, {String? mediaType, String? extension}) add,
) async {
  final byFile = <String, String>{};
  var pictures = 0;
  var motions = 0;
  Future<String> once(String file, String Function() idAndStem) async {
    final known = byFile[file];
    if (known != null) return known;
    final stem = idAndStem();
    return byFile[file] = await add(stem.replaceAll('/', '-'), file, stem);
  }

  Future<String> picture(String file) => once(file, () => '$productionId/pictures/p${(++pictures).toString().padLeft(3, '0')}');
  var total = Duration.zero;
  final chapters = <Map<String, Object?>>[];
  for (final (i, raw) in (authored['chapters']! as List<Object?>).indexed) {
    final chapter = raw! as Map<String, Object?>;
    final audio = chapter['audio']! as String;
    final duration = chapter['duration'] as int? ?? readMediaInfo(audio, FileFormat.m4a).duration?.inMilliseconds;
    if (duration == null) throw ArgumentError('$audio: no length');
    total += Duration(milliseconds: duration);
    final order = chapter['order'] as int? ?? i + 1;
    chapters.add({
      'id': chapter['id'],
      'order': order,
      'title': chapter['title'],
      'duration': duration,
      'audio': await once(audio, () => '$productionId/audio/ch${order.toString().padLeft(2, '0')}'),
      if (chapter['book'] != null) 'book': chapter['book'],
      if (chapter['opening'] != null) 'opening': await picture(chapter['opening']! as String),
      'pictures': [
        for (final p in (chapter['pictures'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
          {
            'at': p['at'],
            if (p['hold'] != null) 'hold': p['hold'],
            'picture': await picture(p['picture']! as String),
            // The same moment at 9:16 (SPEC-058 R-37).
            if (p['tall'] != null) 'tall': await picture(p['tall']! as String),
            if (p['focus'] != null) 'focus': p['focus'],
            if (p['motion'] case final Map<String, Object?> motion)
              'motion': {
                'video': await once(motion['video']! as String, () => '$productionId/motion/m${(++motions).toString().padLeft(3, '0')}'),
                'behavior': motion['behavior'],
              },
          },
      ],
      if (chapter['phrases'] != null) 'phrases': chapter['phrases'],
    });
  }
  return (
    {
      'format': listeningFormat,
      'version': listeningVersion,
      'timescale': 1000,
      'title': authored['title'],
      if (authored['cover'] != null) 'cover': await picture(authored['cover']! as String),
      'chapters': chapters,
    },
    total,
  );
}
