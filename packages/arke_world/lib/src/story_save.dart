import 'story.dart';

/// The save format this Player writes and reads (SPEC-063 R-12): a save of any other version is one it
/// cannot read, and gets `Start again` (SPEC-058 R-88).
const storySaveVersion = 1;

/// Where a person is in a scene: a time into what the scene plays, a beat, or its end, where its
/// choices or its ending are.
sealed class StoryPlace {
  const StoryPlace();
}

/// A movie's place: the time into the scene's projected clips, played back to back.
class StoryAt extends StoryPlace {
  const StoryAt(this.at);
  final Duration at;
}

/// A novel's place: the index of the beat in its scene's beats (not in what plays).
class StoryAtBeat extends StoryPlace {
  const StoryAtBeat(this.beat);
  final int beat;
}

/// The scene played through: its choices, or its ending, are showing.
class StoryAtChoice extends StoryPlace {
  const StoryAtChoice();
}

/// Where a person is in one story (SPEC-058 R-88, SPEC-063 R-12): the route as choice ids, the scene
/// it reached and the place in it, the save's version and the fingerprint of the document it was made
/// on. What the story remembers is never kept: it follows from the route, replayed (P18 call 23).
class StorySave {
  const StorySave({required this.route, required this.scene, required this.place, required this.fingerprint, required this.updatedAt});

  /// The save at the start of [document], nothing chosen.
  factory StorySave.start(StoryDocument document, DateTime now) =>
      StorySave(route: const [], scene: document.start, place: const StoryAt(Duration.zero), fingerprint: document.fingerprint, updatedAt: now);

  /// The save at [step] of [document].
  factory StorySave.at(StoryDocument document, StoryStep step, StoryPlace place, DateTime now) =>
      StorySave(route: step.route, scene: step.scene, place: place, fingerprint: document.fingerprint, updatedAt: now);

  final List<String> route;
  final String scene;
  final StoryPlace place;
  final String fingerprint;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'version': storySaveVersion,
    'route': route,
    'scene': scene,
    ...switch (place) {
      StoryAt(:final at) => {'at': at.inMilliseconds},
      StoryAtBeat(:final beat) => {'beat': beat},
      StoryAtChoice() => {'choosing': true},
    },
    'fingerprint': fingerprint,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  /// Reads a save as [toJson] wrote it; null for anything else — another version, a missing route, a
  /// place that is not one — which is a save that cannot be read (R-88).
  static StorySave? read(Object? json) {
    if (json is! Map<String, Object?> || json['version'] != storySaveVersion) return null;
    final route = json['route'];
    final scene = json['scene'];
    final fingerprint = json['fingerprint'];
    final updatedAt = json['updatedAt'] is String ? DateTime.tryParse(json['updatedAt']! as String) : null;
    if (route is! List<Object?> || route.any((id) => id is! String) || scene is! String || fingerprint is! String || updatedAt == null) return null;
    final StoryPlace place;
    switch ((json['at'], json['beat'], json['choosing'])) {
      case (final int at, null, null) when at >= 0:
        place = StoryAt(Duration(milliseconds: at));
      case (null, final int beat, null) when beat >= 0:
        place = StoryAtBeat(beat);
      case (null, null, true):
        place = const StoryAtChoice();
      default:
        return null;
    }
    return StorySave(route: List.unmodifiable(route.cast<String>()), scene: scene, place: place, fingerprint: fingerprint, updatedAt: updatedAt);
  }
}

/// What a story's page and player offer, from its save (SPEC-058 R-88, P18 rule 6).
sealed class StoryResume {
  const StoryResume();
}

/// No save: `Play` from the start.
class StoryFresh extends StoryResume {
  const StoryFresh();
}

/// `Continue`: the route replayed on the installed document, every step legal, at [step]; [place] is
/// the save's own when the document is the one it was made on, else the scene's start.
class StoryContinue extends StoryResume {
  const StoryContinue({required this.step, required this.place, required this.save});
  final StoryStep step;
  final StoryPlace place;
  final StorySave save;
}

/// `Start again`, in place of Continue: a save that cannot be read, or a route an update made
/// illegal. The save is kept as it is until the person starts again (SPEC-063 R-14).
class StoryStartAgain extends StoryResume {
  const StoryStartAgain();
}

/// Where a person is in [document], from the [raw] save the library kept (R-88). The route is replayed
/// on the document installed: when every step is still legal it goes on, from the saved place if the
/// document is the one the save was made on; when not, or when the save cannot be read, the old save
/// stays and the story offers only `Start again`.
StoryResume resumeStory(StoryDocument document, Object? raw) {
  if (raw == null) return const StoryFresh();
  final save = StorySave.read(raw);
  if (save == null) return const StoryStartAgain();
  try {
    return switch (replayStory(document, save.route)) {
      // A save whose scene is not where its route leads was not written by this Player.
      StoryReplayed(:final step) when step.scene == save.scene => StoryContinue(
        step: step,
        place: save.fingerprint == document.fingerprint && _fits(document, step, save.place) ? save.place : const StoryAt(Duration.zero),
        save: save,
      ),
      _ => const StoryStartAgain(),
    };
  } on StoryRuleError {
    return const StoryStartAgain();
  }
}

/// Whether a kept place is one the scene has.
bool _fits(StoryDocument document, StoryStep step, StoryPlace place) => switch (place) {
  StoryAt() => document.kind == StoryKind.movie,
  StoryAtBeat(:final beat) => document.kind == StoryKind.novel && step.play.contains(beat),
  StoryAtChoice() => true,
};

/// Every step along [route] (P18 rule 4): the start, then where each choice led, in order, so the
/// route can be drawn scene by scene with the choice taken after each. Throws [StoryRouteRefused]
/// when a step is not legal.
List<StoryStep> storyPath(StoryDocument document, List<String> route) => [for (var i = 0; i <= route.length; i++) evaluateStory(document, route.sublist(0, i))];

/// How long a scene plays in [step]: its projected clips, back to back. Zero in a novel.
Duration sceneLength(StoryDocument document, StoryStep step) {
  final clips = document.scenes[step.scene]!.clips;
  return step.play.where((index) => index < clips.length).fold(Duration.zero, (sum, index) => sum + (clips[index].to - clips[index].from));
}
