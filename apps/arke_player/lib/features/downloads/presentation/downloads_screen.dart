import 'package:flutter/material.dart';

import '../../../app/widgets/frame_placeholder.dart';

/// What is on the phone: space, Shared downloads, Added packages and files.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) => const FramePlaceholder(title: 'Downloads', frames: ['P6a']);
}
