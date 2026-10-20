import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/widgets/frame_placeholder.dart';

/// A world: its key art, one meta line, its logline, its productions by Watch, Play, Listen and Read.
class WorldScreen extends StatelessWidget {
  const WorldScreen({required this.worldId, super.key});

  final String worldId;

  @override
  Widget build(BuildContext context) => FramePlaceholder(
    title: worldId,
    frames: const ['P1d', 'P6c'],
    actions: [FilledButton(onPressed: () => context.go(Routes.production(worldId, 'the-tenth-key')), child: const Text('The Tenth Key'))],
  );
}
