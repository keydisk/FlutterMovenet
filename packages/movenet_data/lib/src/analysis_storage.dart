import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisStorage {
  static const _key = 'movenet.analysisHistory';

  Future<List<AnalysisRecord>> load() async {
    final values =
        (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];
    final root = await _containerRoot();
    return values
        .map(
          (value) => AnalysisRecord.fromJson(
            rebasePaths(
              (jsonDecode(value) as Map).cast<String, Object?>(),
              root,
              exists: (path) => File(path).existsSync(),
            ),
          ),
        )
        .toList();
  }

  /// 앱 데이터 컨테이너 루트(iOS: Documents의 상위, 끝에 '/').
  static Future<String> _containerRoot() async =>
      '${(await getApplicationDocumentsDirectory()).parent.path}/';

  /// iOS 컨테이너 경로(`.../Data/Application/<UUID>/`) 앞부분.
  static final _iosContainer = RegExp(r'^.*/Data/Application/[0-9A-Fa-f-]+/');

  /// iOS는 앱을 다시 설치·업데이트하면 데이터 컨테이너 UUID가 바뀌어,
  /// 저장해 둔 절대 경로(영상·섬네일·위험 스냅샷)가 모두 없는 파일을 가리키게 된다.
  /// 파일이 없으면 지금 컨테이너 루트로 경로 앞부분을 바꿔 끼운다.
  @visibleForTesting
  static Map<String, Object?> rebasePaths(
    Map<String, Object?> json,
    String root, {
    required bool Function(String path) exists,
  }) {
    String? rebase(Object? value) {
      if (value is! String) return null;
      if (exists(value)) return value;
      final match = _iosContainer.firstMatch(value);
      return match == null ? value : '$root${value.substring(match.end)}';
    }

    return {
      ...json,
      'videoPath': rebase(json['videoPath']),
      if (json['thumbnailPath'] != null)
        'thumbnailPath': rebase(json['thumbnailPath']),
      if (json['risks'] case final List<Object?> risks)
        'risks': [
          for (final risk in risks)
            if (risk case final Map<Object?, Object?> map)
              {
                ...map.cast<String, Object?>(),
                if (map['imagePath'] != null)
                  'imagePath': rebase(map['imagePath']),
              },
        ],
    };
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
