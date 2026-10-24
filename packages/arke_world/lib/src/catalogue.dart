import 'dart:convert';

import 'package:arke_library/arke_library.dart';

import 'manifest.dart';
import 'music.dart';

/// What a production is, as the design writes it (P1 rule 6): `Audiobook · Book · 2 h 3 m` for a
/// book with its narration, `Audiobook · 6 h 12 m` for narration alone, `Book` for a book alone.
String productionKind({required bool book, required bool narration, Duration? length}) =>
    [if (narration) 'Audiobook', if (book) 'Book', if (narration && length != null) formatLength(length)].join(' · ');

/// A picture published beside Arke's list (SPEC-058 rev 10): where it is and the bytes it must have,
/// pinned as a package is. It comes with the list, so a new or changed picture needs no new app.
/// It rides under `pins`, never in place of the bundle path beside it: every Player before it reads
/// `picture` as a string, and would throw on an object there and ignore the whole list.
class PicturePin {
  const PicturePin({required this.url, required this.byteLength, required this.sha256});

  final Uri url;
  final int byteLength;
  final String sha256;

  /// A cover at 1024 × 1536 is well under a megabyte; anything near this is not a picture for a row.
  static const maxBytes = 4 * 1024 * 1024;

  @override
  bool operator ==(Object other) => other is PicturePin && other.url == url && other.byteLength == byteLength && other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(url, byteLength, sha256);
}

/// A production a catalogue world holds, as its page shows it before the world is installed
/// (P9c's Inside): a title, its kind line and a picture bundled with the app.
class CatalogueProduction {
  const CatalogueProduction({
    required this.title,
    required this.kind,
    this.picture,
    this.tall,
    this.picturePin,
    this.tallPin,
    this.id,
    this.schedule,
    this.package,
    this.music,
  });

  final String title;
  final String kind;

  /// An asset path in the app's bundle.
  final String? picture;

  /// Its Tall cover, an asset path in the app's bundle (SPEC-058 rev 9, Player P16 call 14): what a
  /// poster and a phone's feature show. Without one they show [picture] whole over its blur.
  final String? tall;

  /// The same pictures published beside the list (SPEC-058 rev 10): shown in place of [picture] and
  /// [tall] once fetched and checked.
  final PicturePin? picturePin;
  final PicturePin? tallPin;

  /// Its id in the world's package, so a tile opens the world's page at it; absent in older lists.
  final String? id;

  /// When its author says new chapters come (SPEC-058 R-48, R-53), as `pin_world` copied it.
  final WorldSchedule? schedule;

  /// Its own production package, published alone beside the world's edition (SPEC-058 R-71), pinned
  /// as an edition is, with its edition label and fingerprint; null when it is in the edition.
  final CataloguePackage? package;

  /// What kind of music it is (R-71), so its tile is square and it sits under Music; null when it is
  /// not music.
  final MusicKind? music;
}

/// Where a world's package is and the bytes it must have. The digest is pinned by the build, as
/// the Studio pins its Sample world: the package the app downloads is the one it was built to
/// expect, or it is refused.
class CataloguePackage {
  const CataloguePackage({required this.url, required this.byteLength, required this.sha256, this.edition, this.fingerprint});

  final Uri url;
  final int byteLength;
  final String sha256;

  /// The package's edition label (SPEC-058 R-30), as its `world.json` names it.
  final String? edition;

  /// The edition's fingerprint, as `editionFingerprint` makes it: what an installed world is
  /// compared by to see an update (P12 rule 2, P10 rule 2).
  final String? fingerprint;

  /// The parts released since this edition, in release order (SPEC-058 R-49). Empty for a guide.
  List<CataloguePart> get parts => const [];
}

/// A chapter a part brings, as Discover, New and a notification name it before it is fetched.
class CataloguePartChapter {
  const CataloguePartChapter({required this.id, required this.number, required this.title});
  final String id;
  final int number;
  final String title;
}

/// A part pinned as a package is (SPEC-058 R-49): the chapters released after an edition, with
/// the day it was released and what it brings.
class CataloguePart extends CataloguePackage {
  const CataloguePart({
    required super.url,
    required super.byteLength,
    required super.sha256,
    required String super.edition,
    required String super.fingerprint,
    required this.released,
    required this.production,
    required this.chapters,
  });

  /// UTC midnight of the day it was released.
  final DateTime released;
  final String production;
  final List<CataloguePartChapter> chapters;
}

/// An edition's pin with the parts released since it.
class CatalogueEdition extends CataloguePackage {
  const CatalogueEdition({required super.url, required super.byteLength, required super.sha256, super.edition, super.fingerprint, this.parts = const []});

  @override
  final List<CataloguePart> parts;
}

/// A world a person can install (P9 rule 1). The list ships with the app, so it shows offline and
/// needs no Arke cloud; it is also fetched from Arke's address (P12 rule 1), so a newer edition
/// shows without an update.
class CatalogueWorld {
  const CatalogueWorld({
    required this.id,
    required this.name,
    required this.productions,
    this.logline,
    this.keyArt,
    this.keyArtPin,
    this.package,
    this.guide,
    this.replaces = const [],
  });

  final String id;
  final String name;
  final String? logline;

  /// An asset path in the app's bundle.
  final String? keyArt;

  /// The key art published beside the list (SPEC-058 rev 10), shown in place of [keyArt] once
  /// fetched and checked.
  final PicturePin? keyArtPin;
  final List<CatalogueProduction> productions;

  /// Null until the world's package is published: such a world is not offered.
  final CataloguePackage? package;

  /// The world's guide alone, pinned as its package is, so the world can be explored before it is
  /// installed (SPEC-059 R-10, R-23). Null when the world has none.
  final CataloguePackage? guide;

  /// The ids this world was once published under (SPEC-058 R-30): a world installed under one of
  /// them is an older edition of this one, so it is offered `Update`, not a second world.
  final List<String> replaces;

  /// Whether a world installed under [id] is this one, under this id or one it replaces.
  bool covers(String id) => id == this.id || replaces.contains(id);
}

/// The production Discover opens on (SPEC-058 rev 9, Player P16 call 15): a world, and one of its
/// productions or, unnamed, its first.
class CatalogueFeature {
  const CatalogueFeature({required this.world, this.production});
  final String world;
  final String? production;
}

/// A list of Arke's worlds (SPEC-058 R-30): its [serial] rises with every list published, so of two
/// lists the one with the higher serial is the newer. It may name Discover's [feature] and the world
/// of its [band] (P16 call 15); a name that matches no world is the reader's to ignore.
class Catalogue {
  const Catalogue({required this.serial, required this.worlds, this.feature, this.band});
  final int serial;
  final List<CatalogueWorld> worlds;
  final CatalogueFeature? feature;
  final String? band;

  static const empty = Catalogue(serial: 0, worlds: []);
}

final _slug = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
final _digest = RegExp(r'^[a-f0-9]{64}$');

/// An entry's `pins` (SPEC-058 rev 10): a map from the bundle-path key it stands beside to a pin.
/// Keys it does not know are left for a newer reader; a known one must be a pin.
Map<String, Object?> _pins(Object? value, String what) => switch (value) {
  null => const {},
  final Map<String, Object?> pins => pins,
  _ => throw FormatException('$what pins'),
};

PicturePin? _picturePin(Map<String, Object?> pins, String key, String what) {
  final value = pins[key];
  if (value == null) return null;
  if (value case {'url': final String url, 'byteLength': final int byteLength, 'sha256': final String sha256}) {
    final uri = Uri.tryParse(url);
    // A picture comes over HTTPS only, as a world does, and is checked by its length and digest.
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && byteLength > 0 && byteLength <= PicturePin.maxBytes && _digest.hasMatch(sha256)) {
      return PicturePin(url: uri, byteLength: byteLength, sha256: sha256);
    }
  }
  throw FormatException('$what pins $key');
}

/// A listed production's own package (SPEC-058 R-71): pinned as an edition is, by its address, length
/// and SHA-256, and its edition label and fingerprint, which a phone compares to see that production's
/// update. Both are required: a production package is never offered without them.
CataloguePackage? _productionPackage(Object? value, String what) {
  if (value == null) return null;
  if (value case {
    'url': final String url,
    'byteLength': final int byteLength,
    'sha256': final String sha256,
    'edition': final String edition,
    'fingerprint': final String fingerprint,
  }) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.scheme == 'https' && byteLength > 0 && _digest.hasMatch(sha256) && edition.trim().isNotEmpty && _digest.hasMatch(fingerprint)) {
      return CataloguePackage(url: uri, byteLength: byteLength, sha256: sha256, edition: edition, fingerprint: fingerprint);
    }
  }
  throw FormatException('$what package');
}

/// A listed production's music kind (R-71), one of the three a music document names. A kind this
/// Player does not know reads as none, so the production is simply not placed under Music: refusing
/// it would make every released Player ignore the whole fetched list, editions and parts included,
/// the trap R-64 keeps `pins` out of. A value that is not a word at all is still malformed.
MusicKind? _musicKind(Object? value, String what) => switch (value) {
  null => null,
  final String kind => MusicKind.values.where((known) => known.name == kind).firstOrNull,
  _ => throw FormatException('$what music'),
};

/// Reads a list of Arke's worlds: the one the app ships (`assets/worlds/catalogue.json`) or one
/// fetched from Arke's address. Version 1 has no serial and no editions. Throws [FormatException]
/// when it is malformed: the app's own list is a build error, a fetched one is ignored.
Catalogue parseCatalogue(String text) {
  final json = jsonDecode(text);
  if (json is! Map<String, Object?> || json['worlds'] is! List<Object?>) throw const FormatException('catalogue');
  final version = json['version'];
  if (version != 1 && version != 2) throw const FormatException('catalogue version');
  final serial = version == 1 ? 0 : json['serial'];
  if (serial is! int || serial < 0) throw const FormatException('catalogue serial');
  final worlds = <CatalogueWorld>[];
  final ids = <String>{};
  for (final raw in json['worlds']! as List<Object?>) {
    if (raw is! Map<String, Object?>) throw const FormatException('catalogue world');
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || !_slug.hasMatch(id) || !ids.add(id) || name is! String || name.isEmpty) throw FormatException('catalogue world $id');
    final productions = [
      for (final production in raw['productions'] as List<Object?>? ?? const [])
        if (production case {'title': final String title, 'kind': final String kind})
          CatalogueProduction(
            title: title,
            kind: kind,
            picture: production['picture'] as String?,
            tall: switch (production['tall']) {
              null => null,
              final String tall when tall.isNotEmpty => tall,
              _ => throw FormatException('catalogue world $id production tall'),
            },
            picturePin: _picturePin(_pins(production['pins'], 'catalogue world $id production'), 'picture', 'catalogue world $id production'),
            tallPin: _picturePin(_pins(production['pins'], 'catalogue world $id production'), 'tall', 'catalogue world $id production'),
            id: switch (production['id']) {
              null => null,
              final String productionId when _slug.hasMatch(productionId) => productionId,
              _ => throw FormatException('catalogue world $id production id'),
            },
            schedule: production['schedule'] == null ? null : WorldSchedule.read(production['schedule']),
            package: _productionPackage(production['package'], 'catalogue world $id production'),
            music: _musicKind(production['music'], 'catalogue world $id production'),
          )
        else
          throw FormatException('catalogue world $id production'),
    ];
    (Uri, int, String, String?, String?) pinOf(Object? value, String what) {
      if (value case {'url': final String url, 'byteLength': final int byteLength, 'sha256': final String sha256}) {
        final uri = Uri.parse(url);
        // A world arrives over HTTPS only (P2 rule 5's Paste a link holds the same line).
        if (uri.scheme != 'https' || byteLength <= 0 || !_digest.hasMatch(sha256)) throw FormatException('catalogue world $id $what');
        final pin = value as Map<String, Object?>;
        final edition = pin['edition'];
        final fingerprint = pin['fingerprint'];
        if (edition != null && (edition is! String || edition.trim().isEmpty)) throw FormatException('catalogue world $id $what edition');
        if (fingerprint != null && (fingerprint is! String || !_digest.hasMatch(fingerprint))) throw FormatException('catalogue world $id $what fingerprint');
        return (uri, byteLength, sha256, edition as String?, fingerprint as String?);
      }
      throw FormatException('catalogue world $id $what');
    }

    // A part names its day, its production and its chapters, so Discover, New and a notification
    // show it before it is fetched (SPEC-058 R-49).
    CataloguePart partOf(Object? value, int index) {
      final what = 'part ${index + 1}';
      final (url, byteLength, sha256, edition, fingerprint) = pinOf(value, what);
      final pin = value! as Map<String, Object?>;
      final released = parseDay(pin['released']);
      final production = pin['production'];
      final chapters = pin['chapters'];
      if (edition == null || fingerprint == null || released == null || production is! String || !_slug.hasMatch(production) || chapters is! List<Object?>) {
        throw FormatException('catalogue world $id $what');
      }
      return CataloguePart(
        url: url,
        byteLength: byteLength,
        sha256: sha256,
        edition: edition,
        fingerprint: fingerprint,
        released: released,
        production: production,
        chapters: List.unmodifiable([
          for (final chapter in chapters)
            if (chapter case {
              'id': final String chapterId,
              'number': final int number,
              'title': final String title,
            } when _slug.hasMatch(chapterId) && number > 0)
              CataloguePartChapter(id: chapterId, number: number, title: title)
            else
              throw FormatException('catalogue world $id $what chapter'),
        ]),
      );
    }

    CataloguePackage? pinned(String key) {
      if (raw[key] == null) return null;
      final (url, byteLength, sha256, edition, fingerprint) = pinOf(raw[key], key);
      if (key != 'package') return CataloguePackage(url: url, byteLength: byteLength, sha256: sha256, edition: edition, fingerprint: fingerprint);
      final parts = (raw[key]! as Map<String, Object?>)['parts'] ?? const <Object?>[];
      if (parts is! List<Object?>) throw FormatException('catalogue world $id parts');
      return CatalogueEdition(
        url: url,
        byteLength: byteLength,
        sha256: sha256,
        edition: edition,
        fingerprint: fingerprint,
        parts: List.unmodifiable([for (final (index, part) in parts.indexed) partOf(part, index)]),
      );
    }

    final replaces = raw['replaces'] ?? const <Object?>[];
    if (replaces is! List<Object?> || replaces.any((old) => old is! String || !_slug.hasMatch(old) || old == id)) {
      throw FormatException('catalogue world $id replaces');
    }
    worlds.add(
      CatalogueWorld(
        id: id,
        name: name,
        logline: raw['logline'] as String?,
        keyArt: raw['keyArt'] as String?,
        keyArtPin: _picturePin(_pins(raw['pins'], 'catalogue world $id'), 'keyArt', 'catalogue world $id'),
        productions: List.unmodifiable(productions),
        package: pinned('package'),
        guide: pinned('guide'),
        replaces: List.unmodifiable(replaces.cast<String>()),
      ),
    );
  }
  // Discover's feature and band (P16 call 15) are names, kept even when no listed world answers to them,
  // so a list that names a world before it is published still reads.
  final feature = switch (json['feature']) {
    null => null,
    {'world': final String world} && final Map<String, Object?> named when _slug.hasMatch(world) => CatalogueFeature(
      world: world,
      production: switch (named['production']) {
        null => null,
        final String production when _slug.hasMatch(production) => production,
        _ => throw const FormatException('catalogue feature production'),
      },
    ),
    _ => throw const FormatException('catalogue feature'),
  };
  final band = switch (json['band']) {
    null => null,
    final String world when _slug.hasMatch(world) => world,
    _ => throw const FormatException('catalogue band'),
  };
  return Catalogue(serial: serial, worlds: List.unmodifiable(worlds), feature: feature, band: band);
}

/// The worlds of the list the app ships, as [parseCatalogue] reads them.
List<CatalogueWorld> readCatalogue(String text) => parseCatalogue(text).worlds;

/// The list Worlds shows (SPEC-058 R-31): of the list the app ships and the list it fetched and
/// kept, the one with the higher serial, so it never goes back to an older one. Bundle paths come
/// from the app: a fetched list names paths it cannot know are in this build, so a world's key art
/// and its productions' pictures and Tall covers are the shipped list's. Their pins are the newer
/// list's (SPEC-058 rev 10): a pin is an address, not a path, so a fetched list can bring a picture
/// this build never shipped, for a world it does not ship too. Discover's feature and band, and a
/// production's own package and music kind (rev 11), are the newer list's.
Catalogue newestCatalogue(Catalogue shipped, Catalogue? kept) {
  if (kept == null || kept.serial <= shipped.serial) return shipped;
  final bundled = {for (final world in shipped.worlds) world.id: world};
  // A world the app ships under an id the fetched one replaces keeps its pictures.
  CatalogueWorld? shippedAs(CatalogueWorld world) => bundled[world.id] ?? world.replaces.map((id) => bundled[id]).nonNulls.firstOrNull;
  CatalogueProduction? shippedProduction(CatalogueWorld world, CatalogueProduction production) =>
      shippedAs(world)?.productions.where((shippedProduction) => shippedProduction.title == production.title).firstOrNull;
  return Catalogue(
    serial: kept.serial,
    feature: kept.feature,
    band: kept.band,
    worlds: List.unmodifiable([
      for (final world in kept.worlds)
        CatalogueWorld(
          id: world.id,
          name: world.name,
          logline: world.logline,
          keyArt: shippedAs(world)?.keyArt,
          keyArtPin: world.keyArtPin,
          productions: List.unmodifiable([
            for (final production in world.productions)
              CatalogueProduction(
                title: production.title,
                kind: production.kind,
                picture: shippedProduction(world, production)?.picture,
                tall: shippedProduction(world, production)?.tall,
                picturePin: production.picturePin,
                tallPin: production.tallPin,
                id: production.id,
                schedule: production.schedule,
                package: production.package,
                music: production.music,
              ),
          ]),
          package: world.package,
          guide: world.guide,
          replaces: world.replaces,
        ),
    ]),
  );
}

/// Available (P9 rule 2): every world whose package is published and that is not installed, under
/// its id or one it replaces.
List<CatalogueWorld> availableWorlds(Iterable<CatalogueWorld> catalogue, Iterable<LibraryWorld> installed) {
  return [
    for (final world in catalogue)
      if (world.package != null && !installed.any((installedWorld) => world.covers(installedWorld.id))) world,
  ];
}

/// The list's entry for a world installed under [installedId]: its own, or the one replacing it.
CatalogueWorld? listedFor(Iterable<CatalogueWorld> catalogue, String installedId) =>
    catalogue.where((world) => world.id == installedId).firstOrNull ?? catalogue.where((world) => world.replaces.contains(installedId)).firstOrNull;

/// Whether the list names a newer edition of an installed world (SPEC-058 R-32, P12 rule 2): its
/// fingerprint is not the installed one's, or, for a world installed before fingerprints were kept,
/// its label is not. A list entry that names no edition offers none.
/// The parts the list names that an installed world lacks, in order (SPEC-058 R-51): none for a
/// world whose list entry is a newer edition, which waits for Update instead.
List<CataloguePart> missingParts(CatalogueWorld listed, LibraryWorld installed) {
  final package = listed.package;
  if (package == null || hasUpdate(listed, installed)) return const [];
  final have = {for (final part in installed.parts) part.fingerprint};
  return [
    for (final part in package.parts)
      if (!have.contains(part.fingerprint)) part,
  ];
}

bool hasUpdate(CatalogueWorld listed, LibraryWorld installed) {
  final package = listed.package;
  if (package == null || !listed.covers(installed.id)) return false;
  // A world installed under an id this one replaces is always an older edition of it.
  if (listed.id != installed.id) return true;
  if (package.fingerprint != null && installed.fingerprint != null) return package.fingerprint != installed.fingerprint;
  return package.edition != null && package.edition != installed.edition;
}
