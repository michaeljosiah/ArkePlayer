import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../app/router/routes.dart';
import '../../settings/domain/device_settings.dart';
import '../../worlds/application/worlds.dart';
import 'parts.dart';

/// The phone's own notifications of a world's new chapters (SPEC-058 R-54, P15i): per world, off
/// until turned on; each names the world, the chapter and the production, and opens the production.
/// No account and no server: they come from the app's own check of Arke's list.
class Notices {
  Notices([FlutterLocalNotificationsPlugin? plugin]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'studio.arke.player.chapters',
    'New chapters',
    channelDescription: 'A world’s new chapters, for the worlds you turned Notify on for.',
    icon: 'ic_stat_arke',
  );

  /// Ready to show, and where a notification opened leads: the production it names.
  Future<void> init({void Function(String route)? onOpen}) async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_arke'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload case final String route) onOpen?.call(route);
      },
    );
    _ready = true;
  }

  /// The route of the notification the app was opened from, if it was.
  Future<String?> launchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true ? details?.notificationResponse?.payload : null;
  }

  /// Asks the phone's permission, once, as the first world's Notify is turned on (P15 rule 9).
  Future<bool> ask() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  /// `Legend of Dumah` over `Chapter 3 · Whispers from the Void` (P15i).
  Future<void> chapterArrived(LibraryStore? store, CatalogueWorld world, CataloguePart part, {List<LibraryWorld>? installed}) async {
    await init();
    final held = (installed ?? store?.worlds ?? const <LibraryWorld>[]).where((candidate) => world.covers(candidate.id)).firstOrNull;
    final production = held?.productions.where((production) => production.id == part.production).firstOrNull;
    final title = production?.title ?? world.productions.where((listed) => listed.id == part.production).firstOrNull?.title;
    await _plugin.show(
      id: (world.id.hashCode ^ part.sha256.hashCode) & 0x7fffffff,
      title: world.name,
      body: [chaptersLabel(part.chapters), ?title].join(' · '),
      notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
      payload: Routes.production(Routes.world(held?.id ?? world.id), part.production),
    );
  }
}

/// The notifications. Replaced in tests, which have no phone to notify.
final noticesProvider = Provider<Notices>((ref) => Notices());

/// The daily check's name with the phone's scheduler.
const dailyCheck = 'studio.arke.player.daily-check';

/// Keeps the daily check in the phone's scheduler while any world's Notify is on (R-54), and only
/// then. On Wi-Fi when Wi-Fi only is on, as a download is.
Future<void> scheduleDailyCheck(DeviceSettings settings) async {
  final manager = Workmanager();
  if (settings.notify.isEmpty) {
    await manager.cancelByUniqueName(dailyCheck);
    return;
  }
  await manager.registerPeriodicTask(
    dailyCheck,
    dailyCheck,
    frequency: const Duration(days: 1),
    constraints: Constraints(networkType: settings.wifiOnly ? NetworkType.unmetered : NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

/// The daily check, run by the phone's scheduler in an isolate of its own (R-54): Arke's list
/// fetched as Discover fetches it (R-31), and each part an installed world lacks fetched and checked
/// ahead into the inbox — never added, as the app may be writing the library meanwhile; the app adds
/// it when it next opens (R-51). Each fetched for a world whose Notify is on is told of.
@pragma('vm:entry-point')
void dailyCheckDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = DeviceSettings.fromPrefs((key) => prefs.get('arke.$key'));
      if (settings.notify.isEmpty) return true;
      final support = await getApplicationSupportDirectory();
      final root = Directory('${support.path}${Platform.pathSeparator}library');
      // The index read, never loaded: loading clears what it does not name, an install mid-way
      // among it.
      final index = File('${root.path}${Platform.pathSeparator}library.json');
      if (!await index.exists()) return true;
      final installed = [
        for (final raw in ((jsonDecode(await index.readAsString()) as Map<String, Object?>)['worlds'] as List<Object?>? ?? const []))
          LibraryWorld.fromJson((raw! as Map).cast<String, Object?>()),
      ];
      final hosted = HostedCatalogue(url: arkeWorldsList, kept: File('${support.path}${Platform.pathSeparator}catalogue.json'));
      await hosted.refresh();
      final shipped = parseCatalogue(await rootBundle.loadString('assets/worlds/catalogue.json'));
      final catalogue = newestCatalogue(shipped, await hosted.keptList()).worlds;
      final installer = WorldInstaller(store: LibraryStore(root), freeBytes: (_) async => null);
      final inbox = partInbox(root);
      final notices = Notices();
      for (final world in installed) {
        final listed = listedFor(catalogue, world.id);
        if (listed == null) continue;
        for (final part in missingParts(listed, world)) {
          final file = inboxFile(inbox, world.id, part);
          if (await file.exists()) continue;
          await installer.fetchPart(part, file);
          if (settings.notify.contains(world.id)) await notices.chapterArrived(null, listed, part, installed: installed);
        }
      }
      return true;
    } on Object {
      // Tried again tomorrow, or when the app opens.
      return false;
    }
  });
}
