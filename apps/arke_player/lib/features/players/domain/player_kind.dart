import 'package:arke_publication/arke_publication.dart';

import '../../production/domain/production_kind.dart';

/// The players. Those marked [isWebModule] are the Studio's own framework-free modules, hosted
/// in a web view so a package plays the same in the Player as in a browser (Arke Player P3
/// rule 1; docs/decisions/0001). The others are native to the Player.
enum PlayerKind {
  /// Studio turn 156 drew the interactive player; a film is its linear case (P3a, P3b).
  film(isWebModule: true),

  /// One episode a screen, swiped (P3c). Native: a feed of short videos is the phone's own idiom.
  microDrama(isWebModule: false),

  /// Studio turn 156 (P4a–P4c).
  interactive(isWebModule: true),

  /// Studio turn 174 (P4d, P4e).
  visualNovel(isWebModule: true),

  /// Studio turns 186, 211 and 212 (P5a–P5c, P7d).
  audiobook(isWebModule: true),

  /// The audiobook's transport over an edition's transcript (P5d).
  audioDrama(isWebModule: false),

  /// EPUB (P5e).
  reader(isWebModule: false),

  /// PDF and CBZ (P7c).
  pageViewer(isWebModule: false);

  const PlayerKind({required this.isWebModule});
  final bool isWebModule;
}

/// The player a production opens in.
PlayerKind playerForProduction(ProductionKind kind) => switch (kind) {
  ProductionKind.film || ProductionKind.series => PlayerKind.film,
  ProductionKind.microDrama => PlayerKind.microDrama,
  ProductionKind.interactiveMovie => PlayerKind.interactive,
  ProductionKind.visualNovel => PlayerKind.visualNovel,
  ProductionKind.audiobook => PlayerKind.audiobook,
  ProductionKind.audioDrama => PlayerKind.audioDrama,
  ProductionKind.book => PlayerKind.reader,
};

/// The player a standard file opens in (P7 rule 2), or null for what is never opened on its own:
/// an Arke package becomes a world, and captions ride beside their video.
PlayerKind? playerForFile(FileFormat format) => switch (format) {
  FileFormat.epub => PlayerKind.reader,
  FileFormat.pdf || FileFormat.cbz => PlayerKind.pageViewer,
  // A world's narration with its pictures plays in the audiobook player too (SPEC-058 R-22).
  FileFormat.m4b || FileFormat.m4a || FileFormat.mp3 || FileFormat.listening => PlayerKind.audiobook,
  FileFormat.mp4 || FileFormat.mov => PlayerKind.film,
  FileFormat.arkePackage || FileFormat.srt || FileFormat.vtt => null,
};
