import 'package:flutter/material.dart';

import '../../../app/widgets/frame_placeholder.dart';

/// You: the account, Playback, Downloads, Content, About — every setting this device's.
class YouScreen extends StatelessWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context) => const FramePlaceholder(title: 'You', frames: ['P6b', 'P6c']);
}
