import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/router/router.dart';
import 'app/router/routes.dart';
import 'features/players/application/audio_engine.dart';
import 'features/players/application/players.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  _registerFontLicences();

  // First open (P8a) until a file has been added; Home after.
  var seenFirstOpen = false;
  try {
    seenFirstOpen = (await SharedPreferences.getInstance()).getBool('arke.seenFirstOpen') ?? false;
  } on Exception {
    // Storage refused: show first open; adding a file sets it again.
  }
  // The media session exists before anything plays, so the lock screen, the headset and the
  // notification reach the engine from the first press (ADR 0004).
  final engine = await AudioService.init(
    builder: AudioEngine.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'studio.arke.player.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: true,
      // The mark in white: the status bar draws only an icon's alpha, so the launcher icon was a blob.
      androidNotificationIcon: 'drawable/ic_stat_arke',
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 30),
      rewindInterval: Duration(seconds: 15),
    ),
  );
  final router = buildRouter(initialLocation: seenFirstOpen ? Routes.home : Routes.welcome);
  runApp(ProviderScope(overrides: [routerProvider.overrideWithValue(router), audioEngineProvider.overrideWithValue(engine)], child: const ArkePlayerApp()));
}

/// Geist and Jost are OFL-1.1; their licences ship beside the fonts and show under Licences (P8f).
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [('Geist Sans', 'GeistSans-OFL.txt'), ('Jost', 'Jost-OFL.txt')]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}
