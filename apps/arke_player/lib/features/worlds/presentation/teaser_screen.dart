import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' show ImageFilter;

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/device_settings.dart';
import '../application/discover.dart';
import '../application/teaser_feed.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';
import 'media_rail.dart';
import 'row_widgets.dart';
import 'world_shelf.dart';
import 'world_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// Opens the feed at a page. Leaving by a world's name or World opens that world's page, in the tab the
/// feed was opened from, and by Play that world's title.
Future<void> openFeed(BuildContext context, List<FeedPage> pages, int start) async {
  final next = await Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (_) => TeaserFeedScreen(pages: pages, start: start),
    ),
  );
  if (next != null && context.mounted) await context.push(next);
}

/// The feed (P23a – P23d): a teaser fills the phone, and a swipe up moves to the next, across every
/// world. Its sound plays once it is open and never in a row (SPEC-058 R-78), and stays off once it is
/// pressed off. A teaser shows without asking on an 18+ world, whose author chooses ones that suit
/// anyone; only its Start asks.
class TeaserFeedScreen extends ConsumerStatefulWidget {
  const TeaserFeedScreen({required this.pages, required this.start, super.key});

  final List<FeedPage> pages;
  final int start;

  @override
  ConsumerState<TeaserFeedScreen> createState() => _TeaserFeedScreenState();
}

class _TeaserFeedScreenState extends ConsumerState<TeaserFeedScreen> {
  late final TeaserAudio _audio = ref.read(teaserAudioProvider);
  late final PageController _controller = PageController(initialPage: widget.start);
  late int _index = widget.start;
  bool _sound = true;

  /// Only the latest page plays: a swipe past several starts none of those between.
  int _turn = 0;

  @override
  void initState() {
    super.initState();
    _start(_turn);
  }

  void _start(int turn) {
    if (!_sound || turn != _turn) return;
    final page = widget.pages[_index];
    final audio = _Teaser.of(page).audio;
    if (audio != null) _audio.play(page.guide.pathOf(audio)).catchError((Object _) {});
  }

  Future<void> _restart() async {
    final turn = ++_turn;
    await _audio.stop().catchError((Object _) {});
    _start(turn);
  }

  @override
  void dispose() {
    _audio.stop().catchError((Object _) {});
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          itemCount: widget.pages.length,
          onPageChanged: (index) {
            setState(() => _index = index);
            _restart();
          },
          itemBuilder: (context, index) => _FeedPageView(
            page: widget.pages[index],
            current: index == _index,
            sound: _sound,
            position: _audio.position,
            onSound: () {
              setState(() => _sound = !_sound);
              _restart();
            },
            onWorld: () => Navigator.of(context).pop(widget.pages[index].worldPage),
          ),
        ),
        Positioned(
          left: 12,
          top: MediaQuery.paddingOf(context).top + 8,
          child: GlassPress(icon: Icons.close_rounded, label: 'Close', onPressed: () => Navigator.of(context).pop()),
        ),
      ],
    ),
  );
}

/// What a page of the feed shows and sounds (P23 rule 2).
class _Teaser {
  const _Teaser({
    required this.kind,
    required this.title,
    this.line,
    this.quote,
    this.picture,
    this.upright = Alignment.center,
    this.soundLabel,
    this.audio,
    this.length,
  });

  factory _Teaser.of(FeedPage page) {
    ImageProvider assetPicture(String asset) => FileImage(File(page.guide.pathOf(asset)));
    return switch (page.teaser) {
      EntryTeaser(entry: final GuideCharacter character) => _Teaser(
        kind: 'Character',
        title: character.name,
        line: character.role,
        quote: character.voice == null ? null : '“${character.voice!.text}”',
        picture: guidePicture(page.guide, character),
        upright: const Alignment(0, -0.68),
        soundLabel: character.voice == null ? null : 'Voice',
        audio: character.voice?.audio,
        length: character.voice?.duration,
      ),
      EntryTeaser(:final entry) => _Teaser(
        kind: entry is GuidePlace ? placeKind(entry) : 'Lore',
        title: entryName(entry),
        picture: guidePicture(page.guide, entry),
      ),
      SongTeaser(:final title, :final picture, :final audio, :final duration) => _Teaser(
        kind: 'Song · ${formatClock(duration)}',
        title: title,
        picture: assetPicture(picture),
        soundLabel: 'Sound',
        audio: audio,
        length: duration,
      ),
      ClipTeaser(:final title, :final picture, :final from, :final audio, :final duration) => _Teaser(
        kind: 'Clip · ${formatClock(duration)}',
        title: title,
        line: 'Chapter ${from.number}',
        picture: assetPicture(picture),
        soundLabel: 'Sound',
        audio: audio,
        length: duration,
      ),
      PictureTeaser(:final title, :final picture, :final from) => _Teaser(
        kind: 'Picture',
        title: title,
        line: 'Chapter ${from.number}',
        picture: assetPicture(picture),
      ),
    };
  }

  final String kind;
  final String title;
  final String? line;
  final String? quote;
  final ImageProvider? picture;
  final Alignment upright;
  final String? soundLabel;
  final String? audio;
  final Duration? length;
}

class _FeedPageView extends ConsumerStatefulWidget {
  const _FeedPageView({required this.page, required this.current, required this.sound, required this.position, required this.onSound, required this.onWorld});

  final FeedPage page;
  final bool current;
  final bool sound;
  final Stream<Duration> position;
  final VoidCallback onSound;
  final VoidCallback onWorld;

  @override
  ConsumerState<_FeedPageView> createState() => _FeedPageViewState();
}

class _FeedPageViewState extends ConsumerState<_FeedPageView> {
  /// Its picture is Wide or square: a teaser does not say, so the picture is asked.
  bool _across = false;

  FeedPage get page => widget.page;

  @override
  Widget build(BuildContext context) {
    final teaser = _Teaser.of(page);
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final foot = media.padding.bottom + 12;
    final notify = (ref.watch(settingsProvider).value ?? const DeviceSettings()).notify.contains(page.worldId);
    final size = media.size;
    // A tablet sideways: a Wide picture fills the screen, a portrait stays upright over its blur. A Fold,
    // nearly square, keeps the upright shape too; a tablet held upright is as tall as a phone (P23d, P27).
    final sideways = size.width >= WindowBands.wide && size.height >= WindowBands.fold;
    final bleeds = sideways && _across;
    final boxed = (sideways && !_across) || (!sideways && size.width >= WindowBands.fold && size.width / size.height >= 0.8);
    final width = sideways ? size.height * 0.5625 : min(size.width, size.height * 0.695);
    final body = Stack(
      fit: StackFit.expand,
      children: [
        if (teaser.picture != null)
          _FeedPicture(
            picture: teaser.picture!,
            upright: teaser.upright,
            covers: bleeds,
            onAcross: (across) {
              if (across != _across && mounted) setState(() => _across = across);
            },
          )
        else
          const ColoredBox(color: ArkeColors.neutral800),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 150,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x990A0A0A), Color(0x000A0A0A)]),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: teaser.quote != null || teaser.line != null ? 520 : 400,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xF00A0A0A), Color(0xB80A0A0A), Color(0x000A0A0A)],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: bleeds ? 40 : 16,
          right: bleeds ? 160 : 84,
          bottom: foot + 98,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(teaser.kind, style: text.labelMedium?.copyWith(color: _fg.withValues(alpha: 0.82))),
              const SizedBox(height: 3),
              Text(teaser.title, style: text.headlineLarge?.copyWith(color: _fg)),
              if (teaser.line != null) ...[const SizedBox(height: 3), Text(teaser.line!, style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.82)))],
              if (teaser.quote != null) ...[
                const SizedBox(height: 10),
                Text(
                  teaser.quote!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(color: _fg, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: bleeds ? 32 : 8,
          bottom: bleeds ? foot + 16 : foot + 94,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (teaser.soundLabel case final label?) ...[
                RailPress(
                  icon: widget.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  label: label,
                  on: widget.sound,
                  toggles: true,
                  onPressed: widget.onSound,
                ),
                const SizedBox(height: 12),
              ],
              RailPress(
                icon: notify ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                label: 'Notify',
                on: notify,
                toggles: true,
                onPressed: () => setNotify(ref, page.worldId, !notify),
              ),
              const SizedBox(height: 12),
              RailPress(icon: Icons.public, label: 'World', onPressed: widget.onWorld),
            ],
          ),
        ),
        if (teaser.length case final length? when widget.current && widget.sound)
          Positioned(
            left: bleeds ? 40 : 16,
            right: bleeds ? 120 : 16,
            bottom: foot + 80,
            child: StreamBuilder<Duration>(
              stream: widget.position,
              builder: (context, snapshot) =>
                  ThinLine(value: length.inMilliseconds == 0 ? 0 : (snapshot.data ?? Duration.zero).inMilliseconds / length.inMilliseconds),
            ),
          ),
        Positioned(
          left: bleeds ? 40 : 12,
          right: bleeds ? null : 12,
          width: bleeds ? 420 : null,
          bottom: foot,
          child: _WorldStrip(page: page, onWorld: widget.onWorld),
        ),
      ],
    );
    if (!boxed) return body;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (teaser.picture != null) BlurOf(picture: teaser.picture!),
        Center(
          child: SizedBox(
            width: width,
            child: ClipRect(child: body),
          ),
        ),
      ],
    );
  }
}

/// A Tall picture or portrait fills its page; a Wide or square one shows whole over its own blur
/// (P23b, P23c). A teaser does not say which it has, so the picture is asked.
class _FeedPicture extends StatefulWidget {
  const _FeedPicture({required this.picture, required this.upright, required this.covers, required this.onAcross});

  final ImageProvider picture;
  final Alignment upright;

  /// A Wide picture fills a tablet sideways rather than showing whole.
  final bool covers;
  final ValueChanged<bool> onAcross;

  @override
  State<_FeedPicture> createState() => _FeedPictureState();
}

class _FeedPictureState extends State<_FeedPicture> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() => _across = info.image.width >= info.image.height);
    // Told after the frame: a picture already decoded answers while its parent is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAcross(_across);
    });
  }, onError: (error, stack) {});
  bool _across = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = widget.picture.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _across && !widget.covers
      ? Padding(
          padding: const EdgeInsets.only(bottom: 200),
          child: WholeOverBlur(picture: widget.picture),
        )
      : Image(
          image: widget.picture,
          fit: BoxFit.cover,
          alignment: widget.upright,
          errorBuilder: (context, error, stack) => const ColoredBox(color: ArkeColors.neutral800),
        );
}

/// The world, at a teaser's foot (P23 rule 3): its name, genre and age, and the same press as Home's.
/// Its name opens its page.
class _WorldStrip extends ConsumerWidget {
  const _WorldStrip({required this.page, required this.onWorld});

  final FeedPage page;
  final VoidCallback onWorld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = page.world;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(installProvider(world.id));
    final held = ref.watch(installedWorldProvider(page.worldId));
    final art = ref.keyArtOf(world) ?? libraryPicture(ref.watch(libraryStoreProvider).value, held?.keyArt);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 68,
          padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
          color: _bg.withValues(alpha: 0.56),
          alignment: Alignment.center,
          child: state is Installing
              ? InstallProgress(state: state, top: 0, onCancel: () => ref.read(installProvider(world.id).notifier).cancel())
              : Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: world.name,
                        child: ExcludeSemantics(
                          child: GestureDetector(
                            onTap: onWorld,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: SizedBox.square(
                                    dimension: 48,
                                    child: art == null
                                        ? const ColoredBox(color: ArkeColors.neutral800)
                                        : Image(image: art, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const SizedBox.shrink()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        world.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: _fg, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (world.genres.isNotEmpty)
                                            Flexible(
                                              child: Text(
                                                world.genres.first,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: text.labelSmall?.copyWith(color: _fg.withValues(alpha: 0.76)),
                                              ),
                                            ),
                                          if (world.age case final age?) ...[const SizedBox(width: 6), AgeTag(age, color: _fg)],
                                        ],
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
                    const SizedBox(width: 10),
                    WorldPress(worldId: page.worldId, top: 0, bell: false, hug: true, onGo: (route) => Navigator.of(context).pop(route)),
                  ],
                ),
        ),
      ),
    );
  }
}
