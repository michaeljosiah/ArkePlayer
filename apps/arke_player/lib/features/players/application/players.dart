import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import 'audio_engine.dart';
import 'listening_plan.dart';

/// The one audio engine, made by `AudioService.init` in main so the media session exists before
/// anything plays. Null in tests, which never play.
final audioEngineProvider = Provider<AudioEngine?>((ref) => null);

/// Keeps a place in the library (P1 rule 4): Continue reads it, and the player resumes from it.
Future<void> keepPlace(Ref ref, String itemId, Place place, {bool? finished}) async {
  final store = await ref.read(libraryStoreProvider.future);
  await store.keepPlace(itemId, place, finished: finished);
}

/// The item an `/open/:id` route names, with the library's root to resolve its files.
final openItemProvider = StreamProvider.autoDispose.family<({LibraryItem item, LibraryStore store})?, String>((ref, id) async* {
  final store = await ref.watch(libraryStoreProvider.future);
  ({LibraryItem item, LibraryStore store})? find(List<LibraryItem> items) {
    final item = items.where((item) => item.id == id).firstOrNull;
    return item == null ? null : (item: item, store: store);
  }

  yield find(store.items);
  await for (final items in store.changes) {
    yield find(items);
  }
});

/// A function that keeps places, for a player that is not a widget of Riverpod's.
final placeKeeperProvider = Provider<Future<void> Function(String itemId, Place place, {bool? finished})>(
  (ref) =>
      (itemId, place, {finished}) => keepPlace(ref, itemId, place, finished: finished),
);

/// A narration's listening document, for what a page shows of it: its episodes' pictures (P24 rule 2).
/// Null for a file, and for one that cannot be read, whose rows keep their numbers.
final listeningPlanProvider = FutureProvider.family<ListeningPlan?, String>((ref, itemId) async {
  final store = await ref.watch(libraryStoreProvider.future);
  final item = store.items.where((item) => item.id == itemId).firstOrNull;
  if (item == null || item.format != FileFormat.listening) return null;
  try {
    return await loadListeningPlan(store, item);
  } on Object {
    return null;
  }
});
