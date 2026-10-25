import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../worlds/application/worlds.dart';

/// `Album`, `Single`, `Soundtrack` (SPEC-060 R-1).
String musicKindLabel(String kind) => switch (kind) {
  'single' => 'Single',
  'soundtrack' => 'Soundtrack',
  _ => 'Album',
};

/// A music tile's kind line on a world's page (SPEC-058 R-73, P17a): `Album · 9 tracks`,
/// `Single · 3:42`, `Soundtrack · 14 tracks`.
String musicTileKind(String kind, {required int tracks, required Duration length}) =>
    kind == 'single' ? 'Single · ${formatLength(length)}' : '${musicKindLabel(kind)} · ${tracks == 1 ? '1 track' : '$tracks tracks'}';

/// An album page's meta line (R-74, P17c): `Album · The Undersong · 9 tracks · 34 min`. A soundtrack
/// names what it is for in its world's place (P17 rule 1): `Soundtrack · The Bell Watch · …`.
String musicMeta(String kind, {required String of, required int tracks, required Duration length}) =>
    [musicKindLabel(kind), of, if (kind != 'single') tracks == 1 ? '1 track' : '$tracks tracks', formatLength(length)].join(' · ');

/// The title of the production a soundtrack is for, from what the phone has: the installed world,
/// Arke's list, the guide.
String? soundtrackFor(String? productionId, {LibraryWorld? world, CatalogueWorld? listed, Guide? guide}) {
  if (productionId == null) return null;
  return world?.productions.where((production) => production.id == productionId).firstOrNull?.title ??
      listed?.productions.where((production) => production.id == productionId).firstOrNull?.title ??
      guide?.productions.where((production) => production.id == productionId).firstOrNull?.title;
}

/// An installed music production ready to play (SPEC-058 R-74, R-75): its document, where each
/// track's file is, and its square cover. Its tracks play back to back on one clock, as a narration's
/// chapters do, so the scrubber, previous and next read the same.
class MusicAlbum {
  MusicAlbum({required this.worldId, required this.worldName, required this.production, required this.document, required this.pathOf, this.cover})
    : starts = [for (var i = 0, at = Duration.zero; i < document.tracks.length; at += document.tracks[i].duration, i++) at];

  final String worldId;
  final String worldName;
  final LibraryProduction production;
  final MusicDocument document;

  /// The cover, an absolute path; null when the package carried none.
  final String? cover;

  /// A file of the production's package, by asset id, as an absolute path.
  final String Function(String assetId) pathOf;

  /// Where each track starts on the album's clock.
  final List<Duration> starts;

  /// The engine's id for what it plays: one album of one world.
  String get id => 'music:$worldId/${production.id}';
  String get title => production.title;
  List<MusicTrack> get tracks => document.tracks;
  Duration get length => document.duration;
  String trackPath(int index) => pathOf(tracks[index].audio);

  /// `Album · The Undersong · 9 tracks · 34 min` (P17c).
  String get meta => musicMeta(document.kind.name, of: worldName, tracks: tracks.length, length: length);

  /// The track playing at [time] on the album's clock, and how far into it.
  (int, Duration) locate(Duration time) {
    var index = 0;
    for (final (i, start) in starts.indexed) {
      if (start <= time) index = i;
    }
    final offset = time - starts[index];
    final duration = tracks[index].duration;
    return (index, offset < Duration.zero ? Duration.zero : (offset > duration ? duration : offset));
  }

  /// The album as one library item, for the dock and the engine's clock: never kept in the library,
  /// so a song keeps no place and never joins Continue (P17 call 20).
  LibraryItem get asItem => LibraryItem(
    id: id,
    format: FileFormat.m4a,
    title: title,
    byteLength: production.package?.byteLength ?? 0,
    addedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    file: '',
    duration: length,
    cover: production.picture,
    chapters: [for (final (i, track) in tracks.indexed) Chapter(title: track.title, start: starts[i], id: track.id)],
    worldId: worldId,
  );
}

/// Repeat's three states, as a music player cycles them: off, the album, the one track.
enum MusicRepeat {
  off,
  all,
  one;

  MusicRepeat get next => MusicRepeat.values[(index + 1) % MusicRepeat.values.length];

  String get label => switch (this) {
    MusicRepeat.off => 'Repeat off',
    MusicRepeat.all => 'Repeat album',
    MusicRepeat.one => 'Repeat track',
  };
}

/// Where Previous goes (P17d): back to the start of the track once it is past its first three
/// seconds, else to the track before; the first track goes to its start.
int previousTrack(int index, Duration intoTrack) => intoTrack > const Duration(seconds: 3) || index == 0 ? index : index - 1;

/// A track's words as written, by stanza (SPEC-058 R-76, P17e): the structure tags the singing model
/// reads — `[verse]`, `[chorus]` — are labels, not lines, so they are left out; a blank line or a tag
/// starts a new stanza.
List<String> lyricStanzas(String text) {
  final stanzas = <String>[];
  final lines = <String>[];
  void close() {
    if (lines.isNotEmpty) stanzas.add(lines.join('\n'));
    lines.clear();
  }

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || RegExp(r'^\[[^\]]*\]$').hasMatch(line)) {
      close();
    } else {
      lines.add(line);
    }
  }
  close();
  return stanzas;
}

/// Reads an installed music production's document against the manifest kept beside its files
/// (SPEC-058 R-70): its own package's folder, or its world's when it came in the edition.
Future<MusicAlbum> loadMusicAlbum(LibraryStore store, LibraryWorld world, LibraryProduction production) async {
  final music = production.music;
  if (music == null) throw const FormatException('not music');
  final separator = Platform.pathSeparator;
  final folder = production.package == null ? store.worldDirectory(world.id).path : store.resolve(production.package!.folder);
  final manifest = switch (readWorldManifest(await File('$folder$separator$worldManifestFile').readAsString())) {
    WorldManifestOk(:final manifest) => manifest,
    WorldManifestRefused(:final reason) => throw FormatException(reason),
  };
  final document = switch (readMusic(await File(store.resolve(music.document)).readAsString(), manifest.assets)) {
    MusicOk(:final document) => document,
    MusicRefused(:final reason) => throw FormatException(reason),
  };
  return MusicAlbum(
    worldId: world.id,
    worldName: world.name,
    production: production,
    document: document,
    pathOf: (assetId) => '$folder$separator${manifest.assets[assetId]!.path.replaceAll('/', separator)}',
    cover: production.picture == null ? null : store.resolve(production.picture!),
  );
}

/// An installed world's music production, read and ready to play; null when it is not installed or
/// not music.
final musicAlbumProvider = FutureProvider.family<MusicAlbum?, (String, String)>((ref, key) async {
  final (worldId, productionId) = key;
  final store = await ref.watch(libraryStoreProvider.future);
  final world = ref.watch(installedWorldProvider(worldId));
  final production = world?.productions.where((production) => production.id == productionId).firstOrNull;
  if (world == null || production?.music == null) return null;
  return loadMusicAlbum(store, world, production!);
});

/// Every installed music production of a world, read: what a production's Music, a chapter's note
/// and a character's Theme are found in (SPEC-058 R-77).
final worldMusicProvider = FutureProvider.family<List<MusicAlbum>, String>((ref, worldId) async {
  final world = ref.watch(installedWorldProvider(worldId));
  if (world == null) return const [];
  return [
    for (final production in world.productions)
      if (production.music != null) ?await ref.watch(musicAlbumProvider((world.id, production.id)).future).catchError((Object _) => null),
  ];
});

/// The guide's character or place whose theme a track is (SPEC-059 R-35, R-37): `Theme · The
/// Chorister`. A theme follows its entry's gate, so one waiting for a chapter names nobody yet.
GuideEntry? themeEntry(Guide? guide, GuideReach reach, String productionId, String trackId) {
  for (final entry in [...?guide?.characters, ...?guide?.places]) {
    final theme = switch (entry) {
      GuideCharacter(:final theme) => theme,
      GuidePlace(:final theme) => theme,
      _ => null,
    };
    if (theme != null && theme.production == productionId && theme.track == trackId && reach.shows(entry.after)) return entry;
  }
  return null;
}

/// Where a track is heard, as this phone can reach it (SPEC-058 R-77): the production's title and
/// the chapter's number; and, when the production is installed, its narration and chapter to open
/// at the moment. Before that the row only names it.
class HeardPlace {
  const HeardPlace({required this.title, required this.heard, this.number, this.narration, this.chapter});

  final String title;
  final MusicHeardIn heard;
  final int? number;
  final LibraryItem? narration;
  final Chapter? chapter;

  bool get opens => narration != null && chapter != null;

  /// `Heard in · The Ledger of Nights, Chapter 8`.
  String get line => number == null ? 'Heard in · $title' : 'Heard in · $title, Chapter $number';
}

/// [heard] as this phone can reach it; null when nothing here names its production. The chapter's
/// number is the guide's, the author's numbering, else its place in the narration.
HeardPlace? heardPlace(MusicHeardIn heard, {LibraryWorld? world, Map<String, LibraryItem> items = const {}, CatalogueWorld? listed, Guide? guide}) {
  final production = world?.productions.where((production) => production.id == heard.production).firstOrNull;
  final told = guide?.productions.where((production) => production.id == heard.production).firstOrNull;
  final title = production?.title ?? listed?.productions.where((production) => production.id == heard.production).firstOrNull?.title ?? told?.title;
  if (title == null) return null;
  final narration = items[production?.narration];
  final index = narration?.chapters.indexWhere((chapter) => chapter.id == heard.chapter) ?? -1;
  final number = told?.chapters.where((chapter) => chapter.id == heard.chapter).firstOrNull?.number;
  return HeardPlace(
    title: title,
    heard: heard,
    number: number ?? (index >= 0 ? index + 1 : null),
    narration: index >= 0 ? narration : null,
    chapter: index >= 0 ? narration!.chapters[index] : null,
  );
}

/// A track of a world's music where it is heard (R-77): the album, the track, the row naming it.
typedef HeardTrack = ({MusicAlbum album, int track, MusicHeardIn heard});

/// The tracks heard in a production of a world, in album order (P17g).
List<HeardTrack> tracksHeardIn(List<MusicAlbum> music, String productionId) => [
  for (final album in music)
    for (final (i, track) in album.tracks.indexed)
      for (final heard in track.heardIn)
        if (heard.production == productionId) (album: album, track: i, heard: heard),
];
