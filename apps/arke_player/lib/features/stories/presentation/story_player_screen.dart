import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/theme/tokens.dart';
import '../../players/application/players.dart';
import '../../players/presentation/chrome.dart';
import '../application/stories.dart';
import 'story_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// After a beat's voice ends, the next beat follows this much later, as P18 shipped (P19 rule 1).
const _afterVoice = Duration(milliseconds: 600);

/// How long a beat holds with no voice heard (P19 rules 1 and 5): time to read it, 1.5 s and 45 ms a
/// character, the timing P18 shipped with `Auto`. A picture held without a line holds 1.5 s.
Duration _reading(StoryBeat beat) => Duration(milliseconds: 1500 + 45 * (beat.line?.length ?? 0));

/// An interactive story in its player (SPEC-058 R-84 – R-88; Player P18b – P18h, P19, P4c – P4e): a
/// movie plays its scene's clips at the story's own shape, a visual novel plays its beats by itself;
/// a tap shows or hides the controls and never moves on (P19 rule 2). It stops only at a choice of two
/// or more, the choices in the author's order with `Replay scene`, and a lone way on plays straight
/// through (P19 rules 3, 4); at an ending, P4c's card. It opens playing where the save says, the route
/// replayed on the document installed, and keeps the route as it goes.
class StoryPlayerScreen extends ConsumerWidget {
  const StoryPlayerScreen({required this.worldId, required this.productionId, super.key});

  final String worldId;
  final String productionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(loadedStoryProvider((worldId, productionId)));
    final saves = ref.watch(storySavesProvider).value;
    final loaded = story.value;
    if (story.isLoading || saves == null) return const Scaffold(backgroundColor: _bg);
    if (loaded == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: _bg, foregroundColor: _fg),
        body: const Center(
          child: Text('Removed', style: TextStyle(color: _fg)),
        ),
      );
    }
    return _StoryPlayer(key: ValueKey(loaded.document.fingerprint), story: loaded, resume: resumeStory(loaded.document, saves[loaded.key]));
  }
}

enum _Phase { playing, choosing, ending }

/// What ⋯ offers a visual novel.
enum _More { route, startOver }

class _StoryPlayer extends ConsumerStatefulWidget {
  const _StoryPlayer({required this.story, required this.resume, super.key});

  final LoadedStory story;

  /// Where it opens; read once.
  final StoryResume resume;

  @override
  ConsumerState<_StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends ConsumerState<_StoryPlayer> {
  late StoryStep _step;
  _Phase _phase = _Phase.playing;

  /// The clip or beat playing, as an index into the step's projection.
  int _at = 0;
  StoryReel? _reel;
  late final StorySaves _saves = ref.read(storySavesProvider.notifier);
  late final StoryVoice _voice = ref.read(storyVoiceProvider);
  bool _opening = false;

  /// The controls show (P19 rule 2): a tap shows or hides them; while playing they rest after 2.5 s,
  /// and at a choice or an ending the top stays.
  bool _chrome = true;

  /// The route sheet is up: the transport under it goes, as the drawn sheet covers it (P18e).
  bool _routing = false;

  /// A sheet is up over a visual novel: the box and whatever is under it go, as the drawn sheets cover
  /// them (P4e, P19h).
  bool _sheetUp = false;
  Timer? _rest;
  DateTime _lastKept = DateTime.fromMillisecondsSinceEpoch(0);

  // A visual novel plays itself (P19 rules 1 and 5).

  /// Paused by Pause, or while a sheet is over it. A story opens playing.
  bool _paused = false;

  /// The story's voices are heard. Off, each beat holds for its reading time; it stays off for this
  /// story, kept with where you are (P19 call 26).
  late bool _narration;

  /// Raised as each beat starts and stops, so whatever waited on the one before does nothing.
  int _run = 0;

  /// The beat's voice is speaking, or paused mid-line.
  bool _speaking = false;

  /// The beat's voice has been heard through: only the 0.6 s after it is left.
  bool _heard = false;
  Timer? _hold;

  StoryDocument get _document => widget.story.document;
  bool get _movie => _document.kind == StoryKind.movie;
  StoryScene get _scene => _document.scenes[_step.scene]!;

  /// Whether the story carries voices: only then is there Narration to turn off (P19 rule 5).
  late final bool _voiced = _document.scenes.values.any((scene) => scene.beats.any((beat) => beat.voice != null));

  /// Whether the story is going on: a movie's clip playing, a novel not paused.
  bool get _playing => _movie ? (_reel?.playing ?? false) : !_paused;

  @override
  void initState() {
    super.initState();
    // Nothing else plays over a story.
    unawaited(ref.read(audioEngineProvider)?.pause());
    if (_movie) {
      _reel = ref.read(storyReelProvider)();
      _reel!.changes.addListener(_tick);
    }
    var (step, place, narration) = switch (widget.resume) {
      StoryContinue(:final step, :final place, :final save) => (step, place, save.narration),
      _ => (startStory(_document), const StoryAt(Duration.zero) as StoryPlace, true),
    };
    // A save kept at a lone way, as P18 kept one, goes straight on through it (P19 rule 4).
    if ((place is StoryAtChoice || step.play.isEmpty) && step.loneWay != null) {
      step = takeLoneWays(_document, step);
      if (step.play.isNotEmpty) place = const StoryAt(Duration.zero);
    }
    _narration = narration;
    _step = step;
    if (place is StoryAtChoice || step.play.isEmpty) {
      _phase = step.ending != null ? _Phase.ending : _Phase.choosing;
      _at = math.max(0, step.play.length - 1);
    } else if (place is StoryAtBeat) {
      _at = math.max(0, step.play.indexOf(place.beat));
    }
    final (opening, at) = (step, place);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter(opening, at);
    });
  }

  @override
  void dispose() {
    _rest?.cancel();
    _hold?.cancel();
    _keep(force: true);
    _reel?.changes.removeListener(_tick);
    unawaited(_reel?.dispose());
    unawaited(_voice.stop().catchError((Object _) {}));
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  // ---- Where the story is --------------------------------------------------------------------

  /// Enters [step] at [place]: plays it, or, played through, goes on or shows its choices or its
  /// ending.
  Future<void> _enter(StoryStep step, StoryPlace place) async {
    _stopBeat();
    _paused = false;
    setState(() {
      _step = step;
      _phase = _Phase.playing;
      _chrome = true;
    });
    if (place is StoryAtChoice || step.play.isEmpty) return _arrive();
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
    if (_movie) {
      final (index, offset) = _locate(place is StoryAt ? place.at : Duration.zero);
      _at = index;
      await _open(index, offset, play: true);
    } else {
      setState(() => _at = place is StoryAtBeat ? math.max(0, step.play.indexOf(place.beat)) : 0);
      _startBeat();
    }
    _scheduleRest();
    _keep(force: true);
  }

  /// The scene played through (R-84, R-87): a lone way on is taken straight away (P19 rule 4);
  /// otherwise the last frame or line stays, under its choices, or its ending.
  Future<void> _arrive() async {
    _rest?.cancel();
    _stopBeat();
    _paused = false;
    if (_step.loneWay != null) {
      final next = takeLoneWays(_document, _step);
      if (next.play.isNotEmpty) return _enter(next, const StoryAt(Duration.zero));
      _step = next;
    }
    setState(() {
      _phase = _step.ending != null ? _Phase.ending : _Phase.choosing;
      _at = math.max(0, _step.play.length - 1);
      _chrome = true;
    });
    if (_movie && _step.play.isNotEmpty) {
      final clip = _scene.clips[_step.play.last];
      await _open(_step.play.length - 1, clip.to - clip.from - const Duration(milliseconds: 40), play: false);
    }
    _keep(force: true);
  }

  void _choose(StoryChoice choice) => _enter(chooseStory(_document, _step, choice.id), const StoryAt(Duration.zero));

  /// `Choose again` (R-86): the route cut before that choice, at that decision again.
  void _chooseAgain(int index) {
    _stopBeat();
    setState(() => _step = chooseStoryAgain(_document, _step.route, index));
    unawaited(_arrive());
  }

  void _startOver() => _enter(startStory(_document), const StoryAt(Duration.zero));

  void _replay() => _enter(_step, const StoryAt(Duration.zero));

  void _keep({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastKept) < const Duration(seconds: 5)) return;
    _lastKept = now;
    final StoryPlace place = _phase != _Phase.playing
        ? const StoryAtChoice()
        : _movie
        ? StoryAt(_elapsed)
        : StoryAtBeat(_step.play[_at]);
    final save = StorySave.at(_document, _step, place, now.toUtc(), narration: _narration);
    final story = widget.story;
    // After this frame: the saves are watched, and one kept as the player closes must not touch the tree
    // while it is being taken down.
    unawaited(Future.microtask(() => _saves.keep(story, save)));
  }

  /// The controls rest after 2.5 s while the story plays, and never while it is paused (Studio 156).
  void _scheduleRest() {
    _rest?.cancel();
    if (_playing) _rest = Timer(ArkeSizes.chromeRest, () => mounted && _phase == _Phase.playing ? setState(() => _chrome = false) : null);
  }

  void _wake() {
    if (!mounted) return;
    setState(() => _chrome = true);
    _scheduleRest();
  }

  /// A tap shows or hides the controls; it never moves the story on (P19 rule 2).
  void _tapStage() {
    if (!_chrome) return _wake();
    _rest?.cancel();
    setState(() => _chrome = false);
  }

  // ---- A movie ------------------------------------------------------------------------------

  /// The clip a time into the scene falls in, and the time into it.
  (int, Duration) _locate(Duration at) {
    var rest = at;
    for (final (i, index) in _step.play.indexed) {
      final clip = _scene.clips[index];
      final length = clip.to - clip.from;
      if (rest < length || i == _step.play.length - 1) return (i, rest < length ? rest : length);
      rest -= length;
    }
    return (0, Duration.zero);
  }

  /// How far into the scene, its projected clips back to back.
  Duration get _elapsed {
    if (_step.play.isEmpty || _reel == null) return Duration.zero;
    var sum = Duration.zero;
    for (var i = 0; i < _at && i < _step.play.length; i++) {
      final clip = _scene.clips[_step.play[i]];
      sum += clip.to - clip.from;
    }
    final clip = _scene.clips[_step.play[_at.clamp(0, _step.play.length - 1)]];
    final into = _reel!.position - clip.from;
    return sum + (into < Duration.zero ? Duration.zero : (into > clip.to - clip.from ? clip.to - clip.from : into));
  }

  Future<void> _open(int index, Duration offset, {required bool play}) async {
    final reel = _reel!;
    final clip = _scene.clips[_step.play[index]];
    _opening = true;
    try {
      await reel.open(widget.story.pathOf(clip.asset));
      await reel.seek(clip.from + offset);
      play ? await reel.play() : await reel.pause();
    } on Object {
      // A clip that will not open is passed over, as an empty scene is (SPEC-063 R-11).
    } finally {
      _opening = false;
    }
    if (mounted) setState(() {});
  }

  void _tick() {
    if (!mounted || _opening || _phase != _Phase.playing || !_movie || _step.play.isEmpty) return;
    final reel = _reel!;
    final clip = _scene.clips[_step.play[_at]];
    final ended =
        reel.position >= clip.to || (!reel.playing && reel.length > Duration.zero && reel.position >= reel.length - const Duration(milliseconds: 250));
    if (ended) {
      if (_at + 1 < _step.play.length) {
        _at++;
        final next = _scene.clips[_step.play[_at]];
        // The next window of the same file, straight after: it plays on, with no seek to stutter.
        if (next.asset == clip.asset && (next.from - clip.to).abs() < const Duration(milliseconds: 300) && reel.playing) {
          setState(() {});
        } else {
          unawaited(_open(_at, Duration.zero, play: true));
        }
      } else {
        unawaited(reel.pause());
        unawaited(_arrive());
      }
      return;
    }
    _keep();
    setState(() {});
  }

  Future<void> _toggle() async {
    final reel = _reel!;
    reel.playing ? await reel.pause() : await reel.play();
    _keepAwake();
    _keep(force: true);
    _wake();
  }

  /// The screen stays on while a story plays itself, and may sleep while it is paused, as a film's
  /// does (P19 rule 1).
  void _keepAwake() => unawaited((_playing ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((Object _) {}));

  Future<void> _seek(Duration at) async {
    final (index, offset) = _locate(at);
    _at = index;
    await _open(index, offset, play: _reel!.playing);
    _wake();
  }

  /// P3a's back 10 and forward 10, within the scene (P19 call 27).
  Future<void> _seekBy(int seconds) {
    final length = sceneLength(_document, _step);
    final at = _elapsed + Duration(seconds: seconds);
    return _seek(at < Duration.zero ? Duration.zero : (at > length ? length : at));
  }

  // ---- A visual novel -----------------------------------------------------------------------

  StoryBeat? get _beat => _movie || _step.play.isEmpty ? null : _scene.beats[_step.play[_at.clamp(0, _step.play.length - 1)]];

  /// Stops the beat: its hold, its voice, and anything still waiting on it.
  void _stopBeat() {
    _hold?.cancel();
    _run++;
    _speaking = false;
    _heard = false;
    unawaited(_voice.stop().catchError((Object _) {}));
  }

  /// The beat at [_at] from its start, unless the story is paused.
  void _startBeat() {
    _stopBeat();
    if (!_paused) _playBeat();
  }

  /// A voiced beat, with Narration on, moves on 0.6 s after its voice ends; any other beat after its
  /// reading time (P19 rules 1 and 5).
  void _playBeat() {
    final beat = _beat;
    if (beat == null || _phase != _Phase.playing) return;
    final run = _run;
    final voice = _narration ? beat.voice : null;
    if (voice == null) {
      _hold = Timer(_reading(beat), _nextBeat);
      return;
    }
    _speaking = true;
    unawaited(
      _voice
          .play(widget.story.pathOf(voice))
          .then(
            (_) => _heardThrough(run, _afterVoice),
            // A voice that will not play leaves its line the time to read it.
            onError: (Object _) => _heardThrough(run, _reading(beat)),
          ),
    );
  }

  void _heardThrough(int run, Duration after) {
    if (!mounted || run != _run) return;
    _speaking = false;
    _heard = true;
    if (!_paused) _hold = Timer(after, _nextBeat);
  }

  void _nextBeat() {
    if (!mounted || _movie || _phase != _Phase.playing) return;
    if (_at + 1 < _step.play.length) {
      setState(() => _at++);
      _startBeat();
      _keep(force: true);
    } else {
      unawaited(_arrive());
    }
  }

  /// Pause holds the beat where it is, its voice mid-line (P19 rule 2).
  void _pauseBeat() {
    _paused = true;
    _hold?.cancel();
    if (_speaking) unawaited(_voice.pause().catchError((Object _) {}));
  }

  /// Play goes on from there: the voice from where it paused, or the 0.6 s after it. A line read
  /// without one is given its reading time again.
  void _resumeBeat() {
    _paused = false;
    if (_speaking) {
      unawaited(_voice.resume().catchError((Object _) {}));
    } else if (_heard) {
      _hold = Timer(_afterVoice, _nextBeat);
    } else {
      _playBeat();
    }
  }

  void _togglePause() {
    if (_paused) {
      _resumeBeat();
    } else {
      _pauseBeat();
    }
    setState(() {});
    _keepAwake();
    _keep(force: true);
    _wake();
  }

  /// Back: the beat before, or this one again from its start at the scene's first (P19 rule 2).
  void _back() {
    setState(() => _at = math.max(0, _at - 1));
    _startBeat();
    _keep(force: true);
    _wake();
  }

  /// Narration on or off (P19 rule 5): the beat showing starts again, heard or given its time to read.
  void _toggleNarration() {
    setState(() => _narration = !_narration);
    if (_phase == _Phase.playing) _startBeat();
    _keep(force: true);
    _wake();
  }

  // ---- Sheets -------------------------------------------------------------------------------

  /// A sheet over a visual novel holds it, and lets it go on as the sheet closes if it was playing and
  /// nothing chosen there moved it.
  Future<void> _over(Future<void> Function() sheet) async {
    final held = !_movie && _phase == _Phase.playing && !_paused;
    if (held) _pauseBeat();
    _rest?.cancel();
    setState(() => _sheetUp = true);
    await sheet();
    if (!mounted) return;
    if (held && _paused && _phase == _Phase.playing) _resumeBeat();
    setState(() => _sheetUp = false);
    _scheduleRest();
  }

  Future<void> _routeSheet() =>
      showRouteSheet(context, story: widget.story, path: storyPath(_document, _step.route), onChooseAgain: _chooseAgain, onStartOver: _startOver);

  /// The route sheet (P18e) over a movie, which stops under it: what is chosen there replaces what
  /// plays.
  Future<void> _route() async {
    if (_reel?.playing ?? false) {
      unawaited(_reel!.pause());
      _keep(force: true);
    }
    _rest?.cancel();
    setState(() => _routing = true);
    await _routeSheet();
    if (mounted) setState(() => _routing = false);
  }

  /// P4e's log: what this scene has said so far, the line now marked; a voiced line plays again.
  void _log() => unawaited(
    _over(
      () => showPlayerSheet<void>(
        context,
        title: 'Log',
        count: 'Scene ${_step.route.length + 1}',
        builder: (sheet) {
          final shown = _phase == _Phase.playing ? _step.play.take(_at + 1) : _step.play;
          return ListView(
            shrinkWrap: true,
            children: [
              for (final (i, index) in shown.indexed)
                if (_scene.beats[index] case final beat when beat.line != null)
                  _LogRow(beat: beat, now: i == shown.length - 1, onPlay: beat.voice == null ? null : () => _hearAgain(beat.voice!)),
            ],
          );
        },
      ),
    ),
  );

  /// A line heard again from the log: the beat's own voice gives way to it, and the beat starts again
  /// when the story goes on.
  void _hearAgain(String voice) {
    _stopBeat();
    unawaited(_voice.play(widget.story.pathOf(voice)).catchError((Object _) {}));
  }

  /// ⋯ (P19b): Route and Start over. A novel holds under it, and under the route sheet it opens.
  void _more() => unawaited(
    _over(() async {
      final picked = await showPlayerSheet<_More>(
        context,
        title: widget.story.production.title,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const RouteGlyph(),
              title: const Text('Route', style: TextStyle(color: _fg)),
              onTap: () => Navigator.of(sheet).pop(_More.route),
            ),
            ListTile(
              leading: const Icon(Icons.replay_rounded, color: _fg),
              title: const Text('Start over', style: TextStyle(color: _fg)),
              onTap: () => Navigator.of(sheet).pop(_More.startOver),
            ),
          ],
        ),
      );
      if (!mounted) return;
      switch (picked) {
        case _More.route:
          await _routeSheet();
        case _More.startOver:
          _startOver();
        case null:
          break;
      }
    }),
  );

  // ---- Drawing ------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    // A phone turned on its side (P18c); a Fold open, or a tablet (P18h); otherwise a phone upright.
    final turned = size.width > size.height && size.height < WindowBands.fold;
    final fold = !turned && size.width >= WindowBands.fold;
    final layout = _Layout(size: size, pad: pad, turned: turned, fold: fold);
    return Scaffold(backgroundColor: _bg, body: _movie ? _movieStage(layout) : _novelStage(layout));
  }

  Widget _top(_Layout layout, List<Widget> actions) {
    final top = PlayerTop(eyebrow: widget.story.production.title, title: _scene.title, actions: actions);
    if (layout.turned) return Positioned(top: math.max(layout.pad.top, 10), left: 36, right: 36, child: top);
    return Positioned(top: layout.pad.top, left: layout.fold ? 16 : 6, right: layout.fold ? 16 : 6, child: top);
  }

  /// A movie's choices and `Replay scene` where the layout puts them, scrolling from the first when
  /// there are more than fit (SPEC-063 R-26).
  List<Widget> _choices(_Layout layout, {double? top}) {
    final choices = StoryChoices(options: _step.options, onChoose: _choose, across: layout.turned || layout.fold);
    final replay = ReplayScene(onPressed: _replay);
    if (top != null) {
      return [
        Positioned(
          top: top,
          left: layout.fold ? 150 : 16,
          right: layout.fold ? 150 : 16,
          bottom: layout.pad.bottom + 8,
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [choices, const SizedBox(height: 20), replay]),
          ),
        ),
      ];
    }
    final side = layout.turned ? 120.0 : 16.0;
    final bottom = layout.turned ? 62.0 : 96.0 + layout.extra;
    return [
      Positioned(
        left: side,
        right: side,
        bottom: bottom,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(120, layout.size.height - bottom - (layout.turned ? 70 : 120))),
          child: SingleChildScrollView(clipBehavior: Clip.none, child: choices),
        ),
      ),
      Positioned(left: 0, right: 0, bottom: layout.turned ? 12 : 36 + layout.extra, child: replay),
    ];
  }

  Widget _ending(_Layout layout) {
    // Back to the last choice made: a lone way taken was none (P19 rule 4).
    final made = storyChoicesMade(storyPath(_document, _step.route));
    return Positioned(
      left: layout.fold ? 150 : 20,
      right: layout.fold ? 150 : 20,
      bottom: (layout.turned ? 16 : 44) + layout.extra,
      child: _Fade(
        shown: !_sheetUp,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: layout.size.height - layout.pad.top - 90),
          child: SingleChildScrollView(
            child: StoryEndingCard(story: widget.story, step: _step, onStartAgain: _startOver, onBack: made.isEmpty ? null : () => _chooseAgain(made.last)),
          ),
        ),
      ),
    );
  }

  Widget _movieStage(_Layout layout) {
    final reel = _reel!;
    final size = layout.size;
    final tall = widget.story.tallShape;
    final reelSize = reel.size == Size.zero ? (tall ? const Size(9, 16) : const Size(16, 9)) : reel.size;
    Widget picture(BoxFit fit) => FittedBox(
      fit: fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox.fromSize(size: reelSize, child: reel.view()),
    );
    final playing = _phase == _Phase.playing;
    // A 16:9 movie upright sits whole a little above the middle, where P3a holds a film (P18b); on a
    // Fold it runs the width (P18h). Turned, or 9:16 anywhere but a phone upright, it fills the
    // height (P18c). A 9:16 movie fills an upright phone (P18d). Nothing is cropped to fit.
    final upright = !layout.turned && !layout.fold;
    final fills = tall && upright;
    final across = !tall && !layout.turned;
    final width = size.width;
    final videoTop = layout.fold ? 170.0 : (size.height * 300 / 844).clamp(layout.pad.top + 64, double.infinity);
    final videoBottom = videoTop + width * 9 / 16;
    final Widget stage;
    if (fills) {
      stage = Positioned.fill(child: picture(BoxFit.cover));
    } else if (across) {
      stage = Positioned(top: videoTop, left: 0, width: width, height: width * 9 / 16, child: picture(BoxFit.contain));
    } else {
      stage = Positioned.fill(child: picture(BoxFit.contain));
    }
    final overlays = fills || layout.turned;
    final children = <Widget>[
      stage,
      if (overlays) ...[_Scrim(top: true, height: layout.turned ? 140 : 200), _Scrim(top: false, height: layout.turned ? 210 : (playing ? 320 : 560))],
      // P4c's foot, under an ending's words wherever the picture sits.
      if (!overlays && _phase == _Phase.ending) const _Scrim(top: false, height: 560),
    ];
    // A film's controls (P19 call 27): they rest while it plays, in every layout, as P3a's do.
    final chromeShown = !playing || _chrome;
    children.add(
      _Fade(
        shown: chromeShown,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _top(layout, [RoutePress(onPressed: _route)]),
            if (playing && !_routing)
              Positioned(
                left: layout.turned ? 40 : 20,
                right: layout.turned ? 40 : 20,
                bottom: (layout.turned ? 12 : 44) + layout.extra,
                child: Column(
                  children: [
                    Scrubber(position: _elapsed, length: sceneLength(_document, _step), onSeek: _seek),
                    const SizedBox(height: 10),
                    // P3a's transport without its captions and full screen: back 10, Play or Pause,
                    // forward 10 (P19f).
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PlayerPress(icon: Icons.replay_10, label: 'Back 10 seconds', onPressed: () => _seekBy(-10), size: 26),
                        const SizedBox(width: 38),
                        PlayPause(playing: reel.playing, onPressed: _toggle, small: layout.turned),
                        const SizedBox(width: 38),
                        PlayerPress(icon: Icons.forward_10, label: 'Forward 10 seconds', onPressed: () => _seekBy(10), size: 26),
                      ],
                    ),
                  ],
                ),
              ),
            if (_phase == _Phase.choosing) ..._choices(layout, top: layout.fold && across ? videoBottom + 60 : null),
            if (_phase == _Phase.ending) _ending(layout),
          ],
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: playing ? _tapStage : null,
      child: Stack(fit: StackFit.expand, children: children),
    );
  }

  Widget _novelStage(_Layout layout) {
    final beat = _beat;
    final story = widget.story;
    final size = layout.size;
    final pad = layout.pad;
    final playing = _phase == _Phase.playing;
    final upright = !layout.turned && !layout.fold;
    final tallPicture = beat == null ? null : (beat.tall ?? (story.tallShape ? beat.picture : null));
    // Upright, a beat's Tall picture fills the phone (P18f); without one its picture sits whole at the
    // top, the box under it (P18g). Turned or on a Fold, the picture is whole.
    final fills = upright && tallPicture != null;
    const pictureTop = 160.0;
    final pictureHeight = size.width * 9 / 16;
    // At a choice and an ending the top stays while it waits; playing, the controls show until they
    // rest (P19 rule 2).
    final shown = !playing || _chrome;
    final children = <Widget>[];
    if (beat != null) {
      final image = FileImage(File(story.pathOf(fills ? tallPicture : beat.picture)));
      if (fills) {
        children.add(
          Positioned.fill(
            child: Image(image: image, fit: BoxFit.cover, alignment: const Alignment(0, -0.2)),
          ),
        );
      } else if (upright) {
        children.add(
          Positioned(
            top: pictureTop,
            left: 0,
            right: 0,
            height: pictureHeight,
            child: Image(image: image, fit: BoxFit.cover),
          ),
        );
      } else {
        children.add(
          Positioned.fill(
            child: Image(image: image, fit: BoxFit.contain),
          ),
        );
      }
    }
    if (fills || !upright) {
      // Deeper while the controls show (P19a, P19b, P19g).
      children
        ..add(_Scrim(top: true, height: layout.turned ? (shown ? 150 : 75) : (shown ? 220 : 110)))
        ..add(_Scrim(top: false, height: layout.turned ? 300 : (shown ? 560 : 380)));
    }
    // The top: ⌄, the story and its scene, ⋯; Narration under it where the story has voices (P19b).
    final topEdge = layout.turned ? math.max(pad.top, 10.0) : pad.top;
    final narrationTop = topEdge + (layout.turned ? 56 : 57);
    children.add(
      Positioned.fill(
        child: _Fade(
          shown: shown,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _top(layout, [PlayerPress(icon: Icons.more_horiz, label: 'More', onPressed: _more)]),
              if (_voiced)
                Positioned(
                  top: narrationTop,
                  left: layout.turned ? 40 : 14,
                  child: NarrationSwitch(on: _narration, onPressed: _toggleNarration),
                ),
            ],
          ),
        ),
      ),
    );
    // A picture held without a line shows no box; at a choice the last line said stays (R-87). The box
    // is the story, not a control: it never moves as the controls come and go (P19 rule 2).
    final said = playing
        ? (beat?.line == null ? null : beat)
        : [for (final index in _step.play) _scene.beats[index]].lastWhere((beat) => beat.line != null, orElse: () => const StoryBeat(picture: ''));
    final box = said?.line == null || _phase == _Phase.ending ? null : _LineBox(beat: said!);
    final transport = _Transport(beats: _step.play.length, done: _at + 1, playing: !_paused, onBack: _back, onPlay: _togglePause, onLog: _log);
    final foot = ReplayScene(onPressed: _replay, onLog: _log);
    // The choices sit 4 inside the box's edges (P19e); 8 more around them keeps the first's focus ring
    // clear of the scroll's edge.
    Widget choices({required bool across}) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: StoryChoices(options: _step.options, onChoose: _choose, across: across),
    );
    Widget inBox(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child);
    // Under a sheet the box and what is under it go; the top stays (P4e).
    Widget under(Widget child) => _Fade(shown: !_sheetUp, child: child);
    // Replay scene and Log are 40 high as drawn and laid out 48 for the thumb, so the gaps around them
    // below are the drawn ones less those 4s.

    if (upright && !fills) {
      // The box under the picture, where it stays; the controls at the foot, where a film's sit, and at
      // a choice the choices in their place, Replay scene and Log under them (P19c – P19e).
      final boxTop = pictureTop + pictureHeight + 31;
      if (_phase == _Phase.choosing) {
        children.add(
          Positioned(
            top: boxTop,
            left: 8,
            right: 8,
            bottom: 26 + layout.extra,
            child: under(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (box != null) inBox(box),
                  Expanded(
                    child: Align(alignment: Alignment.bottomCenter, child: choices(across: false)),
                  ),
                  const SizedBox(height: 16),
                  foot,
                ],
              ),
            ),
          ),
        );
      } else {
        if (box != null) children.add(Positioned(top: boxTop, left: 12, right: 12, child: under(box)));
        if (playing) {
          children.add(
            Positioned(
              left: 12,
              right: 12,
              bottom: 44 + layout.extra,
              child: _Fade(shown: _chrome && !_sheetUp, child: transport),
            ),
          );
        }
      }
    } else {
      // On a Tall picture, turned or on a Fold: the box at the foot, where it stays; the controls above
      // it while they show, and at a choice the choices in their place, Replay scene and Log under
      // them (P19b, P19g).
      final side = layout.turned ? 170.0 : (layout.fold ? math.max(12.0, (size.width - 640) / 2) : 12.0);
      final bottom = (layout.turned ? 30.0 : 42.0) + layout.extra;
      if (_phase == _Phase.choosing) {
        final clear = _voiced ? narrationTop + ArkeSizes.press + 4 : topEdge + 56;
        children.add(
          Positioned(
            top: clear,
            left: side - 4,
            right: side - 4,
            bottom: bottom,
            child: under(
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(child: choices(across: !upright)),
                  SizedBox(height: layout.turned ? 4 : 16),
                  foot,
                  if (box != null) ...[SizedBox(height: layout.turned ? 12 : 26), inBox(box)],
                ],
              ),
            ),
          ),
        );
      } else {
        children.add(
          Positioned(
            left: side,
            right: side,
            bottom: bottom,
            child: under(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (playing) _Fade(shown: _chrome, child: transport),
                  if (box != null) ...[if (playing) const SizedBox(height: 30), box],
                ],
              ),
            ),
          ),
        );
      }
    }
    if (_phase == _Phase.ending) children.add(_ending(layout));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: playing ? _tapStage : null,
      child: Stack(fit: StackFit.expand, children: children),
    );
  }
}

/// What the layouts need of the screen.
class _Layout {
  const _Layout({required this.size, required this.pad, required this.turned, required this.fold});
  final Size size;
  final EdgeInsets pad;
  final bool turned;
  final bool fold;

  /// A foot taller than the drawn phone's 34 lifts what sits on it.
  double get extra => math.max(0, pad.bottom - 34);
}

/// Controls fading in and out, and untouchable while out.
class _Fade extends StatelessWidget {
  const _Fade({required this.shown, required this.child});
  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !shown,
    child: AnimatedOpacity(opacity: shown ? 1 : 0, duration: const Duration(milliseconds: 200), child: child),
  );
}

/// The scrims the chrome sits on (Studio 156): from the top, 74% fading out; from the foot, 90% to
/// 12% of its height, fading out. They deepen and lift as the controls come and go.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.top, required this.height});
  final bool top;
  final double height;

  @override
  Widget build(BuildContext context) => AnimatedPositioned(
    duration: const Duration(milliseconds: 200),
    left: 0,
    right: 0,
    top: top ? 0 : null,
    bottom: top ? null : 0,
    height: height,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: top
              ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bg.withValues(alpha: 0.74), _bg.withValues(alpha: 0)])
              : LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_bg.withValues(alpha: 0.9), _bg.withValues(alpha: 0.9), _bg.withValues(alpha: 0)],
                  stops: const [0, 0.12, 1],
                ),
        ),
      ),
    ),
  );
}

/// P4d's box: glass, the speaker's name in a pill over its top edge, and the line, narration upright as
/// P19e draws it (only the log sets narration in italics, P4e). The story moves on by itself, so it
/// draws no › (P19 rule 2).
class _LineBox extends StatelessWidget {
  const _LineBox({required this.beat});
  final StoryBeat beat;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ArkeRadius.xxl);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), offset: Offset(0, 10), blurRadius: 15, spreadRadius: -3),
              BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -4),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                decoration: BoxDecoration(
                  color: _bg.withValues(alpha: 0.52),
                  borderRadius: radius,
                  border: Border.all(color: _fg.withValues(alpha: 0.2)),
                ),
                child: Text(
                  beat.line!,
                  style: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeLg, height: 1.5, letterSpacing: -0.18, color: _fg),
                ),
              ),
            ),
          ),
        ),
        if (beat.speaker != null)
          Positioned(
            left: 18,
            top: -15,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _fg, borderRadius: BorderRadius.circular(ArkeRadius.pill)),
              child: Text(
                beat.speaker!.toUpperCase(),
                style: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeXs, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: _bg),
              ),
            ),
          ),
      ],
    );
  }
}

/// A visual novel's transport (P19 rule 2, P19b): the scene's beats where a film's scrubber sits,
/// then Back, Play or Pause on the centre line, and Log.
class _Transport extends StatelessWidget {
  const _Transport({required this.beats, required this.done, required this.playing, required this.onBack, required this.onPlay, required this.onLog});
  final int beats;
  final int done;
  final bool playing;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _BeatDashes(count: beats, done: done),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: PlayerLabelPress(label: 'Back', icon: Icons.skip_previous_rounded, onPressed: onBack),
            ),
          ),
          const SizedBox(width: 22),
          PlayPause(playing: playing, onPressed: onPlay),
          const SizedBox(width: 22),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: PlayerLabelPress(label: 'Log', icon: Icons.format_list_bulleted_rounded, onPressed: onLog),
            ),
          ),
        ],
      ),
    ],
  );
}

/// How far through the scene's beats: a dash a beat, those played in full ink.
class _BeatDashes extends StatelessWidget {
  const _BeatDashes({required this.count, required this.done});
  final int count;
  final int done;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(color: i < done ? _fg : _fg.withValues(alpha: 0.24), borderRadius: BorderRadius.circular(ArkeRadius.pill)),
          ),
        ],
      ],
    ),
  );
}

/// A line in the log (P4e): its speaker over it, narration in italics, the line now marked, and play
/// for a voiced one.
class _LogRow extends StatelessWidget {
  const _LogRow({required this.beat, required this.now, required this.onPlay});
  final StoryBeat beat;
  final bool now;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) => Container(
    color: now ? _fg.withValues(alpha: 0.08) : null,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (beat.speaker != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    beat.speaker!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: ArkeType.family,
                      fontSize: ArkeType.size2xs,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.55,
                      color: _fg.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              Text(
                beat.line!,
                style: TextStyle(
                  fontFamily: ArkeType.family,
                  fontSize: ArkeType.sizeMd,
                  height: 1.6,
                  color: _fg,
                  fontStyle: beat.speaker == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
        if (onPlay != null) ...[
          const SizedBox(width: 12),
          IconButton(
            onPressed: onPlay,
            tooltip: 'Play',
            style: IconButton.styleFrom(
              fixedSize: const Size(36, 36),
              minimumSize: const Size(36, 36),
              backgroundColor: _fg.withValues(alpha: 0.1),
              foregroundColor: _fg,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
          ),
        ],
      ],
    ),
  );
}
