import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/device_settings.dart';
import '../application/audio_engine.dart';
import '../application/captions.dart';
import '../application/listening_plan.dart';
import '../application/players.dart';
import 'chrome.dart';
import 'picture_of_the_moment.dart';

const _fg = ArkeColors.mediaOverlayForeground;

/// An audio file in the audio player (P7d; transport as P5a, chapters P5b, speed and sleep P5c):
/// its cover square and centred, the title and author under it, the chapter's scrubber, then
/// previous chapter, back 15, play or pause, forward 30, next chapter; speed and sleep under
/// those. It shows what the file carries and invents nothing: no Text, no Slow push (P7 rule 6).
///
/// A world's illustrated narration (SPEC-058 R-22 – R-27) is the same player as P5a draws it: the
/// picture of the moment over the top 62%, Slow push under the title, Text above the transport.
class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({required this.item, required this.store, super.key});

  final LibraryItem item;
  final LibraryStore store;

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  late final AudioEngine _engine = ref.read(audioEngineProvider)!;
  ListeningPlan? _plan;
  bool _unreadable = false;
  final _captions = Captions();

  bool get _illustrated => widget.item.format == FileFormat.listening;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value ?? const DeviceSettings();
    final keep = ref.read(placeKeeperProvider);
    final item = widget.item;
    final art = item.cover == null ? null : widget.store.resolve(item.cover!);
    void keepPlace(Place place, {bool? finished}) => keep(item.id, place, finished: finished);
    // Back from the dock, the narration playing already has its plan.
    final playing = _engine.item?.id == item.id ? _engine.plan : null;
    if (_illustrated && playing != null) {
      _plan = playing;
      _engine.open(item, plan: playing, artPath: art, speed: settings.speed, keep: keepPlace);
    } else if (_illustrated) {
      loadListeningPlan(widget.store, item).then(
        (plan) {
          if (!mounted) return;
          setState(() => _plan = plan);
          _engine.open(item, plan: plan, artPath: art, speed: settings.speed, keep: keepPlace);
        },
        onError: (Object _) {
          if (mounted) setState(() => _unreadable = true);
        },
      );
    } else {
      _engine.open(item, path: widget.store.resolve(item.file), artPath: art, speed: settings.speed, keep: keepPlace);
    }
    if (settings.sleep != SleepTimer.off) _engine.setSleep(settings.sleep);
  }

  @override
  Widget build(BuildContext context) {
    if (_illustrated) {
      final plan = _plan;
      if (plan != null) return _illustratedBody(context, plan);
      return Scaffold(
        backgroundColor: ArkeColors.mediaOverlayBackground,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: _fg),
        body: Center(
          child: _unreadable
              ? Text(
                  "Can't open this file",
                  style: TextStyle(color: _fg.withValues(alpha: 0.8), fontSize: ArkeType.sizeBase),
                )
              : const CircularProgressIndicator(color: _fg),
        ),
      );
    }
    return _coverBody(context);
  }

  /// The picture of the moment over the top 62%, the chapter and Slow push over it, Text above the
  /// transport (P5a). A phone in portrait on a moment with a Tall picture shows that one over the
  /// whole screen instead, the chrome and words on P14's foot scrim (SPEC-058 R-39).
  Widget _illustratedBody(BuildContext context, ListeningPlan plan) {
    final item = widget.item;
    final size = MediaQuery.sizeOf(context);
    // Narrower than a Fold and taller than wide: a tablet, a Fold and a phone turned show Wide.
    final portraitPhone = size.width < WindowBands.fold && size.height > size.width;
    final settings = ref.watch(settingsProvider).value ?? const DeviceSettings();
    final push = settings.slowPushIn(reducedMotion: MediaQuery.disableAnimationsOf(context));
    final controller = ref.read(settingsProvider.notifier);
    const bg = ArkeColors.mediaOverlayBackground;
    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<Duration>(
        stream: _engine.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? _engine.now;
          final index = _engine.chapterAt(position);
          final shown = plan.shownAt(position);
          final tall = portraitPhone && shown?.tallPath != null;
          // The top 62% on a phone; 16:9 across a Fold (R-22); the whole screen for a Tall picture
          // (R-39), decided per moment, so turning the phone swaps the shape mid-hold.
          final frame = tall
              ? size.height
              : size.width >= WindowBands.fold
              ? (size.width * 9 / 16).clamp(0.0, size.height * 0.62)
              : size.height * 0.62;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: frame,
                child: StreamBuilder<bool>(
                  stream: _engine.playingStream,
                  initialData: _engine.playing,
                  builder: (context, playing) => PictureOfTheMoment(
                    shown: tall ? shown!.tall : shown,
                    position: position,
                    playing: playing.data ?? false,
                    speed: _engine.speed,
                    push: push,
                    fill: tall,
                  ),
                ),
              ),
              // The two scrims the chrome rests on (Studio 186): one from the top, one from the foot.
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 170,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xB30A0A0A), Color(0x000A0A0A)]),
                  ),
                ),
              ),
              if (tall)
                // P14's foot scrim over a picture that runs to the bottom: 520 high, 90% from its
                // lowest 12%; with Text on 600 high and 92% to 40% of it, so the words read on any
                // picture (P14b).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: (settings.text ? 600.0 : 520.0).clamp(0.0, size.height),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: settings.text
                            ? const [Color(0xEB0A0A0A), Color(0xEB0A0A0A), Color(0x000A0A0A)]
                            : const [Color(0xE60A0A0A), Color(0xE60A0A0A), Color(0x000A0A0A)],
                        stops: settings.text ? const [0, 0.4, 1] : const [0, 0.12, 1],
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  left: 0,
                  right: 0,
                  top: frame * 0.6,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [Color(0x000A0A0A), bg, bg],
                        stops: [0, (frame * 0.4 / (size.height - frame * 0.6)).clamp(0.0, 1.0), 1],
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PlayerTop(
                      eyebrow: item.title,
                      title: '${index + 1} · ${item.chapters[index].title}',
                      actions: [PlayerPress(icon: Icons.format_list_bulleted, label: 'Chapters', onPressed: () => _chapters(context))],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PlayerLabelPress(
                          label: 'Slow push',
                          icon: settings.slowPush ? Icons.toggle_on : Icons.toggle_off_outlined,
                          on: settings.slowPush,
                          onPressed: () => controller.change((s) => s.copyWith(slowPush: !s.slowPush)),
                        ),
                      ),
                    ),
                    if (settings.text) Expanded(child: _text(plan, position)) else const Spacer(),
                    _transport(
                      context,
                      position,
                      chaptered: item.chapters.length > 1,
                      extra: PlayerLabelPress(
                        label: 'Text',
                        icon: Icons.subject,
                        on: settings.text,
                        onPressed: () => controller.change((s) => s.copyWith(text: !s.text)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const _textStyle = TextStyle(
    color: _fg,
    fontSize: ArkeType.sizeLg,
    fontWeight: FontWeight.w500,
    height: 1.35,
    shadows: [Shadow(color: Color(0x990A0A0A), blurRadius: 8)],
  );

  /// Text (R-24): the cue being heard, centred above the transport in the lines there is room for
  /// under Slow push — two at most, one where only one fits, none where none does.
  Widget _text(ListeningPlan plan, Duration position) => LayoutBuilder(
    builder: (context, box) {
      final phrase = plan.phraseAt(position);
      final scaler = MediaQuery.textScalerOf(context);
      final line = scaler.scale(ArkeType.sizeLg) * 1.35;
      final rows = ((box.maxHeight - 24 - 14) / line).floor().clamp(0, 2);
      if (phrase == null || rows == 0) return const SizedBox.shrink();
      final width = (box.maxWidth - 40).clamp(0.0, 640.0);
      // Measured in the face the cue is drawn in: the theme's, not the bare style's default.
      final style = DefaultTextStyle.of(context).style.merge(_textStyle);
      bool fits(String text) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: rows,
          textScaler: scaler,
        )..layout(maxWidth: width);
        final fits = !painter.didExceedMaxLines;
        painter.dispose();
        return fits;
      }

      final cue = _captions.at(phrase, plan.locate(position).$2, (width, rows, line), fits);
      if (cue == null) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SizedBox(
            width: width,
            child: Text(cue.text, textAlign: TextAlign.center, maxLines: rows, style: style),
          ),
        ),
      );
    },
  );

  Widget _coverBody(BuildContext context) {
    final item = widget.item;
    final chaptered = item.chapters.length > 1;
    final cover = item.cover == null ? null : File(widget.store.resolve(item.cover!));
    final size = MediaQuery.sizeOf(context);
    final coverSide = (size.width - 90).clamp(160.0, size.height * 0.42).clamp(160.0, 420.0);

    return Scaffold(
      backgroundColor: ArkeColors.mediaOverlayBackground,
      body: SafeArea(
        child: StreamBuilder<Duration>(
          stream: _engine.position,
          builder: (context, snapshot) {
            final position = snapshot.data ?? _engine.now;
            final index = _engine.chapterAt(position);
            return Column(
              children: [
                PlayerTop(
                  eyebrow: item.title,
                  title: chaptered ? '${index + 1} · ${item.chapters[index].title}' : (item.author ?? item.format.label),
                  actions: [if (chaptered) PlayerPress(icon: Icons.format_list_bulleted, label: 'Chapters', onPressed: () => _chapters(context))],
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(ArkeRadius.xl),
                  child: SizedBox.square(
                    dimension: coverSide,
                    child: cover != null
                        ? Image.file(cover, fit: BoxFit.cover)
                        : ColoredBox(
                            color: ArkeColors.neutral800,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  item.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: _fg, fontSize: ArkeType.sizeXl, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _fg, fontSize: ArkeType.sizeLg, fontWeight: FontWeight.w600),
                      ),
                      if (item.author != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.author!,
                          style: TextStyle(color: _fg.withValues(alpha: 0.68), fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                _transport(context, position, chaptered: chaptered),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The scrubber across the playing chapter, the transport, then speed and sleep (P5a, P7d).
  Widget _transport(BuildContext context, Duration position, {required bool chaptered, Widget? extra}) {
    final (start, end) = _engine.chapterBounds(position);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            // The scrubber runs across the playing chapter (Studio 186).
            Scrubber(position: position - start, length: end - start, onSeek: (offset) => _engine.seek(start + offset)),
            const SizedBox(height: 14),
            StreamBuilder<bool>(
              stream: _engine.playingStream,
              initialData: _engine.playing,
              builder: (context, playing) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PlayerPress(icon: Icons.skip_previous_rounded, label: chaptered ? 'Previous chapter' : 'Start', onPressed: _engine.skipToPrevious),
                  PlayerPress(icon: Icons.replay, label: 'Back 15 seconds', onPressed: _engine.rewind, size: 26),
                  PlayPause(playing: playing.data ?? false, onPressed: () => (playing.data ?? false) ? _engine.pause() : _engine.play()),
                  PlayerPress(icon: Icons.forward_30, label: 'Forward 30 seconds', onPressed: _engine.fastForward, size: 26),
                  PlayerPress(icon: Icons.skip_next_rounded, label: 'Next chapter', onPressed: chaptered ? _engine.skipToNext : null),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlayerLabelPress(label: '${_speedLabel(_engine.speed)}×', onPressed: () => _speedAndSleep(context)),
                const SizedBox(width: 12),
                PlayerLabelPress(
                  label: _engine.sleep.label,
                  icon: Icons.bedtime_outlined,
                  on: _engine.sleep != SleepTimer.off,
                  onPressed: () => _speedAndSleep(context),
                ),
                if (extra != null) ...[const SizedBox(width: 12), extra],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _speedLabel(double speed) => speed == speed.roundToDouble() ? speed.toStringAsFixed(1) : '$speed';

  /// Chapters (P5b): number, title and length, a check when done, the playing one with its line.
  Future<void> _chapters(BuildContext context) => showPlayerSheet<void>(
    context,
    title: 'Chapters',
    count: '${widget.item.chapters.length}',
    builder: (context) {
      final chapters = widget.item.chapters;
      final position = _engine.now;
      final playing = _engine.chapterAt(position);
      return ListView.builder(
        shrinkWrap: true,
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final end = index + 1 < chapters.length ? chapters[index + 1].start : _engine.length;
          final length = end - chapters[index].start;
          final now = index == playing;
          final done = position >= end;
          return Material(
            color: now ? _fg.withValues(alpha: 0.08) : Colors.transparent,
            child: InkWell(
              onTap: () {
                _engine.seek(chapters[index].start);
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: _fg.withValues(alpha: 0.56), fontSize: ArkeType.sizeSm),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapters[index].title,
                            style: const TextStyle(color: _fg, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
                          ),
                          if (now) ...[
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: length.inMilliseconds == 0 ? 0 : (position - chapters[index].start).inMilliseconds / length.inMilliseconds,
                              minHeight: 3,
                              color: _fg,
                              backgroundColor: _fg.withValues(alpha: 0.2),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatClock(length),
                      style: TextStyle(color: _fg.withValues(alpha: 0.62), fontSize: ArkeType.size2xs),
                    ),
                    SizedBox(width: 28, child: done ? Icon(Icons.check, size: 18, color: _fg.withValues(alpha: 0.7)) : null),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  /// Speed and sleep (P5c), both kept on the device.
  Future<void> _speedAndSleep(BuildContext context) async {
    await showPlayerSheet<void>(
      context,
      title: 'Speed',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final controller = ref.read(settingsProvider.notifier);
          return ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<double>(
                  segments: [
                    for (final speed in const [0.8, 1.0, 1.2, 1.5, 2.0]) ButtonSegment(value: speed, label: Text('${speed == 2.0 ? '2' : speed}×')),
                  ],
                  selected: {_engine.speed},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) async {
                    await _engine.setSpeed(value.first);
                    await controller.change((settings) => settings.copyWith(speed: value.first));
                    setSheet(() {});
                    setState(() {});
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 22, 16, 4),
                child: Text(
                  'Sleep',
                  style: TextStyle(color: _fg, fontSize: ArkeType.sizeLg, fontWeight: FontWeight.w600),
                ),
              ),
              for (final sleep in SleepTimer.values)
                if (sleep != SleepTimer.endOfChapter || widget.item.chapters.length > 1)
                  ListTile(
                    title: Text(sleep.label, style: const TextStyle(color: _fg)),
                    trailing: _engine.sleep == sleep ? const Icon(Icons.check, color: _fg) : null,
                    onTap: () async {
                      _engine.setSleep(sleep);
                      await controller.change((settings) => settings.copyWith(sleep: sleep));
                      setSheet(() {});
                      setState(() {});
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
