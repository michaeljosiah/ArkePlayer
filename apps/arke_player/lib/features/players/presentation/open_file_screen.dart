import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/frame_placeholder.dart';

/// An added standard file in its player: the reader, the page viewer, the audiobook or the film player.
class OpenFileScreen extends StatelessWidget {
  const OpenFileScreen({required this.fileId, super.key});

  final String fileId;

  @override
  Widget build(BuildContext context) => FramePlaceholder(
    title: fileId,
    frames: const ['P5e', 'P7c', 'P7d'],
    media: true,
    actions: [FilledButton(onPressed: () => context.pop(), child: const Text('Close'))],
  );
}
