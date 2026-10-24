import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'catalogue.dart';

/// The kinds of picture a pin may bring, by the bytes they start with, and the extension each is
/// kept under.
enum PictureType {
  jpeg('jpg'),
  png('png'),
  webp('webp');

  const PictureType(this.extension);
  final String extension;
}

/// What [head], a file's first bytes, says it is: JPEG, PNG or WebP, or none of them.
PictureType? pictureTypeOf(List<int> head) {
  bool startsWith(List<int> magic, [int at = 0]) {
    if (head.length < at + magic.length) return false;
    for (var index = 0; index < magic.length; index++) {
      if (head[at + index] != magic[index]) return false;
    }
    return true;
  }

  if (startsWith(const [0xff, 0xd8, 0xff])) return PictureType.jpeg;
  if (startsWith(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return PictureType.png;
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) return PictureType.webp;
  return null;
}

/// Every picture a list names under `pins` (SPEC-058 rev 10), one per digest.
List<PicturePin> pinsOf(Iterable<CatalogueWorld> worlds) {
  final byDigest = <String, PicturePin>{};
  for (final world in worlds) {
    for (final pin in [
      world.keyArtPin,
      for (final production in world.productions) ...[production.picturePin, production.tallPin],
    ]) {
      if (pin != null) byDigest.putIfAbsent(pin.sha256, () => pin);
    }
  }
  return List.unmodifiable(byDigest.values);
}

/// Why a file cannot be pinned as a picture.
class PictureRefused implements Exception {
  const PictureRefused(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

/// The pin for a picture published at [url], as `pin_picture` prints it: its address, length and
/// SHA-256. Refuses a file that is not JPEG, PNG or WebP, one over [PicturePin.maxBytes], and an
/// address that is not HTTPS.
Future<Map<String, Object>> pinPicture(File file, Uri url) async {
  if (url.scheme != 'https' || url.host.isEmpty) throw const PictureRefused('a picture is published over HTTPS');
  final length = await file.length();
  if (length <= 0) throw const PictureRefused('the file is empty');
  if (length > PicturePin.maxBytes) throw const PictureRefused('larger than 4 MiB; a picture for a row is far smaller');
  final head = await file.openRead(0, 16).fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
  if (pictureTypeOf(head) == null) throw const PictureRefused('not a JPEG, PNG or WebP picture');
  final digest = await sha256.bind(file.openRead()).first;
  return {'url': url.toString(), 'byteLength': length, 'sha256': digest.toString()};
}

/// The pictures Arke's list names, kept on the phone (SPEC-058 rev 10). Each is fetched once, checked
/// by its length, its SHA-256 and the bytes it starts with, and kept as `<sha256>.<extension>`, so a
/// kept file is the one its pin names or it is not there at all. Nothing outside [folder] is touched.
class PictureKeeper {
  PictureKeeper({required this.folder, HttpClient Function()? httpClient}) : _httpClient = httpClient ?? HttpClient.new;

  final Directory folder;
  final HttpClient Function() _httpClient;

  static const _timeout = Duration(seconds: 30);
  static final _keptName = RegExp(r'^([a-f0-9]{64})\.(jpg|png|webp)$');
  static final _partName = RegExp(r'^[a-f0-9]{64}\.part$');

  String _nameOf(FileSystemEntity entity) => entity.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);

  /// The pictures kept, by digest.
  Future<Map<String, File>> kept() async {
    if (!await folder.exists()) return const {};
    return {
      await for (final entity in folder.list(followLinks: false))
        if (entity is File)
          if (_keptName.firstMatch(_nameOf(entity)) case final match?) match.group(1)!: entity,
    };
  }

  /// Deletes every kept picture [named] does not name, and any download left half done. Only the
  /// files this keeper writes are looked at; anything else in the folder is left alone.
  Future<void> prune(Iterable<PicturePin> named) async {
    if (!await folder.exists()) return;
    final wanted = {for (final pin in named) pin.sha256};
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = _nameOf(entity);
      final match = _keptName.firstMatch(name);
      final stale = match != null ? !wanted.contains(match.group(1)) : _partName.hasMatch(name);
      if (stale) await _delete(entity);
    }
  }

  /// Fetches [pin] and keeps it, or returns null and keeps nothing: a picture that does not arrive, or
  /// arrives as other bytes, is simply not there yet, and the next fetch tries again.
  Future<File?> fetch(PicturePin pin) async {
    await folder.create(recursive: true);
    final part = File('${folder.path}${Platform.pathSeparator}${pin.sha256}.part');
    final client = _httpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(pin.url).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>().catchError((Object _) {});
        return null;
      }
      final sink = part.openWrite();
      var received = 0;
      var tooLong = false;
      try {
        await for (final chunk in response.timeout(_timeout)) {
          received += chunk.length;
          if (received > pin.byteLength) {
            tooLong = true;
            break;
          }
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      if (tooLong || received != pin.byteLength) return await _refuse(part);
      final head = await part.openRead(0, 16).fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
      final type = pictureTypeOf(head);
      if (type == null) return await _refuse(part);
      final digest = await sha256.bind(part.openRead()).first;
      if (digest.toString() != pin.sha256) return await _refuse(part);
      // Renamed only once checked, so a kept name always holds the bytes it names.
      return await part.rename('${folder.path}${Platform.pathSeparator}${pin.sha256}.${type.extension}');
    } on Object {
      await _delete(part);
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Keeps what [pins] names: first deletes what no list names any more, then fetches each picture
  /// not yet kept, one at a time, telling [onKept] as each arrives. [stopped] ends it between
  /// pictures, when a newer list has started its own.
  Future<void> keep(Iterable<PicturePin> pins, {void Function(PicturePin pin, File file)? onKept, bool Function()? stopped}) async {
    final named = pins.toList();
    await prune(named);
    final have = await kept();
    for (final pin in named) {
      if (stopped?.call() ?? false) return;
      if (have.containsKey(pin.sha256)) continue;
      final file = await fetch(pin);
      if (file != null) onKept?.call(pin, file);
    }
  }

  Future<File?> _refuse(File part) async {
    await _delete(part);
    return null;
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Windows may still hold it; the next prune takes it.
    }
  }
}
