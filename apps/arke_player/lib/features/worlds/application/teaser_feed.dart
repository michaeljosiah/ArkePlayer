import 'package:arke_world/arke_world.dart';

import 'guides.dart';

/// One page of the feed (P23a – P23c).
class FeedPage {
  const FeedPage({required this.world, required this.worldId, required this.worldPage, required this.guide, required this.teaser});

  final CatalogueWorld world;

  /// The id it is here under, or its list id before it is.
  final String worldId;

  /// Its page, under the tab the feed was opened from.
  final String worldPage;
  final WorldGuide guide;
  final GuideTeaser teaser;
}

/// The feed (P23 rule 1, call 46), across every world: each world's chosen teasers first, then its open
/// characters and places. Only one published world has chosen any, and all have people, so chosen
/// teasers alone would be an almost empty feed. An entry that waits for a chapter never shows, and one
/// with no picture has nothing to fill the phone with.
List<FeedPage> teaserFeed(Iterable<({CatalogueWorld world, String worldId, String worldPage, WorldGuide guide})> worlds) => [
  for (final (:world, :worldId, :worldPage, :guide) in worlds) ...[
    for (final teaser in _pagesOf(guide.guide)) FeedPage(world: world, worldId: worldId, worldPage: worldPage, guide: guide, teaser: teaser),
  ],
];

Iterable<GuideTeaser> _pagesOf(Guide guide) sync* {
  final chosen = <String>{};
  for (final teaser in guide.teasers) {
    if (teaser is EntryTeaser) {
      if (teaser.entry.after != null) continue;
      chosen.add(teaser.entry.id);
    }
    yield teaser;
  }
  for (final character in guide.characters) {
    if (character.after == null && character.portrait != null && !chosen.contains(character.id)) yield EntryTeaser(character);
  }
  for (final place in guide.places) {
    if (place.after == null && place.picture != null && !chosen.contains(place.id)) yield EntryTeaser(place);
  }
}
