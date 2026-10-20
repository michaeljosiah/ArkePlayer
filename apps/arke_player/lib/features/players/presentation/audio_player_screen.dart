import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/device_settings.dart';
import '../application/audio_engine.dart';
import '../application/players.dart';
import 'chrome.dart';

const _fg = ArkeColors.mediaOverlayForeground;

/// An audio file in the audio player (P7d; transport as P5a, chapters P5b, speed and sleep P5c):
/// its cover square and centred, the title and author under it, the chapter's scrubber, then
/// previous chapter, back 15, play or pause, forward 30, next chapter; speed and sleep under
/// those. It shows what the file carries and invents nothing: no Text, no Slow push (P7 rule 6).
class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({required this.item, required this.store, super.key});

  final LibraryItem item;
  final LibraryStore store;

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  late final AudioEngine _engine = ref.read(audioEngineProvider)!;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value ?? const DeviceSettings();
    final keep = ref.read(placeKeeperProvider);
    final item = widget.item;
    _engine.open(
      item,
      path: widget.store.resolve(item.file),
      artPath: item.cover == null ? null : widget.store.resolve(item.cover!),
      speed: settings.speed,
      keep: (place, {finished}) => keep(item.id, place, finished: finished),
    );
    if (settings.sleep != SleepTimer.off) _engine.setSleep(settings.sleep);
  }

  @override
  Widget build(BuildContext context) {
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
            final (start, end) = _engine.chapterBounds(position);
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
                Padding(
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
                              PlayerPress(
                                icon: Icons.skip_previous_rounded,
                                label: chaptered ? 'Previous chapter' : 'Start',
                                onPressed: _engine.skipToPrevious,
                              ),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
