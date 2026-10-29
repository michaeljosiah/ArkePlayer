import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../../app/services.dart';
import '../../add_file/application/file_importer.dart';
import '../../add_file/application/video_poster.dart';
import '../../players/application/players.dart';
import '../../worlds/application/worlds.dart';

/// `Interactive movie` or `Visual novel`, as a story's kind line names it (P18a).
String storyKindLabel(String kind) => kind == 'novel' ? 'Visual novel' : 'Interactive movie';

/// `14 scenes`.
String sceneCount(int count) => count == 1 ? '1 scene' : '$count scenes';

/// A tile's kind line: `Interactive movie · 14 scenes`.
String storyTileKind(LibraryStory story) => '${storyKindLabel(story.kind)} · ${sceneCount(story.scenes)}';

/// An installed story, read (SPEC-058 R-80): its document, read against the package's own manifest,
/// and where each of its files is on the phone.
class LoadedStory {
  const LoadedStory({
    required this.worldId,
    required this.worldName,
    required this.production,
    required this.document,
    required this.pathOf,
    this.cover,
    this.tall,
  });

  final String worldId;
  final String worldName;
  final LibraryProduction production;
  final StoryDocument document;

  /// An asset id's file.
  final String Function(String assetId) pathOf;

  /// The production's wide cover and its Tall cover, as files.
  final String? cover;
  final String? tall;

  /// This story's key among the saves.
  String get key => LibraryStore.storyKey(worldId, production.id);

  bool get tallShape => document.shape == StoryShape.tall;
}

/// A story of an installed world, by world and production id; null when it is not installed, or its
/// document cannot be read.
final loadedStoryProvider = FutureProvider.family<LoadedStory?, (String, String)>((ref, key) async {
  final (worldId, productionId) = key;
  final world = ref.watch(installedWorldProvider(worldId));
  final production = world?.productions.where((production) => production.id == productionId).firstOrNull;
  final story = production?.story;
  final package = production?.package;
  if (world == null || production == null || story == null || package == null) return null;
  final store = await ref.watch(libraryStoreProvider.future);
  final separator = Platform.pathSeparator;
  final folder = store.resolve(package.folder);
  try {
    final manifest = switch (readWorldManifest(await File('$folder$separator$worldManifestFile').readAsString())) {
      WorldManifestOk(:final manifest) => manifest,
      WorldManifestRefused() => null,
    };
    if (manifest == null) return null;
    final document = switch (readStory(await File(store.resolve(story.document)).readAsString(), manifest.assets)) {
      StoryOk(:final document) => document,
      StoryRefused() => null,
    };
    if (document == null) return null;
    return LoadedStory(
      worldId: world.id,
      worldName: world.name,
      production: production,
      document: document,
      pathOf: (assetId) => '$folder$separator${manifest.assets[assetId]!.path.replaceAll('/', separator)}',
      cover: production.picture == null ? null : store.resolve(production.picture!),
      tall: story.tall == null ? null : store.resolve(story.tall!),
    );
  } on FileSystemException {
    return null;
  }
});

/// Every story's save, by [LibraryStore.storyKey] (SPEC-058 R-88), kept in the library's index with
/// the places, so a save is written as atomically as a place is.
class StorySaves extends AsyncNotifier<Map<String, Map<String, Object?>>> {
  @override
  Future<Map<String, Map<String, Object?>>> build() async {
    final store = await ref.watch(libraryStoreProvider.future);
    final changes = store.storyChanges.listen((stories) => state = AsyncData(stories));
    ref.onDispose(changes.cancel);
    return store.stories;
  }

  /// Keeps where a person is in [story], or forgets it.
  Future<void> keep(LoadedStory story, StorySave? save) async {
    if (!ref.mounted) return;
    final store = await ref.read(libraryStoreProvider.future);
    await store.keepStory(story.worldId, story.production.id, save?.toJson());
  }

  /// Keeps the page a person is on in a graphic novel, beside the stories' places (P20 rule 8).
  Future<void> keepPage(String worldId, String productionId, int page) async {
    if (!ref.mounted) return;
    final store = await ref.read(libraryStoreProvider.future);
    await store.keepStory(worldId, productionId, {'comicPage': page});
  }
}

final storySavesProvider = AsyncNotifierProvider<StorySaves, Map<String, Map<String, Object?>>>(StorySaves.new);

/// What a story offers from its save (R-88): Play, Continue or Start again. Null until both are read.
final storyResumeProvider = Provider.family<StoryResume?, (String, String)>((ref, key) {
  final story = ref.watch(loadedStoryProvider(key)).value;
  final saves = ref.watch(storySavesProvider).value;
  if (story == null || saves == null) return null;
  return resumeStory(story.document, saves[story.key]);
});

/// One clip's player for a movie (P18b – P18d, P18h): a file opened, a window of it played. The
/// platform's video player in the app; a still picture under test, which never plays.
abstract class StoryReel {
  /// Opens [path], if it is not the file open already.
  Future<void> open(String path);
  Future<void> seek(Duration at);
  Future<void> play();
  Future<void> pause();
  Duration get position;
  bool get playing;

  /// The open file's length; zero until opened.
  Duration get length;

  /// The picture's own size, for its shape; zero until opened.
  Size get size;

  /// Ticks as it plays.
  Listenable get changes;
  Widget view();
  Future<void> dispose();
}

class _Ticks extends ChangeNotifier {
  void tick() => notifyListeners();
}

class VideoStoryReel extends StoryReel {
  VideoPlayerController? _video;
  String? _path;
  final _changes = _Ticks();

  @override
  Future<void> open(String path) async {
    if (path == _path && _video != null) return;
    final before = _video;
    final video = VideoPlayerController.file(File(path));
    await video.initialize();
    video.addListener(_changes.tick);
    _video = video;
    _path = path;
    _changes.tick();
    await before?.dispose();
  }

  @override
  Future<void> seek(Duration at) async => _video?.seekTo(at);
  @override
  Future<void> play() async => _video?.play();
  @override
  Future<void> pause() async => _video?.pause();
  @override
  Duration get position => _video?.value.position ?? Duration.zero;
  @override
  bool get playing => _video?.value.isPlaying ?? false;
  @override
  Duration get length => _video?.value.duration ?? Duration.zero;
  @override
  Size get size => _video?.value.size ?? Size.zero;
  @override
  Listenable get changes => _changes;
  @override
  Widget view() => _video == null ? const SizedBox.shrink() : VideoPlayer(_video!);
  @override
  Future<void> dispose() async {
    await _video?.dispose();
    _changes.dispose();
  }
}

final storyReelProvider = Provider<StoryReel Function()>((ref) => VideoStoryReel.new);

/// A visual novel's voices (P18 rule 5, P19 rule 1): a beat's line, heard as it shows. [play] completes
/// when the line has been heard through, or is stopped or replaced; a line paused mid-way waits for
/// [resume], so the story moves on only when its voice ends.
abstract interface class StoryVoice {
  Future<void> play(String path);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

class _PlayerStoryVoice implements StoryVoice {
  _PlayerStoryVoice(this._ref);
  final Ref _ref;
  AudioPlayer? _player;

  /// Raised by every play and stop, so a line stopped or replaced while it loads never starts.
  int _line = 0;

  @override
  Future<void> play(String path) async {
    final line = ++_line;
    await _ref.read(audioEngineProvider)?.pause();
    final player = _player ??= AudioPlayer();
    await player.setFilePath(path);
    if (line != _line) return;
    // Not play()'s own future, which completes on a pause too: a paused line has not been heard. It
    // has when the player completes it, or stops (idle).
    final heard = player.processingStateStream.firstWhere((state) => state == ProcessingState.completed || state == ProcessingState.idle);
    unawaited(player.play().catchError((Object _) {}));
    await heard;
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> resume() async {
    final player = _player;
    if (player != null) unawaited(player.play().catchError((Object _) {}));
  }

  @override
  Future<void> stop() async {
    _line++;
    await _player?.stop();
  }
}

final storyVoiceProvider = Provider<StoryVoice>((ref) {
  final voice = _PlayerStoryVoice(ref);
  ref.onDispose(() => voice._player?.dispose());
  return voice;
});

/// A still of a scene, by world, production and scene id, at the story's shape (P18 rule 4): a
/// novel's first picture, a movie's first frame, taken once by the platform's decoder and kept beside
/// the library. A frame that cannot be taken is the production's cover.
final storyStillProvider = FutureProvider.family<ImageProvider?, (String, String, String)>((ref, key) async {
  final (worldId, productionId, sceneId) = key;
  final story = await ref.watch(loadedStoryProvider((worldId, productionId)).future);
  final scene = story?.document.scenes[sceneId];
  if (story == null || scene == null) return null;
  final cover = story.cover == null ? null : FileImage(File(story.cover!));
  if (scene.beats.isNotEmpty) {
    final beat = scene.beats.first;
    return FileImage(File(story.pathOf(story.tallShape ? beat.tall ?? beat.picture : beat.picture)));
  }
  if (scene.clips.isEmpty) return cover;
  final root = await ref.watch(libraryRootProvider.future);
  final separator = Platform.pathSeparator;
  final still = File(
    [root.parent.path, 'stills', story.worldId, story.production.id, story.document.fingerprint.substring(7, 23), '$sceneId.jpg'].join(separator),
  );
  if (await still.exists()) return FileImage(still);
  await still.parent.create(recursive: true);
  final taken = await ref.read(storyPosterProvider).save(story.pathOf(scene.clips.first.asset), still.path).catchError((Object _) => false);
  return taken && await still.exists() ? FileImage(still) : cover;
});

/// The platform's decoder, for a movie scene's still.
final storyPosterProvider = Provider<VideoPoster>((ref) => const NativeVideoPoster());
