import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:movenet_domain/movenet_domain.dart';

part 'video_analysis_state.freezed.dart';

@freezed
abstract class VideoAnalysisState with _$VideoAnalysisState {
  const factory VideoAnalysisState({
    required List<AnalysisRecord> history,
    @Default(false) bool isAnalyzing,
    @Default(0) double progress,
    String? selectedPath,
    AnalysisRecord? latest,
  }) = _VideoAnalysisState;
}
