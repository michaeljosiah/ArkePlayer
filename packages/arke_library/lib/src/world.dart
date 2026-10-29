/// A music production as installed (SPEC-058 R-69, R-70; Player P17): where its music document is,
/// and what a tile and a page say of it before the document is read — its kind, the production a
/// soundtrack is for, how many tracks and how long. Its tracks play from the document; a song keeps
/// no place, so no library item stands for it (P17 call 20).
class LibraryMusic {
  const LibraryMusic({required this.document, required this.kind, required this.tracks, required this.duration, this.forProduction});

  /// The music document, relative to the library's root.
  final String document;

  /// `album`, `single` or `soundtrack`, as the document names it.
  final String kind;

  /// The production a soundtrack is for, by id.
  final String? forProduction;
  final int tracks;
  final Duration duration;

  Map<String, Object?> toJson() => {
    'document': document,
    'kind': kind,
    if (forProduction != null) 'for': forProduction,
    'tracks': tracks,
    'durationMs': duration.inMilliseconds,
  };

  static LibraryMusic fromJson(Map<String, Object?> json) => LibraryMusic(
    document: json['document']! as String,
    kind: json['kind']! as String,
    forProduction: json['for'] as String?,
    tracks: json['tracks']! as int,
    duration: Duration(milliseconds: json['durationMs']! as int),
  );
}

/// An interactive production as installed (SPEC-058 R-79, R-80; Player P18): where its story document
/// is, and what a tile and a page say of it before the document is read — a movie or a novel, its
/// shape, how many scenes — with its Tall cover and the document's own fingerprint, which a save is
/// checked against (R-88).
class LibraryStory {
  const LibraryStory({required this.document, required this.kind, required this.shape, required this.scenes, required this.fingerprint, this.tall});

  /// The story document, relative to the library's root.
  final String document;

  /// `movie` or `novel`, as the document names it.
  final String kind;

  /// `16:9` or `9:16`.
  final String shape;
  final int scenes;

  /// The document's content fingerprint (SPEC-063 R-14), `sha256:<hex>`.
  final String fingerprint;

  /// Its Tall cover, relative to the library's root.
  final String? tall;

  Map<String, Object?> toJson() => {
    'document': document,
    'kind': kind,
    'shape': shape,
    'scenes': scenes,
    'fingerprint': fingerprint,
    if (tall != null) 'tall': tall,
  };

  static LibraryStory fromJson(Map<String, Object?> json) => LibraryStory(
    document: json['document']! as String,
    kind: json['kind']! as String,
    shape: json['shape']! as String,
    scenes: json['scenes']! as int,
    fingerprint: json['fingerprint']! as String,
    tall: json['tall'] as String?,
  );
}

/// A graphic novel as installed (SPEC-064 R-50; Player P20): where its comic document is, how it
/// reads, its page shape, and how many chapters and pages, so a page tile and Continue need not read it.
class LibraryComic {
  const LibraryComic({required this.document, required this.reading, required this.aspect, required this.chapters, required this.pages});

  /// The comic document, relative to the library's root.
  final String document;

  /// `ltr`, `rtl` or `scroll`.
  final String reading;

  /// The page shape, `2:3`.
  final String aspect;
  final int chapters;
  final int pages;

  Map<String, Object?> toJson() => {'document': document, 'reading': reading, 'aspect': aspect, 'chapters': chapters, 'pages': pages};

  static LibraryComic fromJson(Map<String, Object?> json) => LibraryComic(
    document: json['document']! as String,
    reading: json['reading']! as String,
    aspect: json['aspect']! as String,
    chapters: json['chapters']! as int,
    pages: json['pages']! as int,
  );
}

/// A production published as a package of its own beside its world's edition (SPEC-058 R-68, R-72):
/// the edition and fingerprint its pin in Arke's list names, so a changed one is its Update, and the
/// folder it was installed into, `worlds/<id>/_productions/<production>`.
class LibraryProductionPackage {
  const LibraryProductionPackage({required this.edition, required this.fingerprint, required this.byteLength, required this.installedAt, required this.folder});

  final String edition;
  final String fingerprint;
  final int byteLength;
  final DateTime installedAt;

  /// Relative to the library's root; its `world.json` is at the top.
  final String folder;

  Map<String, Object?> toJson() => {
    'edition': edition,
    'fingerprint': fingerprint,
    'byteLength': byteLength,
    'installedAt': installedAt.toUtc().toIso8601String(),
    'folder': folder,
  };

  static LibraryProductionPackage fromJson(Map<String, Object?> json) => LibraryProductionPackage(
    edition: json['edition']! as String,
    fingerprint: json['fingerprint']! as String,
    byteLength: json['byteLength']! as int,
    installedAt: DateTime.parse(json['installedAt']! as String),
    folder: json['folder']! as String,
  );
}

/// A production of an installed world (Arke Player P9 rule 6): its title, and the library items
/// its book and narration became, so each plays and keeps its place as an added file does. A music
/// production names its [music] instead (P17), an interactive one its [story] (P18), and one
/// published alone its [package] (R-68).
class LibraryProduction {
  const LibraryProduction({
    required this.id,
    required this.title,
    this.author,
    this.picture,
    this.book,
    this.narration,
    this.bookParts = const [],
    this.music,
    this.story,
    this.comic,
    this.package,
  });

  final String id;
  final String title;
  final String? author;

  /// Relative to the library's root.
  final String? picture;

  /// Item ids.
  final String? book;
  final String? narration;

  /// The books of the parts released since the edition (SPEC-058 R-50): each part's EPUB holds its
  /// chapters alone, read after [book] as one book. Item ids, in release order.
  final List<String> bookParts;

  /// Its music, when it is an album, a single or a soundtrack (SPEC-058 R-69).
  final LibraryMusic? music;

  /// Its story, when it is an interactive movie or a visual novel (SPEC-058 R-79).
  final LibraryStory? story;

  /// Its pages, when it is a graphic novel (SPEC-064 R-50).
  final LibraryComic? comic;

  /// The package it came in on its own (R-68, R-72); null when it came in its world's edition.
  final LibraryProductionPackage? package;

  /// The items this production plays from, narration first.
  List<String> get itemIds => [?narration, ?book, ...bookParts];

  LibraryProduction copyWith({String? narration, List<String>? bookParts}) => LibraryProduction(
    id: id,
    title: title,
    author: author,
    picture: picture,
    book: book,
    narration: narration ?? this.narration,
    bookParts: bookParts ?? this.bookParts,
    music: music,
    story: story,
    comic: comic,
    package: package,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    if (author != null) 'author': author,
    if (picture != null) 'picture': picture,
    if (book != null) 'book': book,
    if (narration != null) 'narration': narration,
    if (bookParts.isNotEmpty) 'bookParts': bookParts,
    if (music != null) 'music': music!.toJson(),
    if (story != null) 'story': story!.toJson(),
    if (comic != null) 'comic': comic!.toJson(),
    if (package != null) 'package': package!.toJson(),
  };

  static LibraryProduction fromJson(Map<String, Object?> json) => LibraryProduction(
    id: json['id']! as String,
    title: json['title']! as String,
    author: json['author'] as String?,
    picture: json['picture'] as String?,
    book: json['book'] as String?,
    narration: json['narration'] as String?,
    bookParts: [for (final id in (json['bookParts'] as List<Object?>? ?? const [])) id! as String],
    music: json['music'] == null ? null : LibraryMusic.fromJson((json['music']! as Map).cast<String, Object?>()),
    story: json['story'] == null ? null : LibraryStory.fromJson((json['story']! as Map).cast<String, Object?>()),
    comic: json['comic'] == null ? null : LibraryComic.fromJson((json['comic']! as Map).cast<String, Object?>()),
    package: json['package'] == null ? null : LibraryProductionPackage.fromJson((json['package']! as Map).cast<String, Object?>()),
  );
}

/// A part of an installed world (SPEC-058 R-46, R-50): one production's chapters released after
/// the world's edition, kept in its own folder under the world's, `_parts/<number>`.
class LibraryPart {
  const LibraryPart({
    required this.number,
    required this.edition,
    required this.fingerprint,
    required this.production,
    required this.chapters,
    required this.byteLength,
    required this.installedAt,
    required this.folder,
  });

  /// Its place among the parts after the edition, from 1.
  final int number;

  /// The part's own label, its date.
  final String edition;

  /// The part's own fingerprint, as its pin in Arke's list names it.
  final String fingerprint;

  /// The production it extends, and the ids of the chapters it brought, in order.
  final String production;
  final List<String> chapters;
  final int byteLength;
  final DateTime installedAt;

  /// Relative to the library's root; its `world.json` is at the top.
  final String folder;

  Map<String, Object?> toJson() => {
    'number': number,
    'edition': edition,
    'fingerprint': fingerprint,
    'production': production,
    'chapters': chapters,
    'byteLength': byteLength,
    'installedAt': installedAt.toUtc().toIso8601String(),
    'folder': folder,
  };

  static LibraryPart fromJson(Map<String, Object?> json) => LibraryPart(
    number: json['number']! as int,
    edition: json['edition']! as String,
    fingerprint: json['fingerprint']! as String,
    production: json['production']! as String,
    chapters: [for (final id in json['chapters']! as List<Object?>) id! as String],
    byteLength: json['byteLength']! as int,
    installedAt: DateTime.parse(json['installedAt']! as String),
    folder: json['folder']! as String,
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
    this.parts = const [],
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

  /// The parts released since its edition, in order (SPEC-058 R-50). A new edition holds every
  /// chapter released, so its parts fall away when it is installed (R-55).
  final List<LibraryPart> parts;

  LibraryWorld copyWith({List<LibraryProduction>? productions, List<LibraryPart>? parts, int? byteLength}) => LibraryWorld(
    id: id,
    edition: edition,
    name: name,
    byteLength: byteLength ?? this.byteLength,
    installedAt: installedAt,
    productions: productions ?? this.productions,
    logline: logline,
    keyArt: keyArt,
    fingerprint: fingerprint,
    guide: guide,
    parts: parts ?? this.parts,
  );

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
    if (parts.isNotEmpty) 'parts': [for (final part in parts) part.toJson()],
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
    parts: [for (final part in (json['parts'] as List<Object?>? ?? const [])) LibraryPart.fromJson((part! as Map).cast<String, Object?>())],
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
