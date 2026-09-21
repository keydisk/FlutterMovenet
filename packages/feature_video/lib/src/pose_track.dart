import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movenet_data/movenet_data.dart';
import 'package:movenet_domain/movenet_domain.dart';

/// 영상의 분석 포즈 트랙. 예전 기록처럼 트랙이 없으면 null.
final poseTrackProvider = FutureProvider.autoDispose.family<PoseTrack?, String>(
  (ref, videoPath) async {
    final frames = await const PoseTrackStorage().load(videoPath);
    if (frames == null || frames.isEmpty) return null;
    final settings = await SettingsStorage().load();
    return PoseTrack(frames, minConfidence: settings.minimumConfidence);
  },
);

/// 15fps로 샘플된 포즈를 재생 시각에 맞춰 보간해 꺼낸다.
class PoseTrack {
  PoseTrack(this.frames, {this.minConfidence = 0.35});

  final List<PoseFrame> frames;
  final double minConfidence;

  /// 이 간격보다 멀리 떨어진 샘플 사이는 보간하지 않는다(사람 미검출 구간).
  static const _maxGap = Duration(milliseconds: 250);

  /// [time]의 포즈. 가까운 샘플이 없으면 null.
  PoseFrame? sample(Duration time) {
    if (frames.isEmpty) return null;
    // time 이후 첫 샘플 위치(이진 탐색).
    var low = 0, high = frames.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (frames[mid].timestamp < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final after = low < frames.length ? frames[low] : null;
    final before = low > 0 ? frames[low - 1] : null;
    if (before == null || after == null) {
      final only = (before ?? after)!;
      return (only.timestamp - time).abs() <= _maxGap ~/ 2 ? only : null;
    }
    final span = after.timestamp - before.timestamp;
    if (span > _maxGap) {
      final nearest = time - before.timestamp < after.timestamp - time
          ? before
          : after;
      return (nearest.timestamp - time).abs() <= _maxGap ~/ 2 ? nearest : null;
    }
    final t = span == Duration.zero
        ? 0.0
        : (time - before.timestamp).inMicroseconds / span.inMicroseconds;
    return PoseFrame(
      timestamp: time,
      points: {
        for (final joint in Joint.values)
          if ((before.points[joint], after.points[joint]) case (
            final a?,
            final b?,
          ))
            joint: PosePoint(
              x: lerpDouble(a.x, b.x, t)!,
              y: lerpDouble(a.y, b.y, t)!,
              confidence: math.min(a.confidence, b.confidence),
            ),
      },
    );
  }
}

/// 화면에서 눈으로 따라갈 수 있게 관절 위치와 각도를 부드럽게 만든다.
/// - 위치: 짧은 시간상수(약 0.08초)의 지수 평활로 MoveNet 떨림만 걷어낸다.
/// - 각도 숫자: 더 긴 시간상수로 평활하고, 표시값은 [_textInterval]마다만 바꿔 숫자가 깜빡이지 않게 한다.
/// - 경고: 한 번 뜨면 최소 [_warningHold] 동안 유지한다.
class PoseSmoother {
  PoseSmoother({required this.minConfidence});

  final double minConfidence;

  static const _positionTau = 0.08;
  static const _angleTau = 0.25;
  static const _textInterval = Duration(milliseconds: 300);
  static const _warningHold = Duration(milliseconds: 2000);

  final Map<Joint, Offset> _points = {};
  final Map<RiskJoint, double> _angles = {};
  final Map<RiskJoint, int> _shown = {};
  Duration? _lastTime;
  Duration _lastTextUpdate = Duration.zero;
  JointStatus? _warning;
  Duration _warningAt = Duration.zero;

  /// 평활된 관절 위치(0~1 정규화).
  Map<Joint, Offset> get points => _points;

  /// 표시용 각도(정수, 텍스트 갱신 주기마다 바뀜).
  Map<RiskJoint, int> get angles => _shown;

  /// 최근 경고(유지 시간 동안 남아 있음).
  JointStatus? get warning => _warning;

  void reset() {
    _points.clear();
    _angles.clear();
    _shown.clear();
    _lastTime = null;
    _warning = null;
  }

  /// 재생 시각 [time]의 포즈를 반영한다. [aspect]는 영상 가로/세로 비.
  void update(PoseFrame? pose, Duration time, double aspect) {
    final last = _lastTime;
    // 탐색(seek)이나 되감기로 크게 건너뛰면 이전 값을 끌고 오지 않는다.
    if (last != null &&
        (time < last || time - last > const Duration(milliseconds: 500))) {
      reset();
    }
    final dt = last == null ? 0.0 : (time - last).inMicroseconds / 1e6;
    _lastTime = time;
    if (pose == null) {
      _points.clear();
      _angles.clear();
      _shown.clear();
      return;
    }

    final positionAlpha = _alpha(dt, _positionTau);
    final visible = <Joint>{};
    for (final joint in Joint.values) {
      final point = pose.point(joint, minConfidence);
      if (point == null) continue;
      visible.add(joint);
      final target = Offset(point.x, point.y);
      final previous = _points[joint];
      _points[joint] = previous == null
          ? target
          : Offset.lerp(previous, target, positionAlpha)!;
    }
    _points.removeWhere((joint, _) => !visible.contains(joint));

    final angleAlpha = _alpha(dt, _angleTau);
    for (final joint in RiskJoint.values) {
      final degrees = jointAngle(_points, joint, aspect);
      if (degrees == null) {
        _angles.remove(joint);
        continue;
      }
      final previous = _angles[joint];
      _angles[joint] = previous == null
          ? degrees
          : previous + (degrees - previous) * angleAlpha;
    }

    final refreshText =
        _shown.length != _angles.length ||
        time - _lastTextUpdate >= _textInterval ||
        time < _lastTextUpdate;
    if (refreshText) {
      _lastTextUpdate = time;
      _shown
        ..clear()
        ..addAll(_angles.map((joint, value) => MapEntry(joint, value.round())));
      final current = _worstStatus();
      if (current != null) {
        _warning = current;
        _warningAt = time;
      } else if (time - _warningAt > _warningHold) {
        _warning = null;
      }
    }
  }

  JointStatus? _worstStatus() {
    JointStatus? worst;
    for (final MapEntry(key: joint, value: degrees) in _shown.entries) {
      final status = JointStatus.of(joint, degrees.toDouble());
      if (status.level.index > (worst?.level.index ?? 0)) worst = status;
    }
    return worst;
  }

  static double _alpha(double dt, double tau) =>
      dt <= 0 ? 1 : 1 - math.exp(-dt / tau);
}

/// 정점 관절의 안쪽 각도(도, 180°=완전히 폄). 화면 비율을 반영해 보이는 그대로의 각도를 구한다.
double? jointAngle(Map<Joint, Offset> points, RiskJoint joint, double aspect) {
  final (a, b, c) = joint.joints;
  final pa = points[a], pb = points[b], pc = points[c];
  if (pa == null || pb == null || pc == null) return null;
  final u = Offset((pa.dx - pb.dx) * aspect, pa.dy - pb.dy);
  final v = Offset((pc.dx - pb.dx) * aspect, pc.dy - pb.dy);
  if (u.distance < 1e-4 || v.distance < 1e-4) return null;
  final cos = ((u.dx * v.dx + u.dy * v.dy) / (u.distance * v.distance)).clamp(
    -1.0,
    1.0,
  );
  return math.acos(cos) * 180 / math.pi;
}

enum StatusLevel { normal, caution }

/// 위험 각도 판정(RiskDetector와 같은 임계값).
class JointStatus {
  const JointStatus(this.joint, this.degrees, this.level, this.message);

  factory JointStatus.of(RiskJoint joint, double degrees) {
    final rounded = degrees.round();
    final message = switch (joint) {
      RiskJoint.leftElbow ||
      RiskJoint.rightElbow when degrees >= 178 => '과신전 $rounded° · 관절 부하 주의',
      RiskJoint.leftKnee ||
      RiskJoint.rightKnee when degrees >= 178 => '과신전 $rounded° · 인대 부하 주의',
      RiskJoint.leftKnee ||
      RiskJoint.rightKnee when degrees < 115 => '과도한 굴곡 $rounded° · 관절 압박 주의',
      RiskJoint.leftHip ||
      RiskJoint.rightHip when degrees < 110 => '과도한 굴곡 $rounded° · 골반 가동성 확인',
      _ => null,
    };
    return JointStatus(
      joint,
      degrees,
      message == null ? StatusLevel.normal : StatusLevel.caution,
      message,
    );
  }

  final RiskJoint joint;
  final double degrees;
  final StatusLevel level;
  final String? message;
}
