import 'dart:convert';
import 'dart:io';

import 'package:movenet_domain/movenet_domain.dart';

/// 분석 때 얻은 프레임별 MoveNet 포즈를 영상 옆 JSON 파일(`<영상>.poses.json`)로 보관한다.
/// 재생 중 관절·각도 오버레이가 이 트랙을 시간으로 찾아 그린다.
class PoseTrackStorage {
  const PoseTrackStorage();

  static String _path(String videoPath) => '$videoPath.poses.json';

  Future<void> save(String videoPath, List<PoseFrame> frames) =>
      File(_path(videoPath)).writeAsString(jsonEncode(encode(frames)));

  /// 저장된 트랙. 예전 기록처럼 파일이 없으면 null.
  Future<List<PoseFrame>?> load(String videoPath) async {
    final file = File(_path(videoPath));
    if (!await file.exists()) return null;
    return decode(jsonDecode(await file.readAsString()) as List<Object?>);
  }

  Future<bool> exists(String videoPath) => File(_path(videoPath)).exists();

  Future<void> delete(String videoPath) async {
    final file = File(_path(videoPath));
    if (await file.exists()) await file.delete();
  }

  /// 프레임마다 `[시각(ms), x, y, 신뢰도, ...]`를 Joint.values 순서로 담는다.
  static List<List<num>> encode(List<PoseFrame> frames) => [
    for (final frame in frames)
      [
        frame.timestamp.inMilliseconds,
        for (final joint in Joint.values)
          ...switch (frame.points[joint]) {
            final p? => [_round(p.x), _round(p.y), _round(p.confidence)],
            null => const [0, 0, 0],
          },
      ],
  ];

  static List<PoseFrame> decode(List<Object?> json) => [
    for (final raw in json)
      if (raw case final List<Object?> row
          when row.length == 1 + Joint.values.length * 3)
        PoseFrame(
          timestamp: Duration(milliseconds: (row[0]! as num).toInt()),
          points: {
            for (final (i, joint) in Joint.values.indexed)
              joint: PosePoint(
                x: (row[1 + i * 3]! as num).toDouble(),
                y: (row[2 + i * 3]! as num).toDouble(),
                confidence: (row[3 + i * 3]! as num).toDouble(),
              ),
          },
        ),
  ];

  static double _round(double value) => (value * 10000).round() / 10000;
}
