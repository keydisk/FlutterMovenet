import 'coaching_tip.dart';
import 'exercise_classifier.dart';
import 'exercise_type.dart';
import 'risk_event.dart';
import 'running_metrics.dart';

class AnalysisResult {
  const AnalysisResult({
    required this.exercise,
    required this.probabilities,
    required this.repetitions,
    required this.coaching,
    required this.duration,
    this.riskEvents = 0,
    this.risks = const [],
    this.runningMetrics,
    this.analyzedFrames = 0,
    this.depthDegrees,
    this.locomotionSummary,
    this.candidates = const [],
    this.modelConfidence,
  });

  final ExerciseType exercise;
  final Map<ExerciseType, double> probabilities;
  final int repetitions;
  final List<CoachingTip> coaching;
  final Duration duration;
  final int riskEvents;
  final List<RiskEvent> risks;
  final RunningMetrics? runningMetrics;

  /// 분석에 사용된 유효 프레임 수.
  final int analyzedFrames;

  /// 최저 관절각(스쿼트=무릎, 풀업/푸시업=팔꿈치).
  final double? depthDegrees;

  /// 케이던스 티어 요약(예: "걷기 + 러닝").
  final String? locomotionSummary;

  /// MoViNet 판정이 애매할 때의 운동 후보(확률 내림차순).
  final List<ExerciseCandidate> candidates;

  /// MoViNet이 운동 종류를 확정했을 때의 신뢰도. 자세 규칙으로 판별했으면 null.
  final double? modelConfidence;

  bool get isCertain {
    final scores = probabilities.values.toList()
      ..sort((a, b) => b.compareTo(a));
    return scores.isNotEmpty &&
        scores.first >= 0.70 &&
        (scores.length == 1 || scores.first - scores[1] >= 0.20);
  }
}
