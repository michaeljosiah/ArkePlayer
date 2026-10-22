import 'dart:convert';

import 'package:arke_library/arke_library.dart';

/// What a production is, as the design writes it (P1 rule 6): `Audiobook · Book · 2 h 3 m` for a
/// book with its narration, `Audiobook · 6 h 12 m` for narration alone, `Book` for a book alone.
String productionKind({required bool book, required bool narration, Duration? length}) =>
    [if (narration) 'Audiobook', if (book) 'Book', if (narration && length != null) formatLength(length)].join(' · ');

/// A production a catalogue world holds, as its page shows it before the world is installed
/// (P9c's Inside): a title, its kind line and a picture bundled with the app.
class CatalogueProduction {
  const CatalogueProduction({required this.title, required this.kind, this.picture});

  final String title;
  final String kind;

  /// An asset path in the app's bundle.
  final String? picture;
}

/// Where a world's package is and the bytes it must have. The digest is pinned by the build, as
/// the Studio pins its Sample world: the package the app downloads is the one it was built to
/// expect, or it is refused.
class CataloguePackage {
  const CataloguePackage({required this.url, required this.byteLength, required this.sha256});

  final Uri url;
  final int byteLength;
  final String sha256;
}

/// A world a person can install (P9 rule 1). The list ships with the app, so it shows offline and
/// needs no Arke cloud; a new world arrives with an update.
class CatalogueWorld {
  const CatalogueWorld({required this.id, required this.name, required this.productions, this.logline, this.keyArt, this.package, this.guide});

  final String id;
  final String name;
  final String? logline;

  /// An asset path in the app's bundle.
  final String? keyArt;
  final List<CatalogueProduction> productions;

  /// Null until the world's package is published: such a world is not offered.
  final CataloguePackage? package;

  /// The world's guide alone, pinned as its package is, so the world can be explored before it is
  /// installed (SPEC-059 R-10, R-23). Null when the world has none.
  final CataloguePackage? guide;
}

final _slug = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
final _digest = RegExp(r'^[a-f0-9]{64}$');

/// Reads the catalogue the app ships (`assets/worlds/catalogue.json`). Throws [FormatException]
/// when it is malformed: it is the app's own file, so a bad one is a build error, not a refusal.
List<CatalogueWorld> readCatalogue(String text) {
  final json = jsonDecode(text);
  if (json is! Map<String, Object?> || json['version'] != 1 || json['worlds'] is! List<Object?>) throw const FormatException('catalogue');
  final worlds = <CatalogueWorld>[];
  for (final raw in json['worlds']! as List<Object?>) {
    if (raw is! Map<String, Object?>) throw const FormatException('catalogue world');
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || !_slug.hasMatch(id) || name is! String || name.isEmpty) throw FormatException('catalogue world $id');
    final productions = [
      for (final production in raw['productions']! as List<Object?>)
        if (production case {'title': final String title, 'kind': final String kind})
          CatalogueProduction(title: title, kind: kind, picture: production['picture'] as String?)
        else
          throw FormatException('catalogue world $id production'),
    ];
    CataloguePackage? pinned(String key) {
      if (raw[key] case {'url': final String url, 'byteLength': final int byteLength, 'sha256': final String sha256}) {
        final uri = Uri.parse(url);
        // A world arrives over HTTPS only (P2 rule 5's Paste a link holds the same line).
        if (uri.scheme != 'https' || byteLength <= 0 || !_digest.hasMatch(sha256)) throw FormatException('catalogue world $id $key');
        return CataloguePackage(url: uri, byteLength: byteLength, sha256: sha256);
      }
      if (raw[key] != null) throw FormatException('catalogue world $id $key');
      return null;
    }

    worlds.add(
      CatalogueWorld(
        id: id,
        name: name,
        logline: raw['logline'] as String?,
        keyArt: raw['keyArt'] as String?,
        productions: List.unmodifiable(productions),
        package: pinned('package'),
        guide: pinned('guide'),
      ),
    );
  }
  return List.unmodifiable(worlds);
}

/// Available (P9 rule 2): every world whose package is published and that is not installed.
List<CatalogueWorld> availableWorlds(Iterable<CatalogueWorld> catalogue, Iterable<LibraryWorld> installed) {
  final ids = {for (final world in installed) world.id};
  return [
    for (final world in catalogue)
      if (world.package != null && !ids.contains(world.id)) world,
  ];
}
