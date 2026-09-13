import 'dart:convert';

import 'package:movenet_domain/movenet_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisStorage {
  static const _key = 'movenet.analysisHistory';

  Future<List<AnalysisRecord>> load() async {
    final values =
        (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];
    return values
        .map(
          (value) => AnalysisRecord.fromJson(
            (jsonDecode(value) as Map).cast<String, Object?>(),
          ),
        )
        .toList();
  }

  Future<void> prepend(AnalysisRecord record) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_key) ?? <String>[];
    await preferences.setStringList(
      _key,
      [jsonEncode(record.toJson()), ...values].take(50).toList(),
    );
  }
}
