import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app.dart';
import 'app/catalogue_channel.dart';
import 'app/foreground_start.dart';
import 'app/router/router.dart';
import 'features/parts/application/notices.dart';
import 'features/players/application/audio_engine.dart';
import 'features/players/application/players.dart';

Future<void> main() async {
  if (catalogueChannel.storageFolder.isNotEmpty && !Platform.isAndroid) {
    throw UnsupportedError('The isolated development channel currently requires the Android dev application ID.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  _registerFontLicences();

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
  // Headless media startup still gets its handler, but must not run Home's downloads or
  // load/clean the library alongside the scheduler's separate inbox writer (P15i).
  await waitForFirstForeground();
  // The daily check of Arke's list for a world's new chapters (SPEC-058 R-54); it is scheduled
  // only while a world's Notify is on.
  try {
    await Workmanager().initialize(dailyCheckDispatcher);
  } on Object {
    // A phone with no scheduler checks when the app opens.
  }
  // Nothing to set up: the app opens on Home (P25 rule 1, call 37).
  final router = buildRouter();
  // A notification opens the production it names (P15i), the app's first page under it.
  final notices = Notices();
  try {
    await notices.init(onOpen: (route) => unawaited(router.push(route)));
    if (await notices.launchRoute() case final String route) unawaited(router.push(route));
  } on Object {
    // No notifications on this phone: nothing to open from.
  }
  runApp(
    ProviderScope(
      overrides: [routerProvider.overrideWithValue(router), audioEngineProvider.overrideWithValue(engine), noticesProvider.overrideWithValue(notices)],
      child: const ArkePlayerApp(),
    ),
  );
}

/// Geist and Jost are OFL-1.1; their licences ship beside the fonts and show under Licences (P8f).
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [('Geist Sans', 'GeistSans-OFL.txt'), ('Jost', 'Jost-OFL.txt')]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}
