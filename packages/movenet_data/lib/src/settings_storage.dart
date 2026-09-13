import 'dart:convert';

import 'package:movenet_domain/movenet_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorage {
  static const _key = 'movenet.settings';

  Future<AppSettings> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null
        ? const AppSettings()
        : AppSettings.fromJson(jsonDecode(value) as Map<String, Object?>);
  }

  Future<void> save(AppSettings settings) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(settings.toJson()),
    );
  }
}
