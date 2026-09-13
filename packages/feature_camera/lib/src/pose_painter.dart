import 'package:flutter/material.dart';
import 'package:movenet_domain/movenet_domain.dart';

class PosePainter extends CustomPainter {
  const PosePainter(this.pose, this.minimumConfidence);

  final PoseFrame pose;
  final double minimumConfidence;

  static const _connections = [
    (Joint.leftShoulder, Joint.rightShoulder),
    (Joint.leftShoulder, Joint.leftElbow),
    (Joint.leftElbow, Joint.leftWrist),
    (Joint.rightShoulder, Joint.rightElbow),
    (Joint.rightElbow, Joint.rightWrist),
    (Joint.leftShoulder, Joint.leftHip),
    (Joint.rightShoulder, Joint.rightHip),
    (Joint.leftHip, Joint.rightHip),
    (Joint.leftHip, Joint.leftKnee),
    (Joint.leftKnee, Joint.leftAnkle),
    (Joint.rightHip, Joint.rightKnee),
    (Joint.rightKnee, Joint.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = const Color(0xFFFFD740);
    for (final (start, end) in _connections) {
      final a = pose.point(start, minimumConfidence);
      final b = pose.point(end, minimumConfidence);
      if (a != null && b != null) {
        canvas.drawLine(_offset(a, size), _offset(b, size), line);
      }
    }
    for (final point in pose.points.values.where(
      (point) => point.confidence >= minimumConfidence,
    )) {
      canvas.drawCircle(_offset(point, size), 4, dot);
    }
  }

  Offset _offset(PosePoint point, Size size) =>
      Offset(point.x * size.width, point.y * size.height);

  @override
  bool shouldRepaint(PosePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.minimumConfidence != minimumConfidence;
}
