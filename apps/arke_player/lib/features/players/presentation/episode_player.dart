import 'dart:async';
import 'dart:io';
import 'dart:math' show max;
import 'dart:ui' show ImageFilter;

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/device_settings.dart';
import '../../worlds/application/discover.dart';
import '../../worlds/application/guides.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/guide_widgets.dart';
import '../../worlds/presentation/media_rail.dart';
import '../../worlds/presentation/production_screen.dart';
import '../../worlds/presentation/row_widgets.dart';
import '../../worlds/presentation/someone_new.dart';
import '../../worlds/presentation/world_shelf.dart';
import '../../worlds/presentation/world_widgets.dart';
import '../application/audio_engine.dart';
import '../application/listening_plan.dart';
import 'chrome.dart';
import 'episode_rows.dart';
import 'picture_of_the_moment.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// How long the controls stay once it is playing (P24 rule 5).
const _controlsRest = Duration(milliseconds: 2500);

/// The upright player (P24c – P24j, P14 before it). It plays like a video: the Tall picture fills the
/// phone, the next episode comes on its own, and a swipe moves on. A tap pauses and brings the controls
/// (P19 rule 2: a tap never moves on). Until a title has the Studio's cuts its chapters are its episodes,
/// so this plays them whole, and a chapter opened whole is the same thing (P24 rule 1).
class EpisodePlayer extends ConsumerStatefulWidget {
  const EpisodePlayer({required this.item, required this.plan, required this.engine, required this.onSpeedAndSleep, super.key});

  final LibraryItem item;
  final ListeningPlan plan;
  final AudioEngine engine;
  final VoidCallback onSpeedAndSleep;

  @override
  ConsumerState<EpisodePlayer> createState() => _EpisodePlayerState();
}

class _EpisodePlayerState extends ConsumerState<EpisodePlayer> {
  AudioEngine get _engine => widget.engine;
  List<ListeningChapter> get _chapters => widget.plan.chapters;

  late final PageController _pages = PageController(initialPage: _engine.chapterAt(_engine.now));

  /// The page showing: a chapter, or past the last of them Caught up.
  late int _page = _pages.initialPage;

  /// The chapter last heard, to tell when it moved on.
  late int _chapter = _pages.initialPage;

  /// The chapter a press or a swipe asked for: its coming is not the player moving on by itself.
  int? _asked;

  /// The pages are being moved to follow the sound, not the other way about.
  bool _following = false;
  bool _controls = false;

  /// A sheet is up: only the picture stays behind it (P24e, P24f).
  bool _sheet = false;
  Timer? _rest;
  StreamSubscription<Duration>? _positions;

  /// What the reader had when this opened (P24 rule 7). Asked only once: it works over the whole
  /// listening document, and a place is saved every few seconds. The chapter playing adds to it.
  GuideReach? _before;

  bool get _caughtUp => _page >= _chapters.length;

  @override
  void initState() {
    super.initState();
    _positions = _engine.position.listen(_follow);
  }

  @override
  void dispose() {
    _positions?.cancel();
    _rest?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _follow(Duration position) {
    final length = _engine.length;
    final index = _engine.chapterAt(position);
    if (index != _chapter) {
      final byItself = _asked != index && index == _chapter + 1;
      _chapter = index;
      _asked = null;
      final settings = ref.read(settingsProvider).value ?? const DeviceSettings();
      if (byItself && !settings.autoplayNext) _engine.pause();
      if (_page != index) _moveTo(index);
    } else if (length > Duration.zero && position >= length - const Duration(milliseconds: 300) && !_caughtUp) {
      _moveTo(_chapters.length);
    }
  }

  void _moveTo(int page) {
    if (!_pages.hasClients) return;
    _following = true;
    _pages.animateToPage(page, duration: const Duration(milliseconds: 320), curve: Curves.easeOut).whenComplete(() => _following = false);
  }

  void _onPage(int page) {
    setState(() => _page = page);
    if (_following) return;
    if (page >= _chapters.length) {
      _engine.pause();
    } else {
      _seekTo(page);
    }
  }

  void _seekTo(int index) {
    _asked = index;
    _engine.seek(widget.plan.starts[index]);
    _engine.play();
  }

  void _restSoon() {
    _rest?.cancel();
    _rest = Timer(_controlsRest, () {
      if (mounted && _engine.playing) setState(() => _controls = false);
    });
  }

  void _tap() {
    if (_caughtUp) return;
    if (!_controls) {
      _engine.pause();
      _rest?.cancel();
      setState(() => _controls = true);
    } else if (_engine.playing) {
      _rest?.cancel();
      setState(() => _controls = false);
    } else {
      _engine.play();
      _restSoon();
    }
  }

  void _playPause() {
    if (_engine.playing) {
      _engine.pause();
      _rest?.cancel();
    } else {
      _engine.play();
      _restSoon();
    }
  }

  String? get _productionId {
    final world = ref.watch(libraryWorldsProvider).value?.where((world) => world.id == widget.item.worldId).firstOrNull;
    return world?.productions.where((production) => production.narration == widget.item.id).firstOrNull?.id;
  }

  /// Who the chapter has reached (P24 rule 7): nobody still waiting. It will say who is in this moment
  /// once the listening document carries the Studio's scene cast.
  List<GuideCharacter> _here(Guide? guide, int chapter) {
    if (guide == null) return const [];
    final production = _productionId;
    final number =
        guide.productions
            .where((known) => known.id == production)
            .firstOrNull
            ?.chapters
            .where((known) => known.id == _chapters[chapter].id)
            .firstOrNull
            ?.number ??
        _chapters[chapter].order;
    return [
      for (final character in guide.characters)
        if (character.after == null ||
            (_before?.shows(character.after) ?? false) ||
            (character.after!.production == production && character.after!.number <= number))
          character,
    ];
  }

  void _openEntry(GuideEntry entry) => context.go(Routes.guideEntry(Routes.worldsWorld(widget.item.worldId!), entry.id));

  void _openWorld() => context.go(Routes.worldsWorld(widget.item.worldId!));

  Future<void> _overPicture(Future<void> Function() sheet) async {
    setState(() => _sheet = true);
    await sheet();
    if (mounted) setState(() => _sheet = false);
  }

  Future<void> _showHere(WorldGuide? guide, int chapter) {
    final here = _here(guide?.guide, chapter);
    return _overPicture(
      () => showPlayerSheet<void>(
        context,
        title: 'Here',
        count: '${here.length}',
        builder: (context) => _HereList(
          here: here,
          guide: guide,
          worldName: ref.read(worldNameProvider(widget.item.worldId!)) ?? widget.item.title,
          onEntry: _openEntry,
          onWorld: _openWorld,
        ),
      ),
    );
  }

  Future<void> _showEpisodes() => _overPicture(
    () => showPlayerSheet<void>(
      context,
      title: 'Episodes',
      count: '${_chapters.length}',
      builder: (sheet) => EpisodeRows(
        plan: widget.plan,
        position: _engine.now,
        onOpen: (index) {
          _seekTo(index);
          Navigator.of(sheet).pop();
        },
      ),
    ),
  );

  Future<void> _showMore() => showPlayerSheet<void>(
    context,
    title: widget.item.title,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
        return SwitchListTile(
          title: const Text('Slow push', style: TextStyle(color: _fg)),
          value: settings.slowPush,
          onChanged: (on) => ref.read(settingsProvider.notifier).change((current) => current.copyWith(slowPush: on)),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final worldId = widget.item.worldId;
    final guide = worldId == null ? null : ref.watch(worldGuideProvider(worldId)).value;
    if (_before == null && worldId != null && guide != null) _before = ref.watch(guideReachProvider(worldId)).value;
    final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
    final notify = worldId != null && settings.notify.contains(worldId);
    // A phone upright and an upright tablet take Tall (call 53). A phone turned fills with Wide; a Fold
    // open or a tablet sideways puts Wide beside its panel.
    final turned = size.height < WindowBands.fold;
    final side = !turned && size.width >= WindowBands.fold && size.width / size.height >= 0.8;
    final upright = !turned && !side;
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<Duration>(
        stream: _engine.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? _engine.now;
          final chapter = _engine.chapterAt(position);
          final (start, end) = _engine.chapterBounds(position);
          final length = end - start;
          final title = '${chapter + 1} · ${widget.item.chapters[chapter].title}';
          final words = settings.text ? widget.plan.phraseAt(position)?.text : null;

          final rail = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!side) ...[
                RailPress(icon: Icons.groups_rounded, label: 'Here', onPressed: () => _showHere(guide, chapter)),
                const SizedBox(height: 12),
                RailPress(icon: Icons.format_list_bulleted_rounded, label: 'Episodes', onPressed: _showEpisodes),
                const SizedBox(height: 12),
              ],
              if (worldId != null && !side)
                RailPress(
                  icon: notify ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                  label: 'Notify',
                  on: notify,
                  toggles: true,
                  onPressed: () => setNotify(ref, worldId, !notify),
                ),
            ],
          );

          final stage = LayoutBuilder(
            builder: (context, box) {
              final media = MediaQuery.of(context);
              final foot = media.padding.bottom + 4;
              // Beside its panel the picture stands above its words (P24j).
              final pictureHeight = side ? (box.maxWidth * 2 / 3).clamp(0.0, box.maxHeight * 0.6) : 0.0;
              final pictureTop = side ? max(media.padding.top + 56, (box.maxHeight - pictureHeight - 220) / 2) : 0.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: _tap,
                    behavior: HitTestBehavior.opaque,
                    child: PageView.builder(
                      controller: _pages,
                      scrollDirection: Axis.vertical,
                      itemCount: _chapters.length + 1,
                      onPageChanged: _onPage,
                      itemBuilder: (context, index) {
                        if (index == _chapters.length) {
                          return _CaughtUp(item: widget.item, plan: widget.plan, onClose: () => context.pop(), onEntry: _openEntry);
                        }
                        final current = index == chapter;
                        final at = current ? position : widget.plan.starts[index];
                        return _EpisodePicture(
                          shown: widget.plan.shownAt(at),
                          position: at,
                          playingStream: _engine.playingStream,
                          playing: _engine.playing && current,
                          current: current,
                          speed: _engine.speed,
                          push: settings.slowPushIn(reducedMotion: media.disableAnimations),
                          tall: upright,
                          // Letterboxed as P14 shows a moment with no Tall; beside a panel, above its words.
                          top: side ? pictureTop : 0,
                          height: side
                              ? pictureHeight
                              : upright
                              ? box.maxHeight * 0.62
                              : box.maxHeight,
                        );
                      },
                    ),
                  ),
                  if (!_caughtUp && !_sheet) ...[
                    if (!side) ...[
                      const IgnorePointer(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: 110,
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xBD0A0A0A), Color(0x000A0A0A)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: words == null ? 300 : 380,
                            width: double.infinity,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Color(0xE60A0A0A), Color(0xE60A0A0A), Color(0x000A0A0A)],
                                  stops: [0, 0.12, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_controls) const IgnorePointer(child: ColoredBox(color: Color(0x570A0A0A))),
                    if (!_controls)
                      Positioned(
                        left: side ? 28 : 16,
                        right: side ? 28 : 84,
                        top: side ? pictureTop + pictureHeight + 32 : null,
                        bottom: side ? null : foot + 28,
                        child: _Foot(words: words, title: title, name: widget.item.title, large: side, onName: worldId == null ? null : _openWorld),
                      ),
                    if (!side) Positioned(right: 8, bottom: _controls ? foot + 116 : foot + 24, child: rail),
                    if (!_controls && !side)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: foot + 8,
                        child: ThinLine(value: length.inMilliseconds == 0 ? 0 : (position - start).inMilliseconds / length.inMilliseconds),
                      ),
                    if (!_controls && side)
                      Positioned(
                        left: 28,
                        right: 28,
                        top: pictureTop + pictureHeight + 148,
                        child: ThinLine(value: length.inMilliseconds == 0 ? 0 : (position - start).inMilliseconds / length.inMilliseconds),
                      ),
                    if (_controls) ...[
                      Positioned(
                        left: 4,
                        right: 4,
                        top: media.padding.top + 4,
                        child: _TopRow(name: widget.item.title, title: title, onClose: () => context.pop(), onMore: _showMore),
                      ),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Seek15(forward: false, onPressed: () => _engine.rewind()),
                            const SizedBox(width: 34),
                            StreamBuilder<bool>(
                              stream: _engine.playingStream,
                              initialData: _engine.playing,
                              builder: (context, playing) => PlayPause(playing: playing.data ?? false, onPressed: _playPause),
                            ),
                            const SizedBox(width: 34),
                            _Seek15(forward: true, onPressed: () => _engine.forward15()),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: foot + 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Scrubber(position: position - start, length: length, onSeek: (offset) => _engine.seek(start + offset)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PlayerLabelPress(label: '${_speedLabel(_engine.speed)}×', onPressed: widget.onSpeedAndSleep),
                                const SizedBox(width: 12),
                                PlayerLabelPress(
                                  label: _engine.sleep == SleepTimer.off ? 'Sleep' : _engine.sleep.label,
                                  icon: Icons.bedtime_outlined,
                                  on: _engine.sleep != SleepTimer.off,
                                  onPressed: widget.onSpeedAndSleep,
                                ),
                                const SizedBox(width: 12),
                                PlayerLabelPress(
                                  label: 'Text',
                                  icon: Icons.subject,
                                  on: settings.text,
                                  onPressed: () => ref.read(settingsProvider.notifier).change((current) => current.copyWith(text: !current.text)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  SomeoneNew(item: widget.item, chapter: _chapters.elementAtOrNull(chapter)),
                ],
              );
            },
          );
          if (!side) return stage;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: stage),
              SizedBox(
                width: size.width >= WindowBands.wide ? 380 : 320,
                child: _SidePanel(
                  here: _here(guide?.guide, chapter),
                  guide: guide,
                  plan: widget.plan,
                  position: position,
                  worldId: worldId,
                  notify: notify,
                  worldName: worldId == null ? null : ref.watch(worldNameProvider(worldId)),
                  onEntry: _openEntry,
                  onWorld: _openWorld,
                  onEpisode: _seekTo,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _speedLabel(double speed) => speed == speed.roundToDouble() ? speed.toStringAsFixed(1) : '$speed';

/// A chapter's picture of the moment. A moment with a Tall one fills an upright page, as P14 shows it;
/// one with only its Wide shows it whole over its own blur. A neighbour coming up in a swipe holds its
/// first picture (P24g).
class _EpisodePicture extends StatelessWidget {
  const _EpisodePicture({
    required this.shown,
    required this.position,
    required this.playingStream,
    required this.playing,
    required this.current,
    required this.speed,
    required this.push,
    required this.tall,
    required this.top,
    required this.height,
  });

  final ShownPicture? shown;
  final Duration position;
  final Stream<bool> playingStream;
  final bool playing;
  final bool current;
  final double speed;
  final bool push;
  final bool tall;
  final double top;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shown = this.shown;
    final fills = tall && shown?.tallPath != null;
    final picture = StreamBuilder<bool>(
      stream: playingStream,
      initialData: playing,
      builder: (context, state) => PictureOfTheMoment(
        shown: fills ? shown!.tall : shown,
        position: position,
        playing: current && (state.data ?? false),
        speed: speed,
        push: push,
        fill: fills,
      ),
    );
    if (fills || shown == null) return picture;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(seconds: 1),
          child: BlurOf(key: ValueKey(shown.path), picture: FileImage(File(shown.path))),
        ),
        Positioned(left: 0, right: 0, top: top, height: height, child: picture),
      ],
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.words, required this.title, required this.name, required this.large, required this.onName});

  final String? words;
  final String title;
  final String name;
  final bool large;
  final VoidCallback? onName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (words != null) ...[
          Text(
            words!,
            maxLines: large ? 4 : 3,
            overflow: TextOverflow.ellipsis,
            style: (large ? text.headlineSmall : text.titleLarge)?.copyWith(
              color: _fg,
              fontWeight: FontWeight.w600,
              height: 1.35,
              shadows: const [Shadow(color: Color(0x800A0A0A), blurRadius: 10)],
            ),
          ),
          SizedBox(height: large ? 18 : 14),
        ],
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(color: _fg),
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: onName,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.82)),
                ),
              ),
              if (onName != null) Icon(Icons.chevron_right_rounded, size: 16, color: _fg.withValues(alpha: 0.82)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.name, required this.title, required this.onClose, required this.onMore});

  final String name;
  final String title;
  final VoidCallback onClose;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          onPressed: onClose,
          tooltip: 'Close',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _fg, size: 28),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: _fg.withValues(alpha: 0.7)),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(color: _fg),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onMore,
          tooltip: 'More',
          icon: const Icon(Icons.more_horiz, color: _fg),
        ),
      ],
    );
  }
}

/// Back or forward 15: the replay arrow, turned round for forward, with its number in it.
class _Seek15 extends StatelessWidget {
  const _Seek15({required this.forward, required this.onPressed});

  final bool forward;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: forward ? 'Forward 15 seconds' : 'Back 15 seconds',
    child: ExcludeSemantics(
      child: InkResponse(
        onTap: onPressed,
        radius: 32,
        child: SizedBox.square(
          dimension: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.flip(
                flipX: forward,
                child: const Icon(Icons.replay_rounded, color: _fg, size: 40),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '15',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _fg, fontWeight: FontWeight.w600, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One of Here's rows (P24e): a face, a name and a role, opening their entry while the episode plays on.
class _HereRow extends StatelessWidget {
  const _HereRow({required this.character, required this.guide, required this.onOpen});

  final GuideCharacter character;
  final WorldGuide? guide;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final picture = guide == null ? null : guidePicture(guide!, character);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ArkeRadius.md),
              child: SizedBox(
                width: 44,
                height: 56,
                child: picture == null
                    ? ColoredBox(
                        color: ArkeColors.neutral800,
                        child: Center(
                          child: Text(initials(character.name), style: text.labelMedium?.copyWith(color: _fg)),
                        ),
                      )
                    : Image(
                        image: picture,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.6),
                        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: _fg),
                  ),
                  if (character.role case final role?) ...[
                    const SizedBox(height: 2),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(color: _fg.withValues(alpha: 0.68)),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: _fg.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _HereList extends StatelessWidget {
  const _HereList({required this.here, required this.guide, required this.worldName, required this.onEntry, required this.onWorld});

  final List<GuideCharacter> here;
  final WorldGuide? guide;
  final String worldName;
  final ValueChanged<GuideEntry> onEntry;
  final VoidCallback onWorld;

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    children: [
      for (final character in here) _HereRow(character: character, guide: guide, onOpen: () => onEntry(character)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: OutlinedButton.icon(
          onPressed: onWorld,
          icon: const Icon(Icons.public, size: 18, color: _fg),
          label: Text(worldName, style: const TextStyle(color: _fg)),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
        ),
      ),
    ],
  );
}

/// `Here · Episodes` beside the picture (P24j, P27): the same two lists as the sheets, with the bell.
class _SidePanel extends ConsumerStatefulWidget {
  const _SidePanel({
    required this.here,
    required this.guide,
    required this.plan,
    required this.position,
    required this.worldId,
    required this.notify,
    required this.worldName,
    required this.onEntry,
    required this.onWorld,
    required this.onEpisode,
  });

  final List<GuideCharacter> here;
  final WorldGuide? guide;
  final ListeningPlan plan;
  final Duration position;
  final String? worldId;
  final bool notify;
  final String? worldName;
  final ValueChanged<GuideEntry> onEntry;
  final VoidCallback onWorld;
  final ValueChanged<int> onEpisode;

  @override
  ConsumerState<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends ConsumerState<_SidePanel> {
  bool _episodes = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget tab(String label, String count, bool on, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: on ? _fg : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: text.bodyMedium?.copyWith(
                fontSize: ArkeType.sizeBase,
                color: _fg.withValues(alpha: on ? 1 : 0.68),
                fontWeight: on ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Text(count, style: text.labelSmall?.copyWith(color: _fg.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          decoration: BoxDecoration(
            color: _bg.withValues(alpha: 0.62),
            border: Border(left: BorderSide(color: _fg.withValues(alpha: 0.12))),
          ),
          child: SafeArea(
            left: false,
            child: Theme(
              data: ThemeData.dark(useMaterial3: true).copyWith(
                textTheme: Theme.of(context).textTheme.apply(bodyColor: _fg, displayColor: _fg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _fg.withValues(alpha: 0.14))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                tab('Here', '${widget.here.length}', !_episodes, () => setState(() => _episodes = false)),
                                tab('Episodes', '${widget.plan.chapters.length}', _episodes, () => setState(() => _episodes = true)),
                              ],
                            ),
                          ),
                        ),
                        if (widget.worldId case final worldId?)
                          IconButton(
                            onPressed: () => setNotify(ref, worldId, !widget.notify),
                            tooltip: 'Notify',
                            icon: Icon(widget.notify ? Icons.notifications_rounded : Icons.notifications_none_rounded, color: _fg, size: 20),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _episodes
                        ? EpisodeRows(plan: widget.plan, position: widget.position, onOpen: widget.onEpisode)
                        : ListView(
                            padding: const EdgeInsets.only(top: 8),
                            children: [
                              for (final character in widget.here) _HereRow(character: character, guide: widget.guide, onOpen: () => widget.onEntry(character)),
                              if (widget.worldName case final name?)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: OutlinedButton.icon(
                                    onPressed: widget.onWorld,
                                    icon: const Icon(Icons.public, size: 18, color: _fg),
                                    label: Text(name, style: const TextStyle(color: _fg)),
                                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// After the last released episode (P24h): `Caught up`, the next date from the title's schedule (P15e),
/// Notify, and `In this world`, the moment to send someone into the world.
class _CaughtUp extends ConsumerWidget {
  const _CaughtUp({required this.item, required this.plan, required this.onClose, required this.onEntry});

  final LibraryItem item;
  final ListeningPlan plan;
  final VoidCallback onClose;
  final ValueChanged<GuideEntry> onEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final worldId = item.worldId;
    final world = ref.watch(libraryWorldsProvider).value?.where((world) => world.id == worldId).firstOrNull;
    final production = world?.productions.where((production) => production.narration == item.id).firstOrNull;
    final listed = worldId == null ? null : listedFor(ref.watch(catalogueProvider).value ?? const [], worldId);
    final inList = listed?.productions.where((candidate) => candidate.id == production?.id).firstOrNull;
    final next = upcoming(inList?.schedule, ref.watch(clockProvider)());
    final tall = ref.tallOf(inList);
    final fallback = plan.document.cover == null ? null : FileImage(File(plan.pathOf(plan.document.cover!)));
    final cover = tall ?? fallback ?? libraryPicture(ref.watch(libraryStoreProvider).value, world?.keyArt);
    final guide = worldId == null ? null : ref.watch(worldGuideProvider(worldId)).value;
    final reach = worldId == null ? GuideReach.none : (ref.watch(guideReachProvider(worldId)).value ?? GuideReach.none);
    final notify = worldId != null && (ref.watch(settingsProvider).value ?? const DeviceSettings()).notify.contains(worldId);
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover != null) BlurOf(picture: cover),
        ListView(
          padding: EdgeInsets.only(top: top + 96, bottom: MediaQuery.paddingOf(context).bottom + 24),
          children: [
            if (cover != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 132,
                    height: 198,
                    child: Image(image: cover, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const SizedBox.shrink()),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'Caught up',
              textAlign: TextAlign.center,
              style: text.headlineLarge?.copyWith(color: _fg),
            ),
            if (next != null) ...[
              const SizedBox(height: 8),
              Text(
                'Episode ${plan.chapters.length + 1} · ${shortDate(next)}',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: _fg.withValues(alpha: 0.8), fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
            if (worldId != null) ...[
              const SizedBox(height: 18),
              Center(
                child: FilledButton.icon(
                  onPressed: () => setNotify(ref, worldId, !notify),
                  icon: Icon(notify ? Icons.notifications_rounded : Icons.notifications_none_rounded, size: 18),
                  label: Text(notify ? 'Notify on' : 'Notify'),
                  style: FilledButton.styleFrom(minimumSize: const Size(180, ArkeSizes.press), backgroundColor: _fg, foregroundColor: _bg),
                ),
              ),
            ],
            if (guide != null) ...[
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('In this world', style: text.titleMedium?.copyWith(color: _fg)),
              ),
              const SizedBox(height: 10),
              TileRow(
                children: [
                  for (final entry in [...guide.guide.characters, ...guide.guide.places])
                    if (reach.shows(entry.after))
                      PosterTile(
                        title: entryName(entry),
                        kind: entry is GuideCharacter ? (entry.role ?? 'Character') : placeKind(entry as GuidePlace),
                        tall: entry is GuideCharacter ? guidePicture(guide, entry) : null,
                        wide: entry is GuideCharacter ? null : guidePicture(guide, entry),
                        initials: initials(entryName(entry)),
                        pictureAlignment: const Alignment(0, -0.6),
                        width: RowSizes.small(context),
                        onMedia: true,
                        onOpen: () => onEntry(entry),
                      ),
                ],
              ),
            ],
          ],
        ),
        Positioned(
          left: 4,
          top: top + 4,
          child: IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _fg, size: 28),
          ),
        ),
      ],
    );
  }
}
