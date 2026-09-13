import 'joint.dart';
import 'pose_point.dart';

class PoseFrame {
  const PoseFrame({required this.points, required this.timestamp});

  final Map<Joint, PosePoint> points;
  final Duration timestamp;

  PosePoint? point(Joint joint, [double minimumConfidence = 0.35]) {
    final value = points[joint];
    return value != null && value.confidence >= minimumConfidence
        ? value
        : null;
  }
}
