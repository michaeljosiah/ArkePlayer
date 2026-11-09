import 'dart:async';

import 'package:flutter/widgets.dart';

/// audio_service can warm the main engine when WorkManager registers plugins without an
/// Activity. Keep the UI (and its writable library) dormant until the user opens it, so
/// the daily chapter check only fills the inbox (SPEC-058 R-51, R-54, P15i).
Future<void> waitForFirstForeground() async {
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) return;
  final ready = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!ready.isCompleted) ready.complete();
    },
  );
  try {
    await ready.future;
  } finally {
    listener.dispose();
  }
}
