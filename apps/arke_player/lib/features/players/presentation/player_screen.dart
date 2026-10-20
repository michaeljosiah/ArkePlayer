import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/frame_placeholder.dart';

/// A production in its player, chosen by kind (players/domain/player_kind.dart).
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({required this.productionId, super.key});

  final String productionId;

  @override
  Widget build(BuildContext context) => FramePlaceholder(
    title: productionId,
    frames: const ['P3a–P3e', 'P4a–P4e', 'P5a–P5d', 'P6f'],
    media: true,
    actions: [FilledButton(onPressed: () => context.pop(), child: const Text('Close'))],
  );
}
