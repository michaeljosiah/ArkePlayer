/// What a person does with a production. A world's page groups its productions under these, in
/// this order, and leaves out a group with nothing in it (Arke Player P15 rule 3, which puts Listen
/// first, as Discover's chips do; P17 rule 2 puts Music after it).
enum TakenAs {
  listen('Listen'),

  /// A world's music (SPEC-058 R-73): its own group on a world's page and its own row on Discover,
  /// but never a chip of its own. Under the chips it is heard, so it sits with [listen].
  music('Music'),
  watch('Watch'),
  play('Play'),
  read('Read');

  const TakenAs(this.label);
  final String label;

  /// The chips over Discover and Library, `All · Listen · Watch · Play · Read`: Music is not one.
  static const chips = [listen, watch, play, read];

  /// The chip a group is shown under.
  TakenAs get chip => this == music ? listen : this;
}

/// The kinds of production Arke publishes, and how each is taken in.
enum ProductionKind {
  film('Film', TakenAs.watch),
  series('Series', TakenAs.watch),
  microDrama('Micro drama', TakenAs.watch),
  interactiveMovie('Interactive movie', TakenAs.play),
  visualNovel('Visual novel', TakenAs.play),
  audiobook('Audiobook', TakenAs.listen),
  audioDrama('Audio drama', TakenAs.listen),

  /// A world's music (SPEC-058 R-69, P17 rule 1): several tracks, one, or several for one of the
  /// world's productions.
  album('Album', TakenAs.music),
  single('Single', TakenAs.music),
  soundtrack('Soundtrack', TakenAs.music),

  /// A book with no narration. A book with its narration is an [audiobook] whose kind line reads
  /// `Audiobook · Book` and which offers Read beside Continue.
  book('Book', TakenAs.read);

  const ProductionKind(this.label, this.takenAs);
  final String label;
  final TakenAs takenAs;

  /// The kind a list's kind line names first, `Audiobook · Book · 8 h 2 m` → [audiobook]; a line
  /// naming no kind this build knows is a book's.
  static ProductionKind ofLine(String line) {
    final first = line.split(' · ').first.trim().toLowerCase();
    return ProductionKind.values.where((kind) => kind.label.toLowerCase() == first).firstOrNull ?? ProductionKind.book;
  }

  /// The kind of a music document's `album`, `single` or `soundtrack`.
  static ProductionKind ofMusic(String kind) => switch (kind) {
    'single' => single,
    'soundtrack' => soundtrack,
    _ => album,
  };
}

/// Groups productions for a world's page: [TakenAs] order, empty groups absent, each group in
/// the order it was given.
Map<TakenAs, List<T>> groupByTakenAs<T>(Iterable<T> productions, ProductionKind Function(T) kindOf) {
  final groups = {for (final taken in TakenAs.values) taken: <T>[]};
  for (final production in productions) {
    groups[kindOf(production).takenAs]!.add(production);
  }
  return {
    for (final entry in groups.entries)
      if (entry.value.isNotEmpty) entry.key: List.unmodifiable(entry.value),
  };
}
