import 'package:feature_video/src/pose_track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movenet_data/movenet_data.dart';
import 'package:movenet_domain/movenet_domain.dart';

PoseFrame _frame(int ms, {double kneeX = 0.5}) => PoseFrame(
  timestamp: Duration(milliseconds: ms),
  points: {
    for (final joint in Joint.values)
      joint: const PosePoint(x: 0.4, y: 0.5, confidence: 0.9),
    Joint.leftHip: const PosePoint(x: 0.5, y: 0.4, confidence: 0.9),
    Joint.leftKnee: PosePoint(x: kneeX, y: 0.6, confidence: 0.9),
    Joint.leftAnkle: const PosePoint(x: 0.5, y: 0.8, confidence: 0.9),
  },
);

void main() {
  group('PoseTrack.sample', () {
    final track = PoseTrack([_frame(0, kneeX: 0.4), _frame(66, kneeX: 0.6)]);

    test('두 샘플 사이는 선형 보간한다', () {
      final pose = track.sample(const Duration(milliseconds: 33))!;
      expect(pose.points[Joint.leftKnee]!.x, closeTo(0.5, 0.01));
    });

    test('샘플에서 멀리 떨어진 시각은 포즈가 없다', () {
      expect(track.sample(const Duration(seconds: 2)), isNull);
    });

    test('간격이 큰(사람 미검출) 구간은 보간하지 않는다', () {
      final gappy = PoseTrack([_frame(0), _frame(1000)]);
      expect(gappy.sample(const Duration(milliseconds: 500)), isNull);
      expect(gappy.sample(const Duration(milliseconds: 950)), isNotNull);
    });
  });

  test('저장 형식은 왕복 변환해도 같은 포즈를 돌려준다', () {
    final frames = [_frame(0), _frame(66, kneeX: 0.61234)];
    final decoded = PoseTrackStorage.decode(PoseTrackStorage.encode(frames));
    expect(decoded, hasLength(2));
    expect(decoded[1].timestamp, const Duration(milliseconds: 66));
    expect(decoded[1].points[Joint.leftKnee]!.x, closeTo(0.6123, 1e-4));
  });

  test('각도는 화면 비율을 반영한다', () {
    const points = {
      Joint.leftHip: Offset(0.5, 0.4),
      Joint.leftKnee: Offset(0.5, 0.6),
      Joint.leftAnkle: Offset(0.6, 0.6),
    };
    // 가로 1 : 세로 1 → 직각, 세로 영상(0.5)에서는 가로가 짧아 보이지만 여전히 직각.
    expect(jointAngle(points, RiskJoint.leftKnee, 1), closeTo(90, 0.01));
    expect(jointAngle(points, RiskJoint.leftKnee, 0.5), closeTo(90, 0.01));
  });

  group('PoseSmoother', () {
    test('각도 숫자는 0.3초마다만 바뀐다', () {
      final smoother = PoseSmoother(minConfidence: 0.3);
      smoother.update(_frame(0, kneeX: 0.5), Duration.zero, 1);
      final first = smoother.angles[RiskJoint.leftKnee];
      // 무릎을 크게 굽혀도 0.3초 전에는 표시값이 그대로다.
      for (var ms = 16; ms < 280; ms += 16) {
        smoother.update(_frame(ms, kneeX: 0.3), Duration(milliseconds: ms), 1);
        expect(smoother.angles[RiskJoint.leftKnee], first);
      }
      smoother.update(
        _frame(320, kneeX: 0.3),
        const Duration(milliseconds: 320),
        1,
      );
      expect(smoother.angles[RiskJoint.leftKnee], isNot(first));
    });

    test('경고는 조건이 사라져도 2초간 유지된다', () {
      final smoother = PoseSmoother(minConfidence: 0.3);
      // 무릎이 크게 굽은 자세(<115°)로 경고를 띄운다.
      final bent = PoseFrame(
        timestamp: Duration.zero,
        points: {
          Joint.leftHip: const PosePoint(x: 0.5, y: 0.4, confidence: 0.9),
          Joint.leftKnee: const PosePoint(x: 0.5, y: 0.6, confidence: 0.9),
          Joint.leftAnkle: const PosePoint(x: 0.7, y: 0.6, confidence: 0.9),
        },
      );
      smoother.update(bent, Duration.zero, 1);
      expect(smoother.warning?.joint, RiskJoint.leftKnee);

      final straight = PoseFrame(
        timestamp: Duration.zero,
        points: {
          Joint.leftHip: const PosePoint(x: 0.5, y: 0.4, confidence: 0.9),
          Joint.leftKnee: const PosePoint(x: 0.51, y: 0.6, confidence: 0.9),
          Joint.leftAnkle: const PosePoint(x: 0.5, y: 0.8, confidence: 0.9),
        },
      );
      for (var ms = 16; ms <= 3000; ms += 16) {
        smoother.update(straight, Duration(milliseconds: ms), 1);
        if (ms < 1900) expect(smoother.warning, isNotNull, reason: '$ms ms');
      }
      expect(smoother.warning, isNull);
    });
  });
}
