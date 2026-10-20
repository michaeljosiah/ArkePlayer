import 'package:flutter/material.dart';

import '../../../app/widgets/frame_placeholder.dart';

/// Add: Choose files or Paste a link; then each file read, checked or refused.
class AddScreen extends StatelessWidget {
  const AddScreen({super.key});

  @override
  Widget build(BuildContext context) => const FramePlaceholder(title: 'Add', frames: ['P2c', 'P2d', 'P2e', 'P2f', 'P7a']);
}
