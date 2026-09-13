import 'exercise_type.dart';
import 'joint.dart';
import 'movement_analyzer.dart';
import 'pose_frame.dart';

class RepCounter {
  final Map<ExerciseType, int> _counts = {
    ExerciseType.pullUp: 0,
    ExerciseType.squat: 0,
    ExerciseType.pushUp: 0,
  };
  final Map<ExerciseType, bool> _loaded = {};

  int count(ExerciseType exercise) => _counts[exercise] ?? 0;

  void reset(ExerciseType exercise) {
    _counts[exercise] = 0;
    _loaded[exercise] = false;
  }

  void add(PoseFrame frame) {
    _transition(
      ExerciseType.pullUp,
      MovementAnalyzer.averageAngle(frame, const [
        (Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist),
        (Joint.rightShoulder, Joint.rightElbow, Joint.rightWrist),
      ]),
      loadedBelow: 105,
      resetAbove: 145,
    );
    _transition(
      ExerciseType.squat,
      MovementAnalyzer.averageAngle(frame, const [
        (Joint.leftHip, Joint.leftKnee, Joint.leftAnkle),
        (Joint.rightHip, Joint.rightKnee, Joint.rightAnkle),
      ]),
      loadedBelow: 110,
      resetAbove: 150,
      countOnReset: true,
    );
    _transition(
      ExerciseType.pushUp,
      MovementAnalyzer.averageAngle(frame, const [
        (Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist),
        (Joint.rightShoulder, Joint.rightElbow, Joint.rightWrist),
      ]),
      loadedBelow: 105,
      resetAbove: 150,
      countOnReset: true,
    );
  }

  void _transition(
    ExerciseType exercise,
    double? angle, {
    required double loadedBelow,
    required double resetAbove,
    bool countOnReset = false,
  }) {
    if (angle == null) return;
    final loaded = _loaded[exercise] ?? false;
    if (!loaded && angle < loadedBelow) {
      _loaded[exercise] = true;
      if (!countOnReset) _counts[exercise] = count(exercise) + 1;
    } else if (loaded && angle > resetAbove) {
      _loaded[exercise] = false;
      if (countOnReset) _counts[exercise] = count(exercise) + 1;
    }
  }
}
