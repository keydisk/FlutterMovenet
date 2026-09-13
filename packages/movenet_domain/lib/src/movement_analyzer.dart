import 'dart:math' as math;

import 'analysis_result.dart';
import 'coaching_tip.dart';
import 'exercise_type.dart';
import 'joint.dart';
import 'pose_frame.dart';
import 'pose_point.dart';
import 'rep_counter.dart';
import 'running_metrics.dart';

class MovementAnalyzer {
  const MovementAnalyzer();

  AnalysisResult analyze(List<PoseFrame> frames, Duration duration) {
    if (frames.isEmpty) {
      return AnalysisResult(
        exercise: ExerciseType.unknown,
        probabilities: const {ExerciseType.unknown: 1},
        repetitions: 0,
        coaching: const [
          CoachingTip(title: '전신 확인', message: '전신이 화면에 보이도록 촬영해 주세요.'),
        ],
        duration: duration,
      );
    }

    final totals = <ExerciseType, double>{};
    final counter = RepCounter();
    for (final frame in frames) {
      counter.add(frame);
      for (final entry in classify(frame).entries) {
        totals.update(
          entry.key,
          (value) => value + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }
    final probabilities = _normalize(totals);
    final exercise = probabilities.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return AnalysisResult(
      exercise: exercise,
      probabilities: probabilities,
      repetitions: counter.count(exercise),
      coaching: coachingFor(exercise, frames.last),
      duration: duration,
      riskEvents: _riskEvents(exercise, frames),
      runningMetrics:
          exercise == ExerciseType.running || exercise == ExerciseType.walking
          ? _runningMetrics(frames, duration)
          : null,
    );
  }

  Map<ExerciseType, double> classify(PoseFrame frame) {
    final shoulder = _midpoint(frame, Joint.leftShoulder, Joint.rightShoulder);
    final hip = _midpoint(frame, Joint.leftHip, Joint.rightHip);
    final wrist = _midpoint(frame, Joint.leftWrist, Joint.rightWrist);
    final ankle = _midpoint(frame, Joint.leftAnkle, Joint.rightAnkle);
    final elbowAngle = averageAngle(frame, const [
      (Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist),
      (Joint.rightShoulder, Joint.rightElbow, Joint.rightWrist),
    ]);
    final kneeAngle = averageAngle(frame, const [
      (Joint.leftHip, Joint.leftKnee, Joint.leftAnkle),
      (Joint.rightHip, Joint.rightKnee, Joint.rightAnkle),
    ]);
    final horizontalBody =
        shoulder != null && hip != null && (shoulder.y - hip.y).abs() < 0.22;
    final verticalBody =
        shoulder != null && hip != null && (shoulder.y - hip.y).abs() >= 0.18;
    final handsAboveShoulders =
        wrist != null && shoulder != null && wrist.y < shoulder.y - 0.04;
    final feetApart =
        ankle != null && hip != null && (ankle.x - hip.x).abs() > 0.04;

    return _normalize({
      ExerciseType.pullUp:
          0.08 +
          (handsAboveShoulders ? 0.72 : 0) +
          (elbowAngle < 125 ? 0.15 : 0),
      ExerciseType.squat:
          0.08 + (verticalBody ? 0.30 : 0) + (kneeAngle < 145 ? 0.52 : 0),
      ExerciseType.pushUp:
          0.08 + (horizontalBody ? 0.62 : 0) + (elbowAngle < 145 ? 0.25 : 0),
      ExerciseType.running:
          0.05 + (verticalBody && feetApart && kneeAngle < 155 ? 0.35 : 0),
      ExerciseType.walking: 0.08 + (verticalBody && feetApart ? 0.24 : 0),
    });
  }

  List<CoachingTip> coachingFor(ExerciseType exercise, PoseFrame frame) {
    final shoulderTilt = _tilt(frame, Joint.leftShoulder, Joint.rightShoulder);
    final hipTilt = _tilt(frame, Joint.leftHip, Joint.rightHip);
    final elbow = averageAngle(frame, const [
      (Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist),
      (Joint.rightShoulder, Joint.rightElbow, Joint.rightWrist),
    ]);
    final knee = averageAngle(frame, const [
      (Joint.leftHip, Joint.leftKnee, Joint.leftAnkle),
      (Joint.rightHip, Joint.rightKnee, Joint.rightAnkle),
    ]);
    return switch (exercise) {
      ExerciseType.pullUp => [
        CoachingTip(
          title: '어깨 균형',
          message: shoulderTilt > 0.06
              ? '한쪽 어깨가 먼저 올라갑니다. 양쪽 견갑을 함께 내려 주세요.'
              : '양쪽 어깨가 안정적으로 움직입니다.',
        ),
        CoachingTip(
          title: '팔 가동 범위',
          message: elbow > 145
              ? '아래에서 팔을 충분히 편 뒤 가슴을 바 쪽으로 당겨 주세요.'
              : '팔꿈치 굽힘 구간이 잘 포착됐습니다.',
        ),
      ],
      ExerciseType.squat => [
        CoachingTip(
          title: '무릎 깊이',
          message: knee > 125
              ? '엉덩이를 뒤로 보내며 무릎을 조금 더 굽혀 주세요.'
              : '충분한 스쿼트 깊이입니다.',
        ),
        CoachingTip(
          title: '골반 균형',
          message: hipTilt > 0.06
              ? '골반이 한쪽으로 기울지 않게 발바닥을 고르게 눌러 주세요.'
              : '골반 좌우 균형이 안정적입니다.',
        ),
      ],
      ExerciseType.pushUp => [
        CoachingTip(
          title: '팔꿈치',
          message: elbow > 125
              ? '가슴이 내려갈 때 팔꿈치를 충분히 굽혀 주세요.'
              : '팔꿈치 가동 범위가 좋습니다.',
        ),
        CoachingTip(
          title: '어깨·몸통 정렬',
          message: shoulderTilt > 0.06 || hipTilt > 0.07
              ? '양쪽 어깨를 맞추고 머리부터 발끝까지 한 줄을 유지해 주세요.'
              : '어깨와 몸통 정렬이 안정적입니다.',
        ),
      ],
      ExerciseType.running => const [
        CoachingTip(title: '착지', message: '발을 몸 중심 가까이에 부드럽게 착지해 주세요.'),
      ],
      ExerciseType.walking => const [
        CoachingTip(title: '보행 균형', message: '시선은 정면에 두고 좌우 보폭을 일정하게 유지해 주세요.'),
      ],
      ExerciseType.unknown => const [
        CoachingTip(title: '촬영 위치', message: '관절이 가려지지 않도록 전신을 화면에 담아 주세요.'),
      ],
    };
  }

  static double averageAngle(
    PoseFrame frame,
    List<(Joint, Joint, Joint)> joints,
  ) {
    final values = <double>[];
    for (final (start, center, end) in joints) {
      final a = frame.point(start);
      final b = frame.point(center);
      final c = frame.point(end);
      if (a != null && b != null && c != null) values.add(_angle(a, b, c));
    }
    return values.isEmpty
        ? 180
        : values.reduce((a, b) => a + b) / values.length;
  }

  static double _angle(PosePoint a, PosePoint b, PosePoint c) {
    final first = math.atan2(a.y - b.y, a.x - b.x);
    final second = math.atan2(c.y - b.y, c.x - b.x);
    var degrees = (first - second).abs() * 180 / math.pi;
    if (degrees > 180) degrees = 360 - degrees;
    return degrees;
  }

  static PosePoint? _midpoint(PoseFrame frame, Joint first, Joint second) {
    final a = frame.point(first);
    final b = frame.point(second);
    if (a == null || b == null) return null;
    return PosePoint(
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      confidence: math.min(a.confidence, b.confidence),
    );
  }

  static double _tilt(PoseFrame frame, Joint first, Joint second) {
    final a = frame.point(first);
    final b = frame.point(second);
    return a == null || b == null ? 0 : (a.y - b.y).abs();
  }

  int _riskEvents(ExerciseType exercise, List<PoseFrame> frames) {
    var count = 0;
    var active = false;
    for (final frame in frames) {
      final risky = switch (exercise) {
        ExerciseType.pullUp =>
          _tilt(frame, Joint.leftShoulder, Joint.rightShoulder) > 0.07 ||
              (_sideAngle(
                            frame,
                            Joint.leftShoulder,
                            Joint.leftElbow,
                            Joint.leftWrist,
                          ) -
                          _sideAngle(
                            frame,
                            Joint.rightShoulder,
                            Joint.rightElbow,
                            Joint.rightWrist,
                          ))
                      .abs() >
                  28,
        ExerciseType.squat =>
          averageAngle(frame, const [
                    (Joint.leftHip, Joint.leftKnee, Joint.leftAnkle),
                    (Joint.rightHip, Joint.rightKnee, Joint.rightAnkle),
                  ]) <
                  65 ||
              _tilt(frame, Joint.leftHip, Joint.rightHip) > 0.08,
        ExerciseType.pushUp =>
          _tilt(frame, Joint.leftShoulder, Joint.rightShoulder) > 0.07 ||
              _tilt(frame, Joint.leftHip, Joint.rightHip) > 0.08,
        _ => false,
      };
      if (risky && !active) count++;
      active = risky;
    }
    return count;
  }

  RunningMetrics _runningMetrics(List<PoseFrame> frames, Duration duration) {
    var steps = 0;
    var leftLoaded = false;
    var rightLoaded = false;
    final trunkAngles = <double>[];
    final kneeAngles = <double>[];
    final hipAngles = <double>[];
    for (final frame in frames) {
      final leftKnee = _sideAngle(
        frame,
        Joint.leftHip,
        Joint.leftKnee,
        Joint.leftAnkle,
      );
      final rightKnee = _sideAngle(
        frame,
        Joint.rightHip,
        Joint.rightKnee,
        Joint.rightAnkle,
      );
      if (!leftLoaded && leftKnee < 145) {
        leftLoaded = true;
        steps++;
      } else if (leftLoaded && leftKnee > 160) {
        leftLoaded = false;
      }
      if (!rightLoaded && rightKnee < 145) {
        rightLoaded = true;
        steps++;
      } else if (rightLoaded && rightKnee > 160) {
        rightLoaded = false;
      }
      kneeAngles.add(math.min(leftKnee, rightKnee));
      hipAngles.add(
        averageAngle(frame, const [
          (Joint.leftShoulder, Joint.leftHip, Joint.leftKnee),
          (Joint.rightShoulder, Joint.rightHip, Joint.rightKnee),
        ]),
      );
      final shoulder = _midpoint(
        frame,
        Joint.leftShoulder,
        Joint.rightShoulder,
      );
      final hip = _midpoint(frame, Joint.leftHip, Joint.rightHip);
      if (shoulder != null && hip != null) {
        trunkAngles.add(
          math.atan2((shoulder.x - hip.x).abs(), (shoulder.y - hip.y).abs()) *
              180 /
              math.pi,
        );
      }
    }
    final seconds = math.max(1, duration.inMilliseconds / 1000);
    final hipRange = hipAngles.isEmpty
        ? 0.0
        : hipAngles.reduce(math.max) - hipAngles.reduce(math.min);
    return RunningMetrics(
      cadence: steps * 60 / seconds,
      trunkLean: _average(trunkAngles),
      kneeAngle: _average(kneeAngles),
      hipMobility: hipRange,
    );
  }

  static double _sideAngle(
    PoseFrame frame,
    Joint start,
    Joint center,
    Joint end,
  ) => averageAngle(frame, [(start, center, end)]);

  static double _average(List<double> values) => values.isEmpty
      ? 0
      : values.reduce((first, second) => first + second) / values.length;

  static Map<ExerciseType, double> _normalize(
    Map<ExerciseType, double> scores,
  ) {
    final total = scores.values.fold<double>(0, (sum, value) => sum + value);
    return scores.map(
      (key, value) => MapEntry(key, total == 0 ? 0 : value / total),
    );
  }
}
