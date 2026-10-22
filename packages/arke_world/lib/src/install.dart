import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:arke_library/arke_library.dart';
import 'package:arke_media/arke_media.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:crypto/crypto.dart';

import 'catalogue.dart';
import 'manifest.dart';
import 'package.dart';

/// Where an install is (P9 rule 4): the download, then the check of every file.
sealed class InstallStep {
  const InstallStep();
}

class Downloading extends InstallStep {
  const Downloading(this.received, this.total);
  final int received;
  final int total;
}

/// A package added from a file being copied into the Player's own storage (P2d).
class Copying extends InstallStep {
  const Copying(this.copied, this.total);
  final int copied;
  final int total;
}

class Checking extends InstallStep {
  const Checking(this.checked, this.total);
  final int checked;
  final int total;
}

/// Why a world was not installed, in the one clause the sheet shows (P9 rule 5). Nothing partial
/// is kept after any of them.
sealed class InstallRefusal implements Exception {
  const InstallRefusal();
  String get clause;

  @override
  String toString() => clause;
}

class NoConnection extends InstallRefusal {
  const NoConnection();
  @override
  String get clause => 'No connection';
}

class DownloadStopped extends InstallRefusal {
  const DownloadStopped();
  @override
  String get clause => 'Download stopped';
}

class NeedsSpace extends InstallRefusal {
  const NeedsSpace(this.needed, this.free);
  final int needed;
  final int free;
  @override
  String get clause => 'Needs ${formatBytes(needed)} · ${formatBytes(free)} free';
}

class FilesDoNotMatch extends InstallRefusal {
  const FilesDoNotMatch(this.count);
  final int count;
  @override
  String get clause => count == 1 ? '1 file does not match' : '$count files do not match';
}

class NotAPackage extends InstallRefusal {
  const NotAPackage();
  @override
  String get clause => 'Not an Arke package';
}

class NewerArke extends InstallRefusal {
  const NewerArke();
  @override
  String get clause => 'Made with a newer Arke';
}

/// The person pressed Cancel: not a refusal, so no sheet.
class InstallCancelled extends InstallRefusal {
  const InstallCancelled();
  @override
  String get clause => '';
}

/// Cancel for one install. What has come is deleted (P9 rule 4).
class InstallCancel {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
  }

  void _whenCancelled(void Function() listener) => _listeners.add(listener);

  void _check() {
    if (_cancelled) throw const InstallCancelled();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Installs a world from Available (P9), in the order the rules bind:
///
/// 1. Check the space before the first byte. The download and what it unpacks to are both on the
///    phone until the download is deleted, so twice the package is needed.
/// 2. Download into a staging folder beside the installed worlds, hashing as it comes. Its length
///    and SHA-256 must be the catalogue's, which the app was built with.
/// 3. Read the package's directory and manifest ([readWorldPackage]) and refuse what is not a
///    world package, or one made with a newer Arke.
/// 4. Extract each file and check it against the manifest, as a package from a file is (P2 rule 6).
///    Nothing plays before every file matches.
/// 5. Read the book and the narration as an added file is read, then move the folder into place
///    and name the world and its items in one write of the library's index.
///
/// Every refusal, and Cancel, deletes the staging folder; a crash leaves one the library clears on
/// its next load.
class WorldInstaller {
  WorldInstaller({required this.store, required this.freeBytes, HttpClient Function()? httpClient, this.idle = const Duration(seconds: 60)})
    : _httpClient = httpClient ?? HttpClient.new;

  final LibraryStore store;
  final Future<int?> Function(String path) freeBytes;
  final HttpClient Function() _httpClient;

  /// A download that receives nothing for this long has stopped.
  final Duration idle;

  /// Space kept free beyond the world, as for an added file.
  static const reserve = 64 * 1000 * 1000;

  /// Progress is reported at most this often while downloading or copying.
  static const _progressStep = 256 * 1024;

  /// Installs a world from Available (P9): download, check, and add at once.
  Future<LibraryWorld> install(CatalogueWorld world, {void Function(InstallStep step)? onStep, InstallCancel? cancel}) async {
    final package = world.package;
    if (package == null) throw const NotAPackage();
    for (final installed in store.worlds) {
      if (installed.id == world.id) return installed;
    }
    final control = cancel ?? InstallCancel();
    final needed = await _checkSpace(package.byteLength);
    final staging = await store.stageWorld();
    try {
      final zip = '${staging.path}${Platform.pathSeparator}package.zip';
      await _download(package, zip, onStep, control);
      control._check();
      final prepared = await _prepare(zip, staging, needed, onStep, control);
      if (prepared.manifest.id != world.id) throw const NotAPackage();
      return await commit(prepared);
    } on FileSystemException catch (error) {
      throw await _full(error, needed);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Fetches a world's guide alone (SPEC-059 R-10, R-18) as a world is installed: its pin's length
  /// and SHA-256, then every file checked, then kept under `guides/` for reading offline. A guide
  /// already kept under the same pin is not fetched again.
  Future<LibraryGuide> fetchGuide(CatalogueWorld world, {InstallCancel? cancel}) async {
    final pin = world.guide;
    if (pin == null) throw const NotAPackage();
    for (final kept in store.guides) {
      if (kept.worldId == world.id && kept.sha256 == pin.sha256) return kept;
    }
    final control = cancel ?? InstallCancel();
    final needed = await _checkSpace(pin.byteLength);
    final staging = await store.stageGuide();
    try {
      final zip = '${staging.path}${Platform.pathSeparator}package.zip';
      await _download(pin, zip, null, control);
      control._check();
      final prepared = await _prepare(zip, staging, needed, null, control);
      final manifest = prepared.manifest;
      if (manifest.id != world.id || !manifest.isGuideAlone || manifest.guide == null) throw const NotAPackage();
      final guide = LibraryGuide(
        worldId: world.id,
        edition: manifest.edition,
        sha256: pin.sha256,
        guide: 'guides/${world.id}/${manifest.assets[manifest.guide]!.path}',
        fetchedAt: DateTime.now().toUtc(),
      );
      await store.addGuide(guide, prepared.content);
      return guide;
    } on FileSystemException catch (error) {
      throw await _full(error, needed);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Copies a world package a person added from a file (Player P2c) into staging and checks it in
  /// full (P2d), stopping before it joins the library: the caller shows Ready (P2e), Replace
  /// (P10a) or Already in Library (P10b), then [commit]s or [discard]s.
  Future<PreparedWorld> prepareFile({
    required int size,
    required Stream<List<int>> Function() open,
    void Function(InstallStep step)? onStep,
    InstallCancel? cancel,
  }) async {
    final control = cancel ?? InstallCancel();
    final needed = await _checkSpace(size);
    final staging = await store.stageWorld();
    try {
      final zip = '${staging.path}${Platform.pathSeparator}package.zip';
      final file = await File(zip).open(mode: FileMode.write);
      try {
        var copied = 0;
        var reported = 0;
        onStep?.call(Copying(0, size));
        await for (final chunk in open()) {
          control._check();
          copied += chunk.length;
          await file.writeFrom(chunk);
          if (copied - reported >= _progressStep) {
            reported = copied;
            onStep?.call(Copying(copied, size));
          }
        }
      } finally {
        await file.close();
      }
      control._check();
      return await _prepare(zip, staging, needed, onStep, control);
    } on FileSystemException catch (error) {
      if (await staging.exists()) await staging.delete(recursive: true);
      throw await _full(error, needed);
    } on Object {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  /// Adds a checked world to the library in one write, replacing an installed edition of it and
  /// keeping its places (P10 rule 3).
  Future<LibraryWorld> commit(PreparedWorld prepared) async {
    try {
      await store.addWorld(prepared.world, prepared.items, prepared.content);
      return prepared.world;
    } finally {
      if (await prepared.staging.exists()) await prepared.staging.delete(recursive: true);
    }
  }

  /// Deletes a checked world that was not added: closing Ready, or Cancel.
  Future<void> discard(PreparedWorld prepared) async {
    if (await prepared.staging.exists()) await prepared.staging.delete(recursive: true);
  }

  Future<int> _checkSpace(int packageBytes) async {
    // The package and what it unpacks to are both on the phone until the package is deleted.
    final needed = packageBytes * 2;
    final free = await freeBytes(store.root.parent.path);
    if (free != null && needed + reserve > free) throw NeedsSpace(needed, free);
    return needed;
  }

  /// ENOSPC (28) or ERROR_DISK_FULL (112): the space ran out after it was checked.
  Future<Object> _full(FileSystemException error, int needed) async {
    final code = error.osError?.errorCode;
    if (code == 28 || code == 112) return NeedsSpace(needed, await freeBytes(store.root.parent.path) ?? 0);
    return error;
  }

  Future<PreparedWorld> _prepare(String zip, Directory staging, int needed, void Function(InstallStep step)? onStep, InstallCancel control) async {
    final separator = Platform.pathSeparator;
    final WorldManifest manifest;
    try {
      manifest = await Isolate.run(() => readWorldPackage(zip));
    } on WorldPackageRefused catch (refused) {
      throw refused.refusal == WorldRefusal.newerArke ? const NewerArke() : const NotAPackage();
    }

    final content = Directory('${staging.path}${separator}world');
    final total = manifest.assets.length;
    var checked = 0;
    var failed = 0;
    onStep?.call(Checking(0, total));
    for (final asset in manifest.assets.values) {
      control._check();
      final to = '${content.path}$separator${asset.path.replaceAll('/', separator)}';
      if (await Isolate.run(() => extractAsset(zip, asset, to)) != AssetCheck.matches) failed++;
      onStep?.call(Checking(++checked, total));
    }
    if (failed > 0) throw FilesDoNotMatch(failed);
    await File(zip).delete();
    // The manifest goes with the world, so a player can read a listening document against it.
    await File('${content.path}$separator$worldManifestFile').writeAsString(jsonEncode(manifest.toJson()), flush: true);

    final (world, items) = await _describe(manifest, content);
    control._check();
    final installed = store.worlds.where((existing) => existing.id == world.id).firstOrNull;
    return PreparedWorld(manifest: manifest, world: world, items: items, content: content, staging: staging, installed: installed);
  }

  Future<void> _download(CataloguePackage package, String to, void Function(InstallStep step)? onStep, InstallCancel cancel) async {
    final client = _httpClient()..connectionTimeout = const Duration(seconds: 20);
    cancel._whenCancelled(() => client.close(force: true));
    final file = await File(to).open(mode: FileMode.write);
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    try {
      final HttpClientResponse response;
      try {
        response = await (await client.getUrl(package.url)).close();
      } on Object {
        cancel._check();
        throw const NoConnection();
      }
      if (response.statusCode != HttpStatus.ok) throw const DownloadStopped();
      onStep?.call(Downloading(0, package.byteLength));
      var received = 0;
      var reported = 0;
      try {
        await for (final chunk in response.timeout(idle)) {
          received += chunk.length;
          // More than the catalogue says is not the package the app was built to expect.
          if (received > package.byteLength) throw const FilesDoNotMatch(1);
          hasher.add(chunk);
          await file.writeFrom(chunk);
          if (received - reported >= _progressStep) {
            reported = received;
            onStep?.call(Downloading(received, package.byteLength));
          }
        }
      } on InstallRefusal {
        rethrow;
      } on FileSystemException {
        rethrow;
      } on Object {
        cancel._check();
        throw const DownloadStopped();
      }
      cancel._check();
      if (received < package.byteLength) throw const DownloadStopped();
      onStep?.call(Downloading(received, package.byteLength));
      hasher.close();
      if (digest.value.toString() != package.sha256) throw const FilesDoNotMatch(1);
    } finally {
      await file.close();
      client.close(force: true);
    }
  }

  /// Reads each production's book and narration as an added file is read (P7 rule 3), and names
  /// them as library items under the world's folder. A listening document becomes one item whose
  /// chapters are the document's, back to back.
  Future<(LibraryWorld, List<LibraryItem>)> _describe(WorldManifest manifest, Directory content) async {
    final separator = Platform.pathSeparator;
    final base = 'worlds/${manifest.id}';
    String stored(WorldAsset asset) => '$base/${asset.path}';
    final keyArt = manifest.keyArt == null ? null : stored(manifest.assets[manifest.keyArt]!);
    final now = DateTime.now().toUtc();
    final items = <LibraryItem>[];
    final productions = <LibraryProduction>[];
    var coverBytes = 0;

    for (final production in manifest.productions) {
      final picture = production.picture == null ? null : stored(manifest.assets[production.picture]!);
      String? bookId;
      String? narrationId;

      final document = manifest.listening[production.id];
      if (document != null) {
        final id = '${manifest.id}.${production.id}.listening';
        final starts = document.starts;
        final cover = document.cover == null ? null : stored(manifest.assets[document.cover]!);
        items.add(
          LibraryItem(
            id: id,
            format: FileFormat.listening,
            title: production.title,
            author: production.author,
            duration: document.duration,
            byteLength: {production.listening!, ...document.assetIds}.fold(0, (sum, assetId) => sum + manifest.assets[assetId]!.byteLength),
            addedAt: now,
            file: stored(manifest.assets[production.listening]!),
            cover: picture ?? cover ?? keyArt,
            chapters: [for (final (i, chapter) in document.chapters.indexed) Chapter(title: chapter.title, start: starts[i])],
            worldId: manifest.id,
          ),
        );
        narrationId = id;
      }

      for (final (role, assetId) in [('narration', production.narration), ('book', production.book)]) {
        if (assetId == null) continue;
        final asset = manifest.assets[assetId]!;
        final format = role == 'book' ? bookMediaTypes[asset.mediaType]! : narrationMediaTypes[asset.mediaType]!;
        final path = '${content.path}$separator${asset.path.replaceAll('/', separator)}';
        final MediaInfo info;
        try {
          info = await Isolate.run(() => readMediaInfo(path, format));
        } on UnreadableFile {
          throw const NotAPackage();
        }
        if (info.protectedFile) throw const NotAPackage();

        final id = '${manifest.id}.${production.id}.$role';
        var cover = picture;
        if (cover == null && info.cover != null) {
          // A package path never starts with `_`, so these never collide with the package's own.
          final name = '_covers/$id.${info.cover!.extension}';
          final file = File('${content.path}$separator${name.replaceAll('/', separator)}');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(info.cover!.bytes, flush: true);
          coverBytes += info.cover!.bytes.length;
          cover = '$base/$name';
        }
        items.add(
          LibraryItem(
            id: id,
            format: format,
            title: production.title,
            author: production.author ?? info.author,
            duration: info.duration,
            byteLength: asset.byteLength,
            addedAt: now,
            file: stored(asset),
            cover: cover ?? keyArt,
            chapters: [for (final chapter in info.chapters) Chapter(title: chapter.title, start: chapter.start)],
            worldId: manifest.id,
          ),
        );
        if (role == 'book') {
          bookId = id;
        } else {
          narrationId = id;
        }
      }
      productions.add(
        LibraryProduction(id: production.id, title: production.title, author: production.author, picture: picture, book: bookId, narration: narrationId),
      );
    }

    final world = LibraryWorld(
      id: manifest.id,
      edition: manifest.edition,
      name: manifest.name,
      logline: manifest.logline,
      keyArt: keyArt,
      byteLength: manifest.assets.values.fold(coverBytes, (sum, asset) => sum + asset.byteLength),
      installedAt: now,
      productions: List.unmodifiable(productions),
      fingerprint: editionFingerprint(manifest),
      guide: manifest.guide == null ? null : stored(manifest.assets[manifest.guide]!),
    );
    return (world, items);
  }
}

/// Two packages are one edition when their edition labels and every file's SHA-256 agree (P10
/// rule 2); this is that, as one digest.
String editionFingerprint(WorldManifest manifest) {
  final lines = [manifest.edition, ...(manifest.assets.values.map((asset) => '${asset.path} ${asset.sha256}').toList()..sort())];
  return sha256.convert(utf8.encode(lines.join('\n'))).toString();
}

/// A world package checked in full and waiting in staging (P2e, P10): added by
/// [WorldInstaller.commit], or deleted by [WorldInstaller.discard].
class PreparedWorld {
  const PreparedWorld({required this.manifest, required this.world, required this.items, required this.content, required this.staging, this.installed});

  final WorldManifest manifest;
  final LibraryWorld world;
  final List<LibraryItem> items;
  final Directory content;
  final Directory staging;

  /// The edition of this world already in Library, if any.
  final LibraryWorld? installed;

  /// The same edition is refused (P10b); another offers Replace (P10a).
  bool get sameEdition => installed != null && installed!.fingerprint == world.fingerprint;
}
