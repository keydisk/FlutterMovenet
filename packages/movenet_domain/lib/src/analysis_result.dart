import 'coaching_tip.dart';
import 'exercise_type.dart';
import 'running_metrics.dart';

class AnalysisResult {
  const AnalysisResult({
    required this.exercise,
    required this.probabilities,
    required this.repetitions,
    required this.coaching,
    required this.duration,
    this.riskEvents = 0,
    this.runningMetrics,
  });

  final ExerciseType exercise;
  final Map<ExerciseType, double> probabilities;
  final int repetitions;
  final List<CoachingTip> coaching;
  final Duration duration;
  final int riskEvents;
  final RunningMetrics? runningMetrics;

  bool get isCertain {
    final scores = probabilities.values.toList()
      ..sort((a, b) => b.compareTo(a));
    return scores.isNotEmpty &&
        scores.first >= 0.70 &&
        (scores.length == 1 || scores.first - scores[1] >= 0.20);
  }
}
