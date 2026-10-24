import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:arke_library/arke_library.dart';
import 'package:arke_media/arke_media.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:crypto/crypto.dart';

import 'catalogue.dart';
import 'listening.dart';
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
    // The edition and every part since it: the world is installed when all of them are (R-50).
    final needed = await _checkSpace(package.byteLength + package.parts.fold(0, (sum, part) => sum + part.byteLength));
    final staging = await store.stageWorld();
    try {
      final zip = '${staging.path}${Platform.pathSeparator}package.zip';
      await _download(package, zip, onStep, control);
      control._check();
      final prepared = await _prepare(zip, staging, needed, onStep, control);
      if (prepared.manifest.id != world.id) throw const NotAPackage();
      return await commit(await _withParts(prepared, package.parts, onStep, control));
    } on FileSystemException catch (error) {
      throw await _full(error, needed);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Adds a part to an installed world (SPEC-058 R-51): its pin's length and SHA-256, every file
  /// checked, then the part beside what is there in one write, so nothing being played changes and
  /// nothing is ever half-added. A part already installed changes nothing. [from] is the part
  /// already fetched by [fetchPart], so nothing is downloaded again.
  Future<LibraryWorld> installPart(
    CatalogueWorld world,
    CataloguePart pin, {
    void Function(InstallStep step)? onStep,
    InstallCancel? cancel,
    File? from,
  }) async {
    final installed = store.worlds.where((existing) => existing.id == world.id).firstOrNull;
    if (installed == null) throw const NotAPackage();
    if (installed.parts.any((part) => part.fingerprint == pin.fingerprint)) return installed;
    final control = cancel ?? InstallCancel();
    final needed = await _checkSpace(pin.byteLength);
    final staging = await store.stageWorld();
    try {
      final zip = '${staging.path}${Platform.pathSeparator}part.zip';
      if (from != null && await from.exists() && await from.length() == pin.byteLength) {
        await from.copy(zip);
        if ((await sha256.bind(File(zip).openRead()).first).toString() != pin.sha256) throw const FilesDoNotMatch(1);
      } else {
        await _download(pin, zip, onStep, control);
      }
      control._check();
      final content = Directory('${staging.path}${Platform.pathSeparator}world');
      final manifest = await _check(zip, content, onStep, control);
      final released = await installedListening(store, installed, manifest.productions.single.id);
      final (next, part, changed) = await _describePart(
        manifest,
        content,
        installed,
        {for (final item in store.items) item.id: item},
        [for (final source in released) source.document],
        DateTime.now().toUtc(),
      );
      if (part.fingerprint != pin.fingerprint) throw const FilesDoNotMatch(1);
      control._check();
      await store.addPart(next, part, changed, content);
      return next;
    } on FileSystemException catch (error) {
      throw await _full(error, needed);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Fetches a part to [to] with its pin's length and SHA-256 checked, and adds nothing: the daily
  /// check in the background fetches while the app may be writing the library, so the part waits
  /// there until the app adds it ([installPart] with `from`).
  Future<void> fetchPart(CataloguePart pin, File to, {InstallCancel? cancel}) async {
    await _checkSpace(pin.byteLength);
    await to.parent.create(recursive: true);
    final partial = File('${to.path}.part');
    try {
      await _download(pin, partial.path, null, cancel ?? InstallCancel());
      await partial.rename(to.path);
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  /// Downloads and checks each part after a checked edition, into the edition's folder, so the
  /// edition and its parts join the library in one write (R-50).
  Future<PreparedWorld> _withParts(PreparedWorld prepared, List<CataloguePart> parts, void Function(InstallStep step)? onStep, InstallCancel control) async {
    if (parts.isEmpty) return prepared;
    var world = prepared.world;
    final items = {for (final item in prepared.items) item.id: item};
    final released = <String, List<ListeningDocument>>{
      for (final MapEntry(:key, :value) in prepared.manifest.listening.entries) key: [value],
    };
    for (final pin in parts) {
      final zip = '${prepared.staging.path}${Platform.pathSeparator}part.zip';
      await _download(pin, zip, onStep, control);
      control._check();
      final content = Directory('${prepared.content.path}${Platform.pathSeparator}_parts${Platform.pathSeparator}${world.parts.length + 1}');
      final manifest = await _check(zip, content, onStep, control);
      final production = manifest.productions.single.id;
      final (next, part, changed) = await _describePart(manifest, content, world, items, released[production] ?? const [], world.installedAt);
      if (part.fingerprint != pin.fingerprint) throw const FilesDoNotMatch(1);
      world = next;
      for (final item in changed) {
        items[item.id] = item;
      }
      if (manifest.listening[production] case final document?) released[production] = [...?released[production], document];
    }
    return PreparedWorld(
      manifest: prepared.manifest,
      world: world,
      items: List.unmodifiable(items.values),
      content: prepared.content,
      staging: prepared.staging,
      installed: prepared.installed,
    );
  }

  /// Brings an installed world to the edition its list entry names (SPEC-058 R-33, Player P12): the
  /// download and check of an install, then the Replace of a package added from a file (P10 rule 3),
  /// places kept by chapter. The installed edition stays and plays until the new one is checked in
  /// full; [beforeSwap] is awaited before it gives way, so a caller can wait for its world to stop
  /// playing. A package that turns out to be the installed edition changes nothing.
  Future<LibraryWorld> update(
    CatalogueWorld world, {
    void Function(InstallStep step)? onStep,
    InstallCancel? cancel,
    Future<void> Function()? beforeSwap,
  }) async {
    final package = world.package;
    if (package == null) throw const NotAPackage();
    final replaced = [
      for (final installed in store.worlds)
        if (installed.id != world.id && world.replaces.contains(installed.id)) installed.id,
    ];
    if (!store.worlds.any((installed) => installed.id == world.id)) {
      // Under an id this world replaces (SPEC-058 R-30): installed anew beside it, then the old one
      // goes. Its places do not carry across ids; everything else is as a first install.
      final added = await install(world, onStep: onStep, cancel: cancel);
      if (replaced.isNotEmpty) {
        await beforeSwap?.call();
        for (final id in replaced) {
          await store.removeWorld(id);
        }
      }
      return added;
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
      if (prepared.sameEdition) return prepared.installed!;
      // A new edition holds every chapter released, so the installed parts fall away with the old
      // edition's folder (R-55); parts listed after it come with it.
      final withParts = await _withParts(prepared, package.parts, onStep, control);
      await beforeSwap?.call();
      control._check();
      return await commit(withParts);
    } on FileSystemException catch (error) {
      throw await _full(error, needed);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// A world's guide being fetched, so a page opened twice fetches it once.
  final _fetching = <String, Future<LibraryGuide>>{};

  /// Fetches a world's guide alone (SPEC-059 R-10, R-18) as a world is installed: its pin's length
  /// and SHA-256, then every file checked, then kept under `guides/` for reading offline. A guide
  /// already kept under the same pin is not fetched again, nor one already being fetched: a second
  /// fetch would replace the folder the first was read from.
  Future<LibraryGuide> fetchGuide(CatalogueWorld world, {InstallCancel? cancel}) =>
      // A block, not an arrow: an arrow would hand whenComplete the removed fetch to wait on, which
      // is the one completing.
      _fetching[world.id] ??= _fetchGuide(world, cancel).whenComplete(() {
        _fetching.remove(world.id);
      });

  Future<LibraryGuide> _fetchGuide(CatalogueWorld world, InstallCancel? cancel) async {
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
    final content = Directory('${staging.path}${Platform.pathSeparator}world');
    final manifest = await _check(zip, content, onStep, control);
    // A part is never a world of its own: it is added to its edition (R-46).
    if (manifest.part != null) throw const NotAPackage();
    final (world, items) = await _describe(manifest, content);
    control._check();
    final installed = store.worlds.where((existing) => existing.id == world.id).firstOrNull;
    return PreparedWorld(manifest: manifest, world: world, items: items, content: content, staging: staging, installed: installed);
  }

  /// Reads a downloaded package, extracts every file into [content] checked against its manifest,
  /// and keeps the manifest beside them, so a player can read a listening document against it.
  Future<WorldManifest> _check(String zip, Directory content, void Function(InstallStep step)? onStep, InstallCancel control) async {
    final separator = Platform.pathSeparator;
    final WorldManifest manifest;
    try {
      manifest = await Isolate.run(() => readWorldPackage(zip));
    } on WorldPackageRefused catch (refused) {
      throw refused.refusal == WorldRefusal.newerArke ? const NewerArke() : const NotAPackage();
    }

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
    return manifest;
  }

  /// What a part adds to [world] (R-46, R-50): it must follow the installed edition, come next in
  /// order and bring chapters the world does not have, after the last released. Its chapters join
  /// the production's narration back to back; its book is read after the edition's. A narration
  /// that was finished moves to the first new chapter, so Continue offers it (P15g).
  Future<(LibraryWorld, LibraryPart, List<LibraryItem>)> _describePart(
    WorldManifest manifest,
    Directory content,
    LibraryWorld world,
    Map<String, LibraryItem> items,
    List<ListeningDocument> released,
    DateTime now,
  ) async {
    final part = manifest.part;
    if (part == null || manifest.id != world.id) throw const NotAPackage();
    if (world.fingerprint == null || part.fingerprint != world.fingerprint || part.number != world.parts.length + 1) throw const NotAPackage();
    final production = manifest.productions.single;
    final target = world.productions.where((existing) => existing.id == production.id).firstOrNull;
    if (target == null) throw const NotAPackage();
    final folder = 'worlds/${world.id}/_parts/${part.number}';
    String stored(WorldAsset asset) => '$folder/${asset.path}';
    final changed = <LibraryItem>[];
    var next = target;

    final document = manifest.listening[production.id];
    if (document != null) {
      final ids = {for (final earlier in released) ...earlier.chapters.map((chapter) => chapter.id)};
      final last = released.expand((earlier) => earlier.chapters).fold(0, (most, chapter) => chapter.order > most ? chapter.order : most);
      if (document.chapters.any((chapter) => ids.contains(chapter.id) || chapter.order <= last)) throw const NotAPackage();
      final id = '${world.id}.${production.id}.listening';
      final bytes = {production.listening!, ...document.assetIds}.fold(0, (sum, assetId) => sum + manifest.assets[assetId]!.byteLength);
      final before = items[id];
      final offset = before?.duration ?? Duration.zero;
      final added = [for (final (i, chapter) in document.chapters.indexed) Chapter(title: chapter.title, start: offset + document.starts[i], id: chapter.id)];
      if (before == null) {
        changed.add(
          LibraryItem(
            id: id,
            format: FileFormat.listening,
            title: production.title,
            author: production.author,
            duration: document.duration,
            byteLength: bytes,
            addedAt: now,
            file: stored(manifest.assets[production.listening]!),
            cover: target.picture ?? world.keyArt,
            chapters: added,
            worldId: world.id,
          ),
        );
        next = next.copyWith(narration: id);
      } else {
        final duration = offset + document.duration;
        final finished = before.finished || (before.place?.progress ?? 0) >= 0.999;
        changed.add(
          before.copyWith(
            chapters: [...before.chapters, ...added],
            duration: duration,
            byteLength: before.byteLength + bytes,
            finished: finished ? false : null,
            place: finished
                ? Place(
                    locator: document.chapters.first.id,
                    position: Duration.zero,
                    progress: duration.inMilliseconds == 0 ? 0 : offset.inMilliseconds / duration.inMilliseconds,
                    updatedAt: now,
                  )
                : null,
          ),
        );
      }
    }

    if (production.book != null) {
      final asset = manifest.assets[production.book]!;
      final path = '${content.path}${Platform.pathSeparator}${asset.path.replaceAll('/', Platform.pathSeparator)}';
      final MediaInfo info;
      try {
        info = await Isolate.run(() => readMediaInfo(path, FileFormat.epub));
      } on UnreadableFile {
        throw const NotAPackage();
      }
      if (info.protectedFile) throw const NotAPackage();
      final id = '${world.id}.${production.id}.book.${part.number}';
      changed.add(
        LibraryItem(
          id: id,
          format: FileFormat.epub,
          title: production.title,
          author: production.author ?? info.author,
          byteLength: asset.byteLength,
          addedAt: now,
          file: stored(asset),
          cover: target.picture ?? world.keyArt,
          chapters: [for (final chapter in info.chapters) Chapter(title: chapter.title, start: chapter.start)],
          worldId: world.id,
        ),
      );
      next = next.copyWith(bookParts: [...next.bookParts, id]);
    }

    final bytes = manifest.assets.values.fold(0, (sum, asset) => sum + asset.byteLength);
    final added = LibraryPart(
      number: part.number,
      edition: manifest.edition,
      fingerprint: editionFingerprint(manifest),
      production: production.id,
      chapters: [...?document?.chapters.map((chapter) => chapter.id)],
      byteLength: bytes,
      installedAt: now,
      folder: folder,
    );
    return (
      world.copyWith(
        productions: [for (final existing in world.productions) existing.id == next.id ? next : existing],
        parts: [...world.parts, added],
        byteLength: world.byteLength + bytes,
      ),
      added,
      changed,
    );
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
            chapters: [for (final (i, chapter) in document.chapters.indexed) Chapter(title: chapter.title, start: starts[i], id: chapter.id)],
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

/// A production's listening documents as installed (SPEC-058 R-50): the edition's, then each
/// part's, each with the folder its files are in. Played back to back, they are one narration.
Future<List<({ListeningDocument document, Map<String, WorldAsset> assets, String folder})>> installedListening(
  LibraryStore store,
  LibraryWorld world,
  String productionId,
) async {
  final separator = Platform.pathSeparator;
  final sources = <({ListeningDocument document, Map<String, WorldAsset> assets, String folder})>[];
  for (final folder in [store.worldDirectory(world.id).path, for (final part in world.parts) store.resolve(part.folder)]) {
    final file = File('$folder$separator$worldManifestFile');
    if (!await file.exists()) continue;
    final manifest = switch (readWorldManifest(await file.readAsString())) {
      WorldManifestOk(:final manifest) => manifest,
      WorldManifestRefused(:final reason) => throw FormatException(reason),
    };
    final listening = manifest.productions.where((production) => production.id == productionId).firstOrNull?.listening;
    if (listening == null) continue;
    final path = '$folder$separator${manifest.assets[listening]!.path.replaceAll('/', separator)}';
    final document = switch (readListening(await File(path).readAsString(), manifest.assets)) {
      ListeningOk(:final document) => document,
      ListeningRefused(:final reason) => throw FormatException(reason),
    };
    sources.add((document: document, assets: manifest.assets, folder: folder));
  }
  return sources;
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
