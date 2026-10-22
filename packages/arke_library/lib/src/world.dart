/// A production of an installed world (Arke Player P9 rule 6): its title, and the library items
/// its book and narration became, so each plays and keeps its place as an added file does.
class LibraryProduction {
  const LibraryProduction({required this.id, required this.title, this.author, this.picture, this.book, this.narration});

  final String id;
  final String title;
  final String? author;

  /// Relative to the library's root.
  final String? picture;

  /// Item ids.
  final String? book;
  final String? narration;

  /// The items this production plays from, narration first.
  List<String> get itemIds => [?narration, ?book];

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    if (author != null) 'author': author,
    if (picture != null) 'picture': picture,
    if (book != null) 'book': book,
    if (narration != null) 'narration': narration,
  };

  static LibraryProduction fromJson(Map<String, Object?> json) => LibraryProduction(
    id: json['id']! as String,
    title: json['title']! as String,
    author: json['author'] as String?,
    picture: json['picture'] as String?,
    book: json['book'] as String?,
    narration: json['narration'] as String?,
  );
}

/// A world installed from Available (P9): its own folder under `worlds/`, what its package said
/// about it, and its productions. It is the person's: it goes only by Remove (P9 rule 6).
class LibraryWorld {
  const LibraryWorld({
    required this.id,
    required this.edition,
    required this.name,
    required this.byteLength,
    required this.installedAt,
    required this.productions,
    this.logline,
    this.keyArt,
    this.fingerprint,
    this.guide,
  });

  final String id;
  final String edition;

  /// The edition label and every file's SHA-256 as one digest: two packages with the same are the
  /// same edition (P10 rule 2). Absent for a world installed before it was kept.
  final String? fingerprint;
  final String name;
  final String? logline;

  /// Relative to the library's root.
  final String? keyArt;

  /// What its files take on the phone.
  final int byteLength;
  final DateTime installedAt;
  final List<LibraryProduction> productions;

  /// Its guide document, relative to the library's root, when its package carried one (SPEC-059
  /// R-18).
  final String? guide;

  Map<String, Object?> toJson() => {
    'id': id,
    'edition': edition,
    'name': name,
    if (logline != null) 'logline': logline,
    if (keyArt != null) 'keyArt': keyArt,
    'byteLength': byteLength,
    'installedAt': installedAt.toUtc().toIso8601String(),
    'productions': [for (final production in productions) production.toJson()],
    if (fingerprint != null) 'fingerprint': fingerprint,
    if (guide != null) 'guide': guide,
  };

  static LibraryWorld fromJson(Map<String, Object?> json) => LibraryWorld(
    id: json['id']! as String,
    edition: json['edition']! as String,
    name: json['name']! as String,
    logline: json['logline'] as String?,
    keyArt: json['keyArt'] as String?,
    byteLength: json['byteLength']! as int,
    installedAt: DateTime.parse(json['installedAt']! as String),
    productions: [for (final production in json['productions']! as List<Object?>) LibraryProduction.fromJson((production! as Map).cast<String, Object?>())],
    fingerprint: json['fingerprint'] as String?,
    guide: json['guide'] as String?,
  );
}

/// A world's guide alone, fetched before the world is installed so it can be explored (SPEC-059
/// R-10, R-18): its own folder under `guides/`, kept for reading offline (R-22).
class LibraryGuide {
  const LibraryGuide({required this.worldId, required this.edition, required this.sha256, required this.guide, required this.fetchedAt});

  final String worldId;
  final String edition;

  /// The package's SHA-256, as the catalogue pinned it: a new pin is a new guide.
  final String sha256;

  /// The guide document, relative to the library's root.
  final String guide;
  final DateTime fetchedAt;

  Map<String, Object?> toJson() => {'worldId': worldId, 'edition': edition, 'sha256': sha256, 'guide': guide, 'fetchedAt': fetchedAt.toUtc().toIso8601String()};

  static LibraryGuide fromJson(Map<String, Object?> json) => LibraryGuide(
    worldId: json['worldId']! as String,
    edition: json['edition']! as String,
    sha256: json['sha256']! as String,
    guide: json['guide']! as String,
    fetchedAt: DateTime.parse(json['fetchedAt']! as String),
  );
}
