import 'dart:math' as math;

import 'package:movenet_domain/movenet_domain.dart';
import 'package:test/test.dart';

void main() {
  test('counts every pull-up contraction in the full sequence', () {
    final counter = RepCounter();
    for (var repetition = 0; repetition < 4; repetition++) {
      counter.add(_pullUpFrame(170, repetition * 2));
      counter.add(_pullUpFrame(75, repetition * 2 + 1));
    }
    expect(counter.count(ExerciseType.pullUp), 4);
  });
}

PoseFrame _pullUpFrame(double elbowDegrees, int second) {
  final radians = elbowDegrees * 3.141592653589793 / 180;
  return PoseFrame(
    timestamp: Duration(seconds: second),
    points: {
      Joint.leftShoulder: const PosePoint(x: 0, y: 0, confidence: 1),
      Joint.leftElbow: const PosePoint(x: 1, y: 0, confidence: 1),
      Joint.leftWrist: PosePoint(
        x: 1 - math.cos(radians),
        y: math.sin(radians),
        confidence: 1,
      ),
    },
  );
}
