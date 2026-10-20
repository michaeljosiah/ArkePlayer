/// Every route of the MVP, with the design frames it implements. Paths are built here and nowhere
/// else. Worlds, productions, shares and the Add sheet return after the MVP (docs/mvp.md, "Out").
abstract final class Routes {
  /// First open, before sign-in exists: the wordmark and Add a file (P8a).
  static const welcome = '/welcome';

  // The four tabs (P1 rule 3).
  static const home = '/';
  static const library = '/library';
  static const downloads = '/downloads';
  static const you = '/you';

  /// An added file in its player, over the tabs: the audio player (P7d, P5a–P5c), the reader
  /// (P5e), the page viewer (P7c) or the film player (P3a, P3b, P3e).
  static String open(String itemId) => '/open/$itemId';
}
