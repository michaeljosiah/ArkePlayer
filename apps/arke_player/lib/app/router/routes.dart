/// Every route, with the design frames it implements. Paths are built here and nowhere else.
abstract final class Routes {
  /// First open: the wordmark, Sign in with Arke ↗, Add a file (P1a).
  static const welcome = '/welcome';

  // The four tabs (P1 rule 3).
  static const home = '/';
  static const library = '/library';
  static const downloads = '/downloads';
  static const you = '/you';

  /// A world's page, pushed inside Library (P1d, P6c).
  static String world(String worldId) => '$library/world/$worldId';

  /// A production's page (P1e, P1f).
  static String production(String worldId, String productionId) => '${world(worldId)}/production/$productionId';

  /// The Add sheet and what follows it: checking, ready, refused (P2c–P2f, P7a).
  static const add = '/add';

  /// A share link opened from outside the app (P2a, P2b).
  static String share(String token) => '/share/$token';

  /// A production in its player, over everything, tabs and dock included (P3–P5).
  static String play(String productionId) => '/play/$productionId';

  /// An added standard file in its player (P7c, P7d, P5e).
  static String open(String fileId) => '/open/$fileId';
}
