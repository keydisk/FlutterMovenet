import 'package:feature_camera/src/camera_analysis_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movenet_domain/movenet_domain.dart';

void main() {
  test('camera state keeps the cumulative repetition count', () {
    const state = CameraAnalysisState(
      exercise: ExerciseType.pullUp,
      probabilities: {ExerciseType.pullUp: 0.9},
      repetitions: 4,
      coaching: [],
      showSkeleton: true,
      showFps: true,
      minimumConfidence: 0.35,
    );
    expect(state.repetitions, 4);
  });
}
