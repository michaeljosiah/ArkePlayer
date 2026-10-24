import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/players/application/players.dart';
import '../../features/players/presentation/dock.dart';
import '../theme/tokens.dart';
import '../widgets/shelf.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('Home', Icons.home_outlined, Icons.home),
  _Tab('Discover', Icons.explore_outlined, Icons.explore),
  _Tab('Library', Icons.video_library_outlined, Icons.video_library),
  _Tab('Downloads', Icons.download_outlined, Icons.download),
  _Tab('You', Icons.account_circle_outlined, Icons.account_circle),
];

/// The five tabs as a pill floating over the page (Arke Player P16 rule 9, call 16, in place of P1
/// rule 3's bar and P6e's rail): 358 × 64 on a phone, 520 wide from 600, 24 above the foot. The page
/// runs under it to the foot, fading into the page's ground, and is given the pill's room as its
/// bottom padding so its last row clears it ([footRoom]). Audio playing with its player closed
/// docks above the pill (P16i). A page pushed from a tab keeps them.
class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// The pill's height, and the gap between it and the dock or the page's last row.
  static const pillHeight = 64.0;
  static const gap = 12.0;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= WindowBands.fold;
    final pillWidth = math.min(wide ? 520.0 : 358.0, media.size.width - 32);
    // 24 above the foot where the phone keeps 34 for its home indicator, as P16h draws it; never
    // closer than 12 to a foot with no inset.
    final pillBottom = math.max(12.0, media.padding.bottom - 10);
    final engine = ref.watch(audioEngineProvider);
    return Scaffold(
      body: StreamBuilder<bool>(
        stream: engine?.playingStream,
        builder: (context, _) {
          final docked = engine?.item != null;
          final room = pillBottom + pillHeight + gap + (docked ? ArkeSizes.dock + 10 : 0);
          final surface = context.surface;
          return Stack(
            children: [
              Positioned.fill(
                child: MediaQuery(
                  data: media.copyWith(
                    padding: media.padding.copyWith(bottom: room),
                    viewPadding: media.viewPadding.copyWith(bottom: math.max(media.viewPadding.bottom, room)),
                  ),
                  child: shell,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: pillBottom + pillHeight + 44,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [surface.background, surface.background.withValues(alpha: 0)],
                        stops: const [0.22, 1],
                      ),
                    ),
                  ),
                ),
              ),
              if (docked)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: pillBottom + pillHeight + 10,
                  child: Center(
                    child: SizedBox(width: pillWidth, child: const Dock(floating: true)),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: pillBottom,
                child: Center(
                  child: TabPill(width: pillWidth, selected: shell.currentIndex, onSelect: _go),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The pill itself: glass over the page in the theme's card colour, the current tab in a capsule.
class TabPill extends StatelessWidget {
  const TabPill({required this.width, required this.selected, required this.onSelect, super.key});

  final double width;
  final int selected;
  final ValueChanged<int> onSelect;

  /// The tabs' labels, in order: what a test reads the pill by.
  static List<String> get labels => [for (final tab in _tabs) tab.label];

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    // The labels grow with the phone's text only so far: five must share 358.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ArkeRadius.pill),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), offset: Offset(0, 20), blurRadius: 25, spreadRadius: -5),
            BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 10, spreadRadius: -6),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ArkeRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: width,
              height: AdaptiveShell.pillHeight,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: surface.card.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(ArkeRadius.pill),
                border: Border.all(color: surface.foreground.withValues(alpha: 0.11)),
              ),
              child: Row(
                children: [
                  for (final (i, tab) in _tabs.indexed)
                    Expanded(
                      child: _PillTab(tab: tab, on: i == selected, onTap: () => onSelect(i)),
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

class _PillTab extends StatelessWidget {
  const _PillTab({required this.tab, required this.on, required this.onTap});

  final _Tab tab;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final ink = on ? surface.foreground : surface.mutedForeground;
    return Semantics(
      button: true,
      selected: on,
      label: tab.label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Ink(
            decoration: ShapeDecoration(shape: const StadiumBorder(), color: on ? surface.foreground.withValues(alpha: 0.10) : null),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(on ? tab.selectedIcon : tab.icon, size: 22, color: ink),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    style: TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.size2xs, fontWeight: FontWeight.w500, color: ink, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
