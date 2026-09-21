import 'dart:math' as math;

import 'pose_frame.dart';
import 'risk_event.dart';

/// 프레임을 하나씩 넣어 위험 각도를 감지한다(iOS VideoAnalysisPreprocessor.detectRisks와 동일).
/// 관절별 1초 쿨다운, 상·하체 각각 최대 5건, 전체 최대 5건.
class RiskDetector {
  RiskDetector({this.minConfidence = 0.3});

  final double minConfidence;

  static const _maxSnapshots = 5;
  static const _cooldownSeconds = 1.0;

  final List<RiskEvent> events = [];
  final Map<RiskJoint, double> _lastCapture = {};

  /// 이 프레임에서 새로 감지된 위험. 없으면 빈 목록.
  List<RiskEvent> add(PoseFrame frame) {
    if (events.length >= _maxSnapshots) return const [];
    final time =
        frame.timestamp.inMicroseconds / Duration.microsecondsPerSecond;
    final detected = <RiskEvent>[];
    for (final joint in RiskJoint.values) {
      final degrees = _angle(frame, joint);
      if (degrees == null) continue;
      final upper = joint.isUpperBody;
      if (events.where((e) => e.joint.isUpperBody == upper).length >=
          _maxSnapshots) {
        continue;
      }
      final rounded = degrees.round();
      String? description;
      var critical = false;
      switch (joint) {
        case RiskJoint.leftElbow || RiskJoint.rightElbow:
          if (degrees >= 178) {
            critical = degrees >= 183;
            description = '${joint.label} 과신전($rounded°) - 인대 및 관절 부하 위험';
          }
        case RiskJoint.leftKnee || RiskJoint.rightKnee:
          if (degrees >= 178) {
            critical = degrees >= 183;
            description = '${joint.label} 과신전($rounded°) - 인대 및 관절 부하 위험';
          } else if (degrees < 115) {
            description = '${joint.label} 과도한 굴곡($rounded°) - 관절 압박 주의';
          }
        case RiskJoint.leftHip || RiskJoint.rightHip:
          if (degrees < 110) {
            description = '${joint.label} 과도한 굴곡($rounded°) - 골반 가동성 확인 필요';
          }
        case RiskJoint.leftShoulder || RiskJoint.rightShoulder:
          break;
      }
      if (description == null) continue;
      final last = _lastCapture[joint];
      if (last != null && time - last < _cooldownSeconds) continue;
      _lastCapture[joint] = time;
      final event = RiskEvent(
        timestamp: frame.timestamp,
        joint: joint,
        degrees: degrees,
        description: description,
        critical: critical,
      );
      events.add(event);
      detected.add(event);
    }
    return detected;
  }

  /// 감지된 위험의 이미지 경로를 채워 넣는다.
  void attachImage(RiskEvent event, String? path) {
    final index = events.indexOf(event);
    if (index >= 0 && path != null) events[index] = event.withImage(path);
  }

  /// 종횡비 보정 없는 관절 각도(iOS CalculateJointAnglesUseCase와 동일).
  double? _angle(PoseFrame frame, RiskJoint joint) {
    final a = frame.point(joint.joints.$1, minConfidence);
    final b = frame.point(joint.joints.$2, minConfidence);
    final c = frame.point(joint.joints.$3, minConfidence);
    if (a == null || b == null || c == null) return null;
    final ux = a.x - b.x, uy = a.y - b.y;
    final vx = c.x - b.x, vy = c.y - b.y;
    final magU = math.sqrt(ux * ux + uy * uy);
    final magV = math.sqrt(vx * vx + vy * vy);
    if (magU <= 0.0001 || magV <= 0.0001) return null;
    final cos = ((ux * vx + uy * vy) / (magU * magV)).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }
}
