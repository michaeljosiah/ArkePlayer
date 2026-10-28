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

/// An interactive story in its player (SPEC-058 R-84 – R-88; Player P18b – P18h, P4c – P4e): a movie
/// plays its scene's clips at the story's own shape, a visual novel reads its beats; at the scene's end
/// the choices, in the author's order, and `Replay scene`; at an ending, P4c's card. It opens where the
/// save says, the route replayed on the document installed, and keeps the route as it goes.
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
  bool _chrome = true;

  /// The route sheet is up: the transport under it goes, as the drawn sheet covers it (P18e).
  bool _routing = false;
  bool _auto = false;
  Timer? _rest;
  Timer? _autoNext;
  int _spoken = 0;
  DateTime _lastKept = DateTime.fromMillisecondsSinceEpoch(0);

  StoryDocument get _document => widget.story.document;
  bool get _movie => _document.kind == StoryKind.movie;
  StoryScene get _scene => _document.scenes[_step.scene]!;

  @override
  void initState() {
    super.initState();
    // Nothing else plays over a story.
    unawaited(ref.read(audioEngineProvider)?.pause());
    if (_movie) {
      _reel = ref.read(storyReelProvider)();
      _reel!.changes.addListener(_tick);
    }
    final (step, place) = switch (widget.resume) {
      StoryContinue(:final step, :final place) => (step, place),
      _ => (startStory(_document), const StoryAt(Duration.zero) as StoryPlace),
    };
    _step = step;
    if (place is StoryAtChoice || step.play.isEmpty) {
      _phase = step.ending != null ? _Phase.ending : _Phase.choosing;
      _at = math.max(0, step.play.length - 1);
    } else if (place is StoryAtBeat) {
      _at = math.max(0, step.play.indexOf(place.beat));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter(step, place);
    });
  }

  @override
  void dispose() {
    _rest?.cancel();
    _autoNext?.cancel();
    _keep(force: true);
    _reel?.changes.removeListener(_tick);
    unawaited(_reel?.dispose());
    unawaited(_voice.stop().catchError((Object _) {}));
    if (_movie) unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  // ---- Where the story is --------------------------------------------------------------------

  /// Enters [step] at [place]: plays it, or, played through, shows its choices or its ending.
  Future<void> _enter(StoryStep step, StoryPlace place) async {
    _autoNext?.cancel();
    _spoken++;
    unawaited(_voice.stop().catchError((Object _) {}));
    setState(() {
      _step = step;
      _phase = _Phase.playing;
      _chrome = true;
    });
    if (place is StoryAtChoice || step.play.isEmpty) return _arrive();
    if (_movie) {
      final (index, offset) = _locate(place is StoryAt ? place.at : Duration.zero);
      _at = index;
      await _open(index, offset, play: true);
      unawaited(WakelockPlus.enable().catchError((Object _) {}));
      _scheduleRest();
    } else {
      setState(() => _at = place is StoryAtBeat ? math.max(0, step.play.indexOf(place.beat)) : 0);
      unawaited(_speak());
    }
    _keep(force: true);
  }

  /// The scene played through (R-84, R-87): its last frame or line stays, under its choices, or its
  /// ending.
  Future<void> _arrive() async {
    _rest?.cancel();
    _autoNext?.cancel();
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
    _spoken++;
    unawaited(_voice.stop().catchError((Object _) {}));
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
    final save = StorySave.at(_document, _step, place, now.toUtc());
    final story = widget.story;
    // After this frame: the saves are watched, and one kept as the player closes must not touch the tree
    // while it is being taken down.
    unawaited(Future.microtask(() => _saves.keep(story, save)));
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
    _keep(force: true);
    _wake();
  }

  Future<void> _seek(Duration at) async {
    final (index, offset) = _locate(at);
    _at = index;
    await _open(index, offset, play: _reel!.playing);
    _wake();
  }

  void _scheduleRest() {
    _rest?.cancel();
    if (_reel?.playing ?? false) _rest = Timer(ArkeSizes.chromeRest, () => mounted && _phase == _Phase.playing ? setState(() => _chrome = false) : null);
  }

  void _wake() {
    if (!mounted) return;
    setState(() => _chrome = true);
    _scheduleRest();
  }

  // ---- A visual novel -----------------------------------------------------------------------

  StoryBeat? get _beat => _movie || _step.play.isEmpty ? null : _scene.beats[_step.play[_at.clamp(0, _step.play.length - 1)]];

  /// Tap anywhere: the next beat, or the scene's end.
  void _next() {
    if (_phase != _Phase.playing || _movie) return;
    _autoNext?.cancel();
    if (_at + 1 < _step.play.length) {
      setState(() => _at++);
      unawaited(_speak());
      _keep(force: true);
    } else {
      unawaited(_voice.stop().catchError((Object _) {}));
      unawaited(_arrive());
    }
  }

  /// A voiced beat is heard as it shows; with `Auto` on, the next follows once it has been heard, or
  /// once an unvoiced line has had time to be read.
  Future<void> _speak() async {
    final spoken = ++_spoken;
    final beat = _beat;
    if (beat == null) return;
    if (beat.voice != null) {
      await _voice.play(widget.story.pathOf(beat.voice!)).catchError((Object _) {});
      if (!mounted || spoken != _spoken) return;
      if (_auto) _autoNext = Timer(const Duration(milliseconds: 600), _next);
    } else if (_auto) {
      _autoNext = Timer(Duration(milliseconds: 1500 + 45 * (beat.line?.length ?? 0)), () => spoken == _spoken ? _next() : null);
    }
  }

  void _toggleAuto() {
    setState(() => _auto = !_auto);
    _autoNext?.cancel();
    if (_auto && _phase == _Phase.playing && (_beat?.voice == null)) {
      _autoNext = Timer(const Duration(milliseconds: 1500), _next);
    }
  }

  // ---- Sheets -------------------------------------------------------------------------------

  /// The route sheet (P18e). A movie stops under it: what is chosen there replaces what plays.
  Future<void> _route() async {
    if (_movie && (_reel?.playing ?? false)) {
      unawaited(_reel!.pause());
      _keep(force: true);
    }
    _rest?.cancel();
    setState(() => _routing = true);
    await showRouteSheet(context, story: widget.story, path: storyPath(_document, _step.route), onChooseAgain: _chooseAgain, onStartOver: _startOver);
    if (mounted) setState(() => _routing = false);
  }

  /// P4e's log: what this scene has said so far, the line now marked; a voiced line plays again.
  void _log() {
    final shown = _phase == _Phase.playing ? _step.play.take(_at + 1) : _step.play;
    showPlayerSheet<void>(
      context,
      title: 'Log',
      count: 'Scene ${_step.route.length + 1}',
      builder: (sheet) => ListView(
        shrinkWrap: true,
        children: [
          for (final (i, index) in shown.indexed)
            if (_scene.beats[index] case final beat when beat.line != null)
              _LogRow(
                beat: beat,
                now: i == shown.length - 1,
                onPlay: beat.voice == null ? null : () => _voice.play(widget.story.pathOf(beat.voice!)).catchError((Object _) {}),
              ),
        ],
      ),
    );
  }

  void _more() => showPlayerSheet<void>(
    context,
    title: widget.story.production.title,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const RouteGlyph(),
          title: const Text('Route', style: TextStyle(color: _fg)),
          onTap: () {
            Navigator.of(sheet).pop();
            _route();
          },
        ),
        ListTile(
          leading: const Icon(Icons.replay_rounded, color: _fg),
          title: const Text('Start over', style: TextStyle(color: _fg)),
          onTap: () {
            Navigator.of(sheet).pop();
            _startOver();
          },
        ),
      ],
    ),
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

  /// The choices and `Replay scene` where the layout puts them, scrolling from the first when there
  /// are more than fit (SPEC-063 R-26).
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

  Widget _ending(_Layout layout) => Positioned(
    left: layout.fold ? 150 : 20,
    right: layout.fold ? 150 : 20,
    bottom: (layout.turned ? 16 : 44) + layout.extra,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: layout.size.height - layout.pad.top - 90),
      child: SingleChildScrollView(
        child: StoryEndingCard(
          story: widget.story,
          step: _step,
          onStartAgain: _startOver,
          onBack: _step.route.isEmpty ? null : () => _chooseAgain(_step.route.length - 1),
        ),
      ),
    ),
  );

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
    final chromeShown = !playing || _chrome || !overlays;
    children.add(
      IgnorePointer(
        ignoring: !chromeShown,
        child: AnimatedOpacity(
          opacity: chromeShown ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _top(layout, [RoutePress(onPressed: _route)]),
              if (playing && !_routing)
                Positioned(
                  left: layout.turned ? 40 : 20,
                  right: layout.turned ? 40 : 20,
                  bottom: (layout.turned ? 12 : 40) + layout.extra,
                  child: Column(
                    children: [
                      Scrubber(position: _elapsed, length: sceneLength(_document, _step), onSeek: _seek),
                      const SizedBox(height: 10),
                      PlayPause(playing: reel.playing, onPressed: _toggle, small: layout.turned),
                    ],
                  ),
                ),
              if (_phase == _Phase.choosing) ..._choices(layout, top: layout.fold && across ? videoBottom + 60 : null),
              if (_phase == _Phase.ending) _ending(layout),
            ],
          ),
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: playing && overlays ? () => _chrome ? setState(() => _chrome = false) : _wake() : null,
      child: Stack(fit: StackFit.expand, children: children),
    );
  }

  Widget _novelStage(_Layout layout) {
    final beat = _beat;
    final story = widget.story;
    final size = layout.size;
    final playing = _phase == _Phase.playing;
    final upright = !layout.turned && !layout.fold;
    final tallPicture = beat == null ? null : (beat.tall ?? (story.tallShape ? beat.picture : null));
    // Upright, a beat's Tall picture fills the phone (P18f); without one its picture sits whole at the
    // top, the box under it (P18g). Turned or on a Fold, the picture is whole.
    final fills = upright && tallPicture != null;
    const pictureTop = 160.0;
    final pictureHeight = size.width * 9 / 16;
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
      children
        ..add(const _Scrim(top: true, height: 220))
        ..add(_Scrim(top: false, height: playing ? 400 : 560));
    }
    children
      ..add(_top(layout, [PlayerPress(icon: Icons.more_horiz, label: 'More', onPressed: _more)]))
      ..add(
        Positioned(
          top: layout.turned ? math.max(layout.pad.top, 10) + 52 : layout.pad.top + 57,
          left: layout.turned ? 40 : 14,
          child: Row(
            children: [
              PlayerLabelPress(label: 'Auto', icon: Icons.keyboard_double_arrow_right_rounded, on: _auto, onPressed: _toggleAuto),
              const SizedBox(width: 6),
              PlayerLabelPress(label: 'Log', icon: Icons.format_list_bulleted_rounded, onPressed: _log),
            ],
          ),
        ),
      );
    // A picture held without a line shows no box; at a choice the last line said stays (R-87).
    final said = playing
        ? (beat?.line == null ? null : beat)
        : [for (final index in _step.play) _scene.beats[index]].lastWhere((beat) => beat.line != null, orElse: () => const StoryBeat(picture: ''));
    final box = said?.line == null || _phase == _Phase.ending ? null : _LineBox(beat: said!, more: playing);
    if (upright && !fills) {
      // The box under the picture, the speaker's name over its top edge.
      if (box != null) children.add(Positioned(top: pictureTop + pictureHeight + 31, left: 12, right: 12, child: box));
      if (_phase == _Phase.choosing) children.addAll(_choices(layout));
    } else if (upright) {
      if (_phase == _Phase.choosing) {
        // At a choice the last line stays, the choices under it.
        children.add(
          Positioned(
            left: 16,
            right: 16,
            bottom: 96 + layout.extra,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (box != null) ...[box, const SizedBox(height: 26)],
                StoryChoices(options: _step.options, onChoose: _choose),
              ],
            ),
          ),
        );
        children.add(
          Positioned(
            left: 0,
            right: 0,
            bottom: 36 + layout.extra,
            child: ReplayScene(onPressed: _replay),
          ),
        );
      } else if (box != null) {
        children.add(Positioned(left: 12, right: 12, bottom: 42 + layout.extra, child: box));
      }
    } else {
      // Turned or on a Fold: the box and the choices at the foot, over the picture's.
      children.add(
        Positioned(
          left: 0,
          right: 0,
          bottom: layout.pad.bottom + 12,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?box,
                  if (_phase == _Phase.choosing) ...[
                    const SizedBox(height: 22),
                    StoryChoices(options: _step.options, onChoose: _choose, across: true),
                    const SizedBox(height: 4),
                    ReplayScene(onPressed: _replay),
                  ] else
                    const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (playing && _step.play.length > 1) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          bottom: (upright ? 26 : 14) + layout.extra,
          child: _BeatDashes(count: _step.play.length, done: _at + 1),
        ),
      );
    }
    if (_phase == _Phase.ending) children.add(_ending(layout));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: playing ? _next : null,
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

/// The scrims the chrome sits on (Studio 156): from the top, 74% fading out; from the foot, 90% to
/// 12% of its height, fading out.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.top, required this.height});
  final bool top;
  final double height;

  @override
  Widget build(BuildContext context) => Positioned(
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

/// P4d's box: glass, the speaker's name in a pill over its top edge, the line, and a chevron while
/// there is more to read.
class _LineBox extends StatelessWidget {
  const _LineBox({required this.beat, required this.more});
  final StoryBeat beat;
  final bool more;

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
                  style: TextStyle(
                    fontFamily: ArkeType.family,
                    fontSize: ArkeType.sizeLg,
                    height: 1.5,
                    letterSpacing: -0.18,
                    color: _fg,
                    fontStyle: beat.speaker == null ? FontStyle.italic : FontStyle.normal,
                  ),
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
        if (more) Positioned(right: 16, bottom: 10, child: Icon(Icons.chevron_right_rounded, size: 18, color: _fg.withValues(alpha: 0.7))),
      ],
    );
  }
}

/// How far through the scene's beats: a dash a beat, those read in full ink.
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
