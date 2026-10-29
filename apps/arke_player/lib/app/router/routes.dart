/// Every route of the MVP, with the design frames it implements. Paths are built here and nowhere
/// else. Worlds to install (P9), to explore (P11) and to discover (P15) are in; shares and the Add
/// sheet return after the MVP (docs/mvp.md, "Out").
abstract final class Routes {
  /// First open, before sign-in exists: the wordmark and Add a file (P8a).
  static const welcome = '/welcome';

  // The five tabs (P1 rule 3, as P11 rule 1 and P15 rule 1 amend it).
  static const home = '/';
  static const discover = '/discover';
  static const library = '/library';
  static const downloads = '/downloads';
  static const you = '/you';

  /// A world's page in Home's tab, Discover's and Library's (P9c–P9h, P11b, P11c, P15c): the same
  /// page, keeping its tab.
  static String world(String id) => '/world/$id';
  static String discoverWorld(String id) => '/discover/world/$id';
  static String libraryWorld(String id) => '/library/world/$id';

  /// A production of an installed world, under the world's page it was opened from.
  static String production(String worldLocation, String productionId) => '$worldLocation/$productionId';

  /// A world's lore (P11f) and an entry of its guide (P11d, P11e, P11g), under the world's page.
  /// `_guide` can never be a production's id, which starts with a letter or digit.
  static String lore(String worldLocation) => '$worldLocation/_guide';
  static String guideEntry(String worldLocation, String entryId) => '$worldLocation/_guide/$entryId';

  /// An added file in its player, over the tabs: the audio player (P7d, P5a–P5c), the reader
  /// (P5e), the page viewer (P7c) or the film player (P3a, P3b, P3e).
  static String open(String itemId) => '/open/$itemId';

  /// A world's music in the audio player, over the tabs (P17d, P17e). [track] starts it there,
  /// [shuffle] in a shuffled order; with neither it shows what plays, as the dock opens it.
  static String music(String worldId, String productionId, {int? track, bool shuffle = false}) {
    final query = [if (track != null) 'track=$track', if (shuffle) 'shuffle=1'].join('&');
    return '/music/$worldId/$productionId${query.isEmpty ? '' : '?$query'}';
  }

  /// An interactive movie or a visual novel in its player, over the tabs (P18b – P18h), where its save
  /// says.
  static String story(String worldId, String productionId) => '/story/$worldId/$productionId';

  /// A graphic novel in its reader, over the tabs (P20b – P20g), at the page it was left on.
  static String comic(String worldId, String productionId) => '/comic/$worldId/$productionId';
}
