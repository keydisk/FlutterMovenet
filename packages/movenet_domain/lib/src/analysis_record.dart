import 'analysis_result.dart';
import 'coaching_tip.dart';
import 'exercise_classifier.dart';
import 'exercise_type.dart';
import 'risk_event.dart';
import 'running_metrics.dart';

class AnalysisRecord {
  const AnalysisRecord({
    required this.id,
    required this.videoPath,
    required this.createdAt,
    required this.result,
    this.thumbnailPath,
  });

  factory AnalysisRecord.fromJson(Map<String, Object?> json) {
    final exercise = ExerciseType.values.byName(json['exercise']! as String);
    final rawProbabilities = json['probabilities']! as Map<String, Object?>;
    return AnalysisRecord(
      id: json['id']! as String,
      videoPath: json['videoPath']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      thumbnailPath: json['thumbnailPath'] as String?,
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
        risks: [
          for (final item in json['risks'] as List<Object?>? ?? const [])
            RiskEvent.fromJson((item! as Map).cast<String, Object?>()),
        ],
        analyzedFrames: json['analyzedFrames'] as int? ?? 0,
        depthDegrees: (json['depthDegrees'] as num?)?.toDouble(),
        locomotionSummary: json['locomotionSummary'] as String?,
        candidates: [
          for (final item in json['candidates'] as List<Object?>? ?? const [])
            ExerciseCandidate.fromJson((item! as Map).cast<String, Object?>()),
        ],
        modelConfidence: (json['modelConfidence'] as num?)?.toDouble(),
        runningMetrics: json['runningMetrics'] == null
            ? null
            : RunningMetrics.fromJson(
                (json['runningMetrics']! as Map).cast<String, Object?>(),
              ),
      ),
    );
  }

  final String id;
  final String videoPath;
  final DateTime createdAt;

  /// iOS 앱 makeVideoTitle과 동일하게 촬영 시각으로 제목을 만든다(앨범 임시 파일명은 쓰지 않는다).
  String get title =>
      '${createdAt.month}월 ${createdAt.day}일 '
      '${createdAt.hour.toString().padLeft(2, '0')}:'
      '${createdAt.minute.toString().padLeft(2, '0')} 영상';

  /// 히스토리 카드에 보여줄 섬네일 이미지 경로.
  final String? thumbnailPath;
  final AnalysisResult result;

  Map<String, Object> toJson() => {
    'id': id,
    'videoPath': videoPath,
    'createdAt': createdAt.toIso8601String(),
    'thumbnailPath': ?thumbnailPath,
    'exercise': result.exercise.name,
    'probabilities': result.probabilities.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'repetitions': result.repetitions,
    'coaching': result.coaching.map((tip) => tip.toJson()).toList(),
    'durationMs': result.duration.inMilliseconds,
    'riskEvents': result.riskEvents,
    'risks': result.risks.map((risk) => risk.toJson()).toList(),
    'analyzedFrames': result.analyzedFrames,
    'depthDegrees': ?result.depthDegrees,
    'locomotionSummary': ?result.locomotionSummary,
    'candidates': result.candidates.map((c) => c.toJson()).toList(),
    'modelConfidence': ?result.modelConfidence,
    if (result.runningMetrics case final metrics?)
      'runningMetrics': metrics.toJson(),
  };
}
