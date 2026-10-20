/// What a person does with a production. A world's page groups its productions under these, in
/// this order, and leaves out a group with nothing in it (Arke Player P1 rule 6).
enum TakenAs {
  watch('Watch'),
  play('Play'),
  listen('Listen'),
  read('Read');

  const TakenAs(this.label);
  final String label;
}

/// The kinds of production Arke publishes, and how each is taken in.
enum ProductionKind {
  film('Film', TakenAs.watch),
  microDrama('Micro drama', TakenAs.watch),
  interactiveMovie('Interactive movie', TakenAs.play),
  visualNovel('Visual novel', TakenAs.play),
  audiobook('Audiobook', TakenAs.listen),
  audioDrama('Audio drama', TakenAs.listen),

  /// A book with no narration. A book with its narration is an [audiobook] whose kind line reads
  /// `Audiobook · Book` and which offers Read beside Continue.
  book('Book', TakenAs.read);

  const ProductionKind(this.label, this.takenAs);
  final String label;
  final TakenAs takenAs;
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
