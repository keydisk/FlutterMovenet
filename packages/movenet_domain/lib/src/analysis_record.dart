import 'analysis_result.dart';
import 'coaching_tip.dart';
import 'exercise_type.dart';
import 'running_metrics.dart';

class AnalysisRecord {
  const AnalysisRecord({
    required this.id,
    required this.fileName,
    required this.videoPath,
    required this.createdAt,
    required this.result,
  });

  factory AnalysisRecord.fromJson(Map<String, Object?> json) {
    final exercise = ExerciseType.values.byName(json['exercise']! as String);
    final rawProbabilities = json['probabilities']! as Map<String, Object?>;
    return AnalysisRecord(
      id: json['id']! as String,
      fileName: json['fileName']! as String,
      videoPath: json['videoPath']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      result: AnalysisResult(
        exercise: exercise,
        probabilities: rawProbabilities.map(
          (key, value) => MapEntry(
            ExerciseType.values.byName(key),
            (value as num).toDouble(),
          ),
        ),
        repetitions: json['repetitions']! as int,
        coaching: (json['coaching']! as List<Object?>)
            .map(
              (item) =>
                  CoachingTip.fromJson((item! as Map).cast<String, Object?>()),
            )
            .toList(),
        duration: Duration(milliseconds: json['durationMs']! as int),
        riskEvents: json['riskEvents'] as int? ?? 0,
        runningMetrics: json['runningMetrics'] == null
            ? null
            : RunningMetrics.fromJson(
                (json['runningMetrics']! as Map).cast<String, Object?>(),
              ),
      ),
    );
  }

  final String id;
  final String fileName;
  final String videoPath;
  final DateTime createdAt;
  final AnalysisResult result;

  Map<String, Object> toJson() => {
    'id': id,
    'fileName': fileName,
    'videoPath': videoPath,
    'createdAt': createdAt.toIso8601String(),
    'exercise': result.exercise.name,
    'probabilities': result.probabilities.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'repetitions': result.repetitions,
    'coaching': result.coaching.map((tip) => tip.toJson()).toList(),
    'durationMs': result.duration.inMilliseconds,
    'riskEvents': result.riskEvents,
    if (result.runningMetrics case final metrics?)
      'runningMetrics': metrics.toJson(),
  };
}
