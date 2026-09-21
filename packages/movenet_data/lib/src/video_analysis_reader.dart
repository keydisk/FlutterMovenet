import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:movenet_domain/movenet_domain.dart';

/// 샘플 프레임 한 장의 시각과 MoveNet 포즈(사람 미검출이면 null).
class SampledPose {
  const SampledPose({required this.timestamp, this.pose, this.thumbnailPath});

  final Duration timestamp;
  final PoseFrame? pose;

  /// 사람이 처음 잡힌 프레임에서 저장한 섬네일 경로(그 외에는 null).
  final String? thumbnailPath;
}

/// 영상을 처음부터 순차 디코드(목표 fps)하면서 네이티브에서 MoveNet MultiPose로 포즈를 추정하고,
/// 모아 둔 클립으로 MoViNet(Kinetics-600) 로짓을 계산한다.
/// iOS는 CoreML(.mlpackage), Android는 TFLite(MoveNet)·ONNX Runtime(MoViNet)을 쓴다.
class VideoAnalysisReader {
  VideoAnalysisReader._(
    this._id, {
    required this.duration,
    required this.estimatedFrameCount,
    required this.width,
    required this.height,
  });

  static const _channel = MethodChannel('movenet/video_analysis');

  static Future<VideoAnalysisReader> open(
    String videoPath, {
    double fps = 15,
  }) async {
    final info = (await _channel.invokeMapMethod<String, Object?>('open', {
      'path': videoPath,
      'fps': fps,
    }))!;
    return VideoAnalysisReader._(
      info['id']! as int,
      duration: Duration(microseconds: info['durationUs']! as int),
      estimatedFrameCount: info['estimatedFrameCount']! as int,
      width: (info['width']! as num).toDouble(),
      height: (info['height']! as num).toDouble(),
    );
  }

  final int _id;

  final Duration duration;

  /// 진행률 계산용 총 프레임 추정치.
  final int estimatedFrameCount;

  /// 표시 방향 기준 영상 크기.
  final double width;
  final double height;

  double get aspectRatio => height > 0 ? width / height : 16 / 9;

  /// 다음 샘플 프레임. 끝이면 null.
  Future<SampledPose?> next() async {
    final frame = await _channel.invokeMapMethod<String, Object?>('next', {
      'id': _id,
    });
    if (frame == null) return null;
    final timestamp = Duration(microseconds: frame['timeUs']! as int);
    final keypoints = frame['keypoints'] as Float32List?;
    return SampledPose(
      timestamp: timestamp,
      pose: keypoints == null ? null : _poseFrame(keypoints, timestamp),
      thumbnailPath: frame['thumbnailPath'] as String?,
    );
  }

  /// 마지막으로 읽은 프레임을 JPEG로 저장하고 경로를 돌려준다(위험 각도 스냅샷).
  Future<String?> snapshot() =>
      _channel.invokeMethod<String>('snapshot', {'id': _id});

  /// 수집한 클립의 MoViNet 로짓(600). 모델이 없거나 클립이 비면 null.
  Future<List<double>?> classify() =>
      _channel.invokeListMethod<double>('classify', {'id': _id});

  Future<void> close() => _channel.invokeMethod<void>('close', {'id': _id});

  static PoseFrame _poseFrame(Float32List keypoints, Duration timestamp) =>
      PoseFrame(
        timestamp: timestamp,
        points: {
          for (final MapEntry(key: joint, value: index)
              in _moveNetIndex.entries)
            joint: PosePoint(
              x: keypoints[index * 3].clamp(0, 1).toDouble(),
              y: keypoints[index * 3 + 1].clamp(0, 1).toDouble(),
              confidence: keypoints[index * 3 + 2],
            ),
        },
      );

  /// MoveNet(COCO 17) 키포인트 인덱스.
  static const _moveNetIndex = {
    Joint.nose: 0,
    Joint.leftShoulder: 5,
    Joint.rightShoulder: 6,
    Joint.leftElbow: 7,
    Joint.rightElbow: 8,
    Joint.leftWrist: 9,
    Joint.rightWrist: 10,
    Joint.leftHip: 11,
    Joint.rightHip: 12,
    Joint.leftKnee: 13,
    Joint.rightKnee: 14,
    Joint.leftAnkle: 15,
    Joint.rightAnkle: 16,
  };
}

/// MoViNet 출력 인덱스 순서의 Kinetics-600 라벨.
class KineticsLabels {
  static List<String>? _cache;

  static Future<List<String>> load() async {
    if (_cache case final labels?) return labels;
    final json =
        jsonDecode(
              await rootBundle.loadString(
                'packages/movenet_data/assets/kinetics_600_labels.json',
              ),
            )
            as Map<String, Object?>;
    final entries = json.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    return _cache = [for (final entry in entries) entry.value! as String];
  }
}
