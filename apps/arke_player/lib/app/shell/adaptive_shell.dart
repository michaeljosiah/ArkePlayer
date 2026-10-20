import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/players/presentation/dock.dart';
import '../theme/tokens.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('Home', Icons.home_outlined, Icons.home),
  _Tab('Library', Icons.video_library_outlined, Icons.video_library),
  _Tab('Downloads', Icons.download_outlined, Icons.download),
  _Tab('You', Icons.account_circle_outlined, Icons.account_circle),
];

/// The four tabs: a bar above the home indicator on a phone, an 88-wide rail from 600 wide
/// (Arke Player P1 rule 3, P6 rule 5). A page pushed from a tab keeps them.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final railed = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    if (railed) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final tab in _tabs) NavigationRailDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: Text(tab.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: shell),
                  const Dock(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: shell),
          const Dock(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [for (final tab in _tabs) NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label)],
      ),
    );
  }
}
