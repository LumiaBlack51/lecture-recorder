import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._preferencesFuture);

  static const _settingsKey = 'app_settings_v1';

  final Future<SharedPreferences> _preferencesFuture;

  Future<AppSettings> load() async {
    final preferences = await _preferencesFuture;
    final raw = preferences.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      final defaults = AppSettings.defaults();
      await save(defaults);
      return defaults;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      final defaults = AppSettings.defaults();
      await save(defaults);
      return defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    final preferences = await _preferencesFuture;
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
