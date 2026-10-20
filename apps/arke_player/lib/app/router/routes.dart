/// Every route of the MVP, with the design frames it implements. Paths are built here and nowhere
/// else. Worlds to install (P9) are in; shares and the Add sheet return after the MVP
/// (docs/mvp.md, "Out").
abstract final class Routes {
  /// First open, before sign-in exists: the wordmark and Add a file (P8a).
  static const welcome = '/welcome';

  // The four tabs (P1 rule 3).
  static const home = '/';
  static const library = '/library';
  static const downloads = '/downloads';
  static const you = '/you';

  /// Available, from first open, before the tabs exist (P9a, P9b), and a world's page there.
  static const welcomeAvailable = '/welcome/available';
  static String welcomeWorld(String id) => '/welcome/world/$id';

  /// A world's page in Home's tab and in Library's (P9c–P9h): the same page, keeping its tab.
  static String world(String id) => '/world/$id';
  static String libraryWorld(String id) => '/library/world/$id';

  /// A production of an installed world, under the world's page it was opened from.
  static String production(String worldLocation, String productionId) => '$worldLocation/$productionId';

  /// An added file in its player, over the tabs: the audio player (P7d, P5a–P5c), the reader
  /// (P5e), the page viewer (P7c) or the film player (P3a, P3b, P3e).
  static String open(String itemId) => '/open/$itemId';
}
