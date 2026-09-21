import 'dart:math' as math;

import 'package:movenet_domain/movenet_domain.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = FormAnalyzer();

  test('cadence counts hip oscillation peaks per minute', () {
    // 3Hz 상하 진동 = 180 spm, 15fps 샘플
    final times = [for (var i = 0; i < 90; i++) i / 15];
    final hipY = [
      for (final t in times) 0.5 + 0.03 * math.sin(2 * math.pi * 3 * t),
    ];
    expect(FormAnalyzer.cadence(hipY, times), closeTo(180, 15));
  });

  test('detects squat reps from knee flexion cycles', () {
    final frames = <PoseFrame>[];
    for (var rep = 0; rep < 3; rep++) {
      for (var i = 0; i < 30; i++) {
        // 175° → 85° → 175°
        final knee = 130 + 45 * math.cos(2 * math.pi * i / 30);
        frames.add(_standingFrame(knee, (rep * 30 + i) / 15));
      }
    }
    final result = analyzer.analyze(
      frames,
      duration: const Duration(seconds: 6),
    );
    expect(result.exercise, ExerciseType.squat);
    expect(result.repetitions, 3);
    expect(result.depthDegrees, closeTo(85, 2));
  });

  test('model classification overrides pose heuristics', () {
    final frames = [
      for (var i = 0; i < 90; i++)
        _standingFrame(130 + 45 * math.cos(2 * math.pi * i / 30), i / 15),
    ];
    final result = analyzer.analyze(
      frames,
      duration: const Duration(seconds: 6),
      classification: const ExerciseClassification(
        prediction: ExerciseType.walking,
        confidence: 0.8,
      ),
    );
    expect(result.exercise, ExerciseType.walking);
    expect(result.modelConfidence, 0.8);
  });

  test('ambiguous classification reports candidates only', () {
    final frames = [for (var i = 0; i < 30; i++) _standingFrame(175, i / 15)];
    final result = analyzer.analyze(
      frames,
      duration: const Duration(seconds: 2),
      classification: const ExerciseClassification(
        candidates: [ExerciseCandidate(id: 'lunge', confidence: 0.6)],
      ),
    );
    expect(result.exercise, ExerciseType.unknown);
    expect(result.candidates.single.id, 'lunge');
  });

  test('few frames are reported as unknown', () {
    final frames = [for (var i = 0; i < 5; i++) _standingFrame(175, i / 15)];
    final result = analyzer.analyze(
      frames,
      duration: const Duration(seconds: 1),
    );
    expect(result.exercise, ExerciseType.unknown);
  });

  test('risk events respect per-joint cooldown', () {
    final frames = [for (var i = 0; i < 30; i++) _standingFrame(100, i / 15)];
    final detector = RiskDetector();
    for (final frame in frames) {
      detector.add(frame);
    }
    final risks = detector.events;
    // 2초 동안 좌/우 무릎 과굴곡: 쿨다운 1초 → 관절별 2건
    expect(risks.where((r) => r.joint == RiskJoint.leftKnee), hasLength(2));
  });
}

PoseFrame _standingFrame(double kneeDegrees, double seconds) {
  final radians = kneeDegrees * math.pi / 180;
  const knee = (0.5, 0.65);
  final hip = (
    knee.$1 + 0.15 * math.sin(radians),
    knee.$2 + 0.15 * math.cos(radians),
  );
  final shoulder = (hip.$1, hip.$2 - 0.25);
  PosePoint p((double, double) v) => PosePoint(x: v.$1, y: v.$2, confidence: 1);
  return PoseFrame(
    timestamp: Duration(microseconds: (seconds * 1e6).round()),
    points: {
      Joint.leftShoulder: p(shoulder),
      Joint.rightShoulder: p(shoulder),
      Joint.leftElbow: p((shoulder.$1, shoulder.$2 + 0.12)),
      Joint.rightElbow: p((shoulder.$1, shoulder.$2 + 0.12)),
      Joint.leftWrist: p((shoulder.$1 + 0.1, shoulder.$2 + 0.2)),
      Joint.rightWrist: p((shoulder.$1 + 0.1, shoulder.$2 + 0.2)),
      Joint.leftHip: p(hip),
      Joint.rightHip: p(hip),
      Joint.leftKnee: p(knee),
      Joint.rightKnee: p(knee),
      Joint.leftAnkle: p((0.5, 0.8)),
      Joint.rightAnkle: p((0.5, 0.8)),
    },
  );
}
