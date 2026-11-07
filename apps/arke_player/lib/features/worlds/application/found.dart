import 'package:arke_world/arke_world.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_controller.dart';

/// Every entry of a guide: what a world's `10 of 17 found` counts (P23 rule 6).
Iterable<GuideEntry> entriesOf(Guide guide) => [...guide.characters, ...guide.places, ...guide.lore];

/// How many of [entries] this reader has: all that is open from the start, and all that is reached or
/// revealed. A measure of the world, never a score, so nothing is ever awarded for it (call 47).
({int got, int of}) foundIn(Iterable<GuideEntry> entries, GuideReach reach) =>
    (got: entries.where((entry) => reach.shows(entry.after)).length, of: entries.length);

/// With nothing that waits for a chapter there is nothing to find, and a count would only say so.
bool hasWaiting(Guide guide) => entriesOf(guide).any((entry) => entry.after != null);

/// A found entry keeps `New` until it is opened (P23 rule 7). What was open from the start was never
/// found, so it never is.
bool isNewEntry(String worldId, GuideEntry entry, GuideReach reach, Set<String> opened) =>
    entry.after != null && reach.shows(entry.after) && !opened.contains(_opened(worldId, entry.id));

String _opened(String worldId, String entryId) => '$worldId/$entryId';

/// An entry has been opened: its `New` goes, here and everywhere it shows.
Future<void> markEntryOpened(WidgetRef ref, String worldId, String entryId) =>
    ref.read(settingsProvider.notifier).change((current) => current.copyWith(opened: {...current.opened, _opened(worldId, entryId)}));
