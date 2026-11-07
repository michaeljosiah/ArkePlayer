import 'package:arke_world/arke_world.dart';

/// What a search found, in the order its groups show (P22g).
enum SearchKind {
  world('Worlds'),
  title('Titles'),
  character('Characters'),
  place('Places'),
  lore('Lore'),
  chapter('Chapters');

  const SearchKind(this.heading);
  final String heading;
}

/// One thing found: its name, a line of data, and where it is.
class SearchHit {
  const SearchHit({required this.kind, required this.title, required this.line, required this.world, this.entry, this.production});

  final SearchKind kind;
  final String title;
  final String line;
  final CatalogueWorld world;

  /// The guide's entry it opens: a character, a place, a lore entry.
  final GuideEntry? entry;

  /// The production it is, or that its chapter is in.
  final String? production;
}

/// What a world's guide may show: what it holds, and what this phone has reached or revealed.
typedef SearchGuide = ({Guide guide, GuideReach reach});

/// A chapter of a production on this phone. A guide knows its chapters by number alone, so only a
/// world that is here can be searched by a chapter's title.
typedef SearchChapter = ({CatalogueWorld world, String production, String productionTitle, int number, String title});

/// Searches Arke's list and each world's guide on the phone, with no account (P22 rule 10, call 43).
/// A word of a name has to begin with what is typed, so `ade` finds Adeyemi and Ade's House but never
/// Arcade. An entry still waiting for a chapter is not found until it is reached or revealed: a search
/// must not be how someone learns who turns up later.
List<SearchHit> searchWorlds(String query, Iterable<CatalogueWorld> worlds, Map<String, SearchGuide> guides, {Iterable<SearchChapter> chapters = const []}) {
  final typed = query.trim();
  if (typed.isEmpty) return const [];
  final pattern = RegExp('(^|[^\\p{L}\\p{N}])${RegExp.escape(typed)}', caseSensitive: false, unicode: true);
  bool matches(String name) => pattern.hasMatch(name);

  final hits = <SearchHit>[];
  for (final world in worlds) {
    if (matches(world.name)) {
      hits.add(SearchHit(kind: SearchKind.world, title: world.name, line: [...world.genres.take(1), ?world.age].join(' · '), world: world));
    }
    for (final production in world.productions) {
      if (matches(production.title)) {
        hits.add(SearchHit(kind: SearchKind.title, title: production.title, line: world.name, world: world, production: production.id));
      }
    }
    final held = guides[world.id];
    if (held == null) continue;
    final (:guide, :reach) = held;
    for (final character in guide.characters) {
      if (reach.shows(character.after) && matches(character.name)) {
        hits.add(SearchHit(kind: SearchKind.character, title: character.name, line: [?character.role, world.name].join(' · '), world: world, entry: character));
      }
    }
    for (final place in guide.places) {
      if (reach.shows(place.after) && matches(place.name)) {
        hits.add(SearchHit(kind: SearchKind.place, title: place.name, line: '${place.role ?? 'Place'} · ${world.name}', world: world, entry: place));
      }
    }
    for (final lore in guide.lore) {
      if (reach.shows(lore.after) && matches(lore.title)) {
        hits.add(SearchHit(kind: SearchKind.lore, title: lore.title, line: world.name, world: world, entry: lore));
      }
    }
  }
  for (final chapter in chapters) {
    if (matches(chapter.title)) {
      hits.add(
        SearchHit(
          kind: SearchKind.chapter,
          title: chapter.title,
          line: 'Chapter ${chapter.number} · ${chapter.productionTitle}',
          world: chapter.world,
          production: chapter.production,
        ),
      );
    }
  }
  return hits..sort((a, b) => a.kind.index.compareTo(b.kind.index));
}
