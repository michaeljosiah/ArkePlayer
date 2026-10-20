import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:arke_publication/arke_publication.dart';

import 'manifest.dart';

/// A world package refused before anything in it was used.
class WorldPackageRefused implements Exception {
  const WorldPackageRefused(this.refusal, this.reason);

  final WorldRefusal refusal;

  /// For a log, never the screen.
  final String reason;

  @override
  String toString() => 'WorldPackageRefused($refusal: $reason)';
}

const _maxManifestBytes = 1024 * 1024;
const _stored = 0;

/// Reads a downloaded world package's directory and manifest before any file in it is used,
/// refusing what SPEC-048 R-14 asks a reader to refuse: absolute paths, traversal, backslashes,
/// symbolic links, duplicate entries after case folding, and any file the manifest does not name.
///
/// Assets must be stored, not compressed. Media is compressed already, and a stored entry is
/// exactly as long as its directory says, so a package can never unpack to more than it declared.
///
/// Synchronous: call it off the UI isolate.
WorldManifest readWorldPackage(String zipPath) {
  WorldPackageRefused notAPackage(String reason) => WorldPackageRefused(WorldRefusal.notAPackage, reason);

  final input = InputFileStream(zipPath);
  try {
    final decoder = ZipDecoder();
    final Archive archive;
    try {
      archive = decoder.decodeStream(input);
    } on Object {
      throw notAPackage('not a ZIP');
    }
    final seen = <String>{};
    final methods = <String, int>{};
    for (final header in decoder.directory.fileHeaders) {
      final name = header.filename;
      if ((header.externalFileAttributes >> 16) & 0xF000 == 0xA000) throw notAPackage('symbolic link $name');
      if (name.contains(r'\') || name.startsWith('/') || name.contains(':')) throw notAPackage('path $name');
      final isDirectory = name.endsWith('/');
      final segments = (isDirectory ? name.substring(0, name.length - 1) : name).split('/');
      if (segments.any((segment) => segment.isEmpty || segment == '.' || segment == '..')) throw notAPackage('path $name');
      // The decoder keeps the first of two entries with one name; a package is refused instead.
      if (!seen.add(name.toLowerCase())) throw notAPackage('duplicate $name');
      if (!isDirectory) methods[name] = header.compressionMethod;
    }

    final manifestEntry = archive.find(worldManifestFile);
    if (manifestEntry == null || !manifestEntry.isFile || manifestEntry.size > _maxManifestBytes) throw notAPackage('no $worldManifestFile');
    final String text;
    try {
      text = utf8.decode(manifestEntry.readBytes() ?? const <int>[]);
    } on FormatException {
      throw notAPackage('$worldManifestFile is not UTF-8');
    }
    final manifest = switch (readWorldManifest(text)) {
      WorldManifestOk(:final manifest) => manifest,
      WorldManifestRefused(:final refusal, :final reason) => throw WorldPackageRefused(refusal, reason),
    };

    final named = {for (final asset in manifest.assets.values) asset.path};
    final extra = methods.keys.where((name) => name != worldManifestFile && !named.contains(name));
    if (extra.isNotEmpty) throw notAPackage('files the manifest does not name: ${extra.take(3).join(', ')}');
    final compressed = named.where((path) => methods.containsKey(path) && methods[path] != _stored);
    if (compressed.isNotEmpty) throw notAPackage('compressed assets: ${compressed.take(3).join(', ')}');
    return manifest;
  } finally {
    input.closeSync();
  }
}

/// Extracts one asset of a package [readWorldPackage] accepted to [to], then checks its bytes
/// against the manifest. An asset the package lacks, or whose stored size is not its declared
/// length, is not extracted at all.
Future<AssetCheck> extractAsset(String zipPath, WorldAsset asset, String to) async {
  final input = InputFileStream(zipPath);
  try {
    final entry = ZipDecoder().decodeStream(input).find(asset.path);
    if (entry == null || !entry.isFile) return AssetCheck.missing;
    if (entry.size != asset.byteLength) return AssetCheck.wrongLength;
    await File(to).parent.create(recursive: true);
    final output = OutputFileStream(to);
    try {
      entry.writeContent(output);
    } finally {
      await output.close();
    }
  } finally {
    input.closeSync();
  }
  return checkAsset(asset.asPublicationAsset, () => File(to).openRead());
}
