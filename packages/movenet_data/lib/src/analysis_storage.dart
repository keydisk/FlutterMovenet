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

  /// 새 기록을 맨 앞에 넣는다. 같은 id가 있으면 교체한다(재분석).
  Future<void> save(AnalysisRecord record) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_key) ?? <String>[];
    await preferences.setStringList(
      _key,
      [
        jsonEncode(record.toJson()),
        for (final value in values)
          if ((jsonDecode(value) as Map)['id'] != record.id) value,
      ].take(50).toList(),
    );
  }

  Future<void> remove(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_key) ?? <String>[];
    await preferences.setStringList(_key, [
      for (final value in values)
        if ((jsonDecode(value) as Map)['id'] != id) value,
    ]);
  }
}
