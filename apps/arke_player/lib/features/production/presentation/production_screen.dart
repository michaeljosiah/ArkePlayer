import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/widgets/frame_placeholder.dart';

/// A production: the show page — Play or Continue, the download, chapters or episodes.
class ProductionScreen extends StatelessWidget {
  const ProductionScreen({required this.worldId, required this.productionId, super.key});

  final String worldId;
  final String productionId;

  @override
  Widget build(BuildContext context) => FramePlaceholder(
    title: productionId,
    frames: const ['P1e', 'P1f'],
    actions: [FilledButton(onPressed: () => context.push(Routes.play(productionId)), child: const Text('Continue'))],
  );
}
