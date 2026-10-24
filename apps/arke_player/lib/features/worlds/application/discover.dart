import 'package:arke_world/arke_world.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../players/application/players.dart';
import '../../production/domain/production_kind.dart';

/// The time Discover and Home count days by. Replaced in tests, which fix the day.
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// A part Arke's list names as released lately, with its world and its production (SPEC-058 R-49,
/// R-52).
class FreshPart {
  const FreshPart({required this.world, required this.part, this.production});
  final CatalogueWorld world;
  final CataloguePart part;
  final CatalogueProduction? production;

  /// What it is a part of, as the list's kind line names it.
  ProductionKind get kind => production == null ? ProductionKind.audiobook : ProductionKind.ofLine(production!.kind);

  /// Watched in episodes: a micro drama or a series.
  bool get episodes => kind == ProductionKind.microDrama || kind == ProductionKind.series;
}

/// New chapters (P15 rule 7): every listed world's parts released in the last 14 days, newest
/// first; with [only], those of the worlds it names (Home's: the installed worlds').
List<FreshPart> freshParts(Iterable<CatalogueWorld> catalogue, DateTime now, {bool Function(CatalogueWorld world)? only}) {
  final since = DateTime.utc(now.year, now.month, now.day).subtract(const Duration(days: 14));
  final fresh = [
    for (final world in catalogue)
      if (only == null || only(world))
        for (final part in world.package?.parts ?? const <CataloguePart>[])
          if (!part.released.isBefore(since))
            FreshPart(world: world, part: part, production: world.productions.where((production) => production.id == part.production).firstOrNull),
  ];
  return fresh..sort((a, b) => b.part.released.compareTo(a.part.released));
}

/// Whether a part came out within the last week, which its tile marks `New` (P15a).
bool releasedThisWeek(CataloguePart part, DateTime now) =>
    !part.released.isBefore(DateTime.utc(now.year, now.month, now.day).subtract(const Duration(days: 7)));

/// A clip's narration, with sound once it is opened (SPEC-059 R-32), pausing the narration first so
/// two never speak at once. Replaced in tests, which never play.
abstract interface class TeaserAudio {
  Future<void> play(String path);
  Future<void> stop();
}

class _PlayerTeaserAudio implements TeaserAudio {
  _PlayerTeaserAudio(this._ref);
  final Ref _ref;
  AudioPlayer? _player;

  @override
  Future<void> play(String path) async {
    await _ref.read(audioEngineProvider)?.pause();
    final player = _player ??= AudioPlayer();
    await player.setFilePath(path);
    await player.play();
  }

  @override
  Future<void> stop() async => _player?.stop();
}

final teaserAudioProvider = Provider<TeaserAudio>((ref) {
  final audio = _PlayerTeaserAudio(ref);
  ref.onDispose(() => audio._player?.dispose());
  return audio;
});
