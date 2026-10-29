import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_screen.dart';
import '../../worlds/presentation/world_widgets.dart';
import '../application/stories.dart';
import 'story_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;

/// An interactive movie's page, or a visual novel's (P18a): the hero, `Interactive movie · The
/// Undersong · 14 scenes`, `Continue · The drowned quarter` — `Play` before there is a save, `Start again` when the
/// save cannot be replayed (R-88) — its size and ⋯ with `Start over`; then `Your route`, scene by
/// scene with the choice taken after each and `Choose again` (R-86). A newer package in Arke's list
/// is its `Update` (R-83).
class StoryProductionScreen extends ConsumerWidget {
  const StoryProductionScreen({required this.world, required this.production, super.key});

  final LibraryWorld world;
  final LibraryProduction production;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = production.story!;
    final key = (world.id, production.id);
    final loaded = ref.watch(loadedStoryProvider(key)).value;
    final resume = ref.watch(storyResumeProvider(key));
    final store = ref.watch(libraryStoreProvider).value;
    final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], world.id);
    final update = ref.watch(productionUpdateProvider(key));
    final state = ref.watch(productionInstallProvider(key));
    ref.listen(productionInstallProvider(key), (previous, next) {
      if (next is InstallFailed && previous is! InstallFailed && listed != null && update != null) {
        showInstallRefusal(context, ref, listed, next.refusal, updating: true, production: update);
      }
    });
    final saves = ref.read(storySavesProvider.notifier);

    void open() => context.push(Routes.story(world.id, production.id));

    // Narration turned off stays off for this story (P19 call 26), through a new route as through an
    // old one, wherever the old save can still be read.
    bool narration() => loaded == null || (StorySave.read(ref.read(storySavesProvider).value?[loaded.key])?.narration ?? true);

    Future<void> startAgain() async {
      if (loaded == null) return;
      await saves.keep(loaded, StorySave.start(loaded.document, DateTime.now().toUtc(), narration: narration()));
      open();
    }

    // Choose again from the page (R-86): the route cut before that choice, and the player opened at
    // that decision.
    Future<void> chooseAgain(List<String> route, int index) async {
      if (loaded == null) return;
      final step = chooseStoryAgain(loaded.document, route, index);
      await saves.keep(loaded, StorySave.at(loaded.document, step, const StoryAtChoice(), DateTime.now().toUtc(), narration: narration()));
      open();
    }

    Future<void> menu() async {
      final chosen = await showArkeSheet<bool>(
        context,
        title: production.title,
        builder: (sheet) => ListTile(leading: const Icon(Icons.replay_rounded), title: const Text('Start over'), onTap: () => Navigator.of(sheet).pop(true)),
      );
      // Start over empties the route (R-86): the page offers Play again.
      if (chosen == true && loaded != null) await saves.keep(loaded, null);
    }

    final continuing = resume is StoryContinue ? resume : null;
    final path = continuing == null || loaded == null ? null : storyPath(loaded.document, continuing.step.route);
    final bytes = production.package?.byteLength ?? 0;

    return Scaffold(
      body: ScrolledHead(
        title: production.title,
        onMore: menu,
        child: ListView(
          padding: EdgeInsets.only(bottom: footRoom(context)),
          children: [
            WorldHero(
              picture: libraryPicture(store, production.picture ?? world.keyArt),
              title: production.title,
              meta: [storyKindLabel(story.kind), world.name, sceneCount(story.scenes)].join(' · '),
              onMore: menu,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  switch (resume) {
                    StoryContinue(:final step) when loaded != null => HeroPress(
                      icon: Icons.play_arrow_rounded,
                      label: 'Continue',
                      detail: loaded.document.scenes[step.scene]!.title,
                      onPressed: open,
                    ),
                    StoryStartAgain() => HeroPress(icon: Icons.replay_rounded, label: 'Start again', onPressed: startAgain),
                    _ => HeroPress(icon: Icons.play_arrow_rounded, label: 'Play', onPressed: open),
                  },
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width >= WindowBands.fold ? 320 : double.infinity,
                      child: Row(
                        children: [
                          Expanded(child: _Size(bytes: bytes)),
                          const SizedBox(width: 8),
                          _More(onPressed: menu),
                        ],
                      ),
                    ),
                  ),
                  switch (state) {
                    Installing() => InstallProgress(state: state, onCancel: () => ref.read(productionInstallProvider(key).notifier).cancel()),
                    _ when update != null && listed != null => HeroSecondPress(
                      icon: Icons.download_rounded,
                      label: 'Update',
                      detail: formatBytes(update.alone!.byteLength),
                      onPressed: () => ref.read(productionInstallProvider(key).notifier).start(listed, update),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ],
              ),
            ),
            if (path != null && loaded != null) ...[
              const SectionHead('Your route'),
              RouteRows(story: loaded, path: path, onMedia: false, onChooseAgain: (index) => chooseAgain(continuing!.step.route, index)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// What the story takes on the phone, in the hero's quiet fill, as P1e's size press is: data, not a
/// press, since it is already on the phone.
class _Size extends StatelessWidget {
  const _Size({required this.bytes});
  final int bytes;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${formatBytes(bytes)} downloaded',
    child: ExcludeSemantics(
      child: Container(
        height: ArkeSizes.press,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _fg.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(ArkeRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 18, color: _fg),
            const SizedBox(width: 8),
            Text(
              formatBytes(bytes),
              style: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500, color: _fg),
            ),
          ],
        ),
      ),
    ),
  );
}

/// ⋯ beside the size, round, in the same fill.
class _More extends StatelessWidget {
  const _More({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: 'More',
    style: IconButton.styleFrom(fixedSize: const Size.square(ArkeSizes.press), backgroundColor: _fg.withValues(alpha: 0.16), foregroundColor: _fg),
    icon: const Icon(Icons.more_horiz, size: 22),
  );
}
