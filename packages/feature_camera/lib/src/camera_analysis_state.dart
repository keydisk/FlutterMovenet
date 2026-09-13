import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:movenet_domain/movenet_domain.dart';

part 'camera_analysis_state.freezed.dart';

@freezed
abstract class CameraAnalysisState with _$CameraAnalysisState {
  const factory CameraAnalysisState({
    required ExerciseType exercise,
    required Map<ExerciseType, double> probabilities,
    required int repetitions,
    required List<CoachingTip> coaching,
    required bool showSkeleton,
    required bool showFps,
    required double minimumConfidence,
    PoseFrame? pose,
    @Default(0) double fps,
  }) = _CameraAnalysisState;
}
