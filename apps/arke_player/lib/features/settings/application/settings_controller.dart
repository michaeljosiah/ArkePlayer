import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/device_settings.dart';

/// The device's settings, read once and written on every change. If storage is refused the
/// choice still holds for the open app; nothing that plays waits on a write (Studio 211 rule 3).
class SettingsController extends AsyncNotifier<DeviceSettings> {
  static const _prefix = 'arke.';

  @override
  Future<DeviceSettings> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return DeviceSettings.fromPrefs((key) => prefs.get('$_prefix$key'));
    } on Exception {
      return const DeviceSettings();
    }
  }

  Future<void> change(DeviceSettings Function(DeviceSettings current) edit) async {
    final next = edit(state.value ?? const DeviceSettings());
    state = AsyncData(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final MapEntry(:key, :value) in next.toPrefs().entries) {
        switch (value) {
          case final bool flag:
            await prefs.setBool('$_prefix$key', flag);
          case final double number:
            await prefs.setDouble('$_prefix$key', number);
          case final String text:
            await prefs.setString('$_prefix$key', text);
        }
      }
    } on Exception {
      // Kept for this session only.
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, DeviceSettings>(SettingsController.new);
