import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:video_player/video_player.dart';

import 'pose_track.dart';

/// 재생 위치를 따라가며 포즈 트랙을 샘플·평활해 오버레이에 넘긴다.
/// video_player는 위치를 약 0.5초 간격으로만 알려 주므로 그 사이는 경과 시간으로 보간한다.
class PoseOverlayDriver extends ChangeNotifier {
  PoseOverlayDriver({required this.video, required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_tick)..start();
  }

  final VideoPlayerController video;
  late final Ticker _ticker;

  PoseTrack? _track;
  PoseSmoother? _smoother;
  Duration _time = Duration.zero;
  Duration? _reported;
  final _sinceReport = Stopwatch();
  bool _dirty = true;

  PoseTrack? get track => _track;
  set track(PoseTrack? value) {
    if (identical(value, _track)) return;
    _track = value;
    _smoother = value == null
        ? null
        : PoseSmoother(minConfidence: value.minConfidence);
    _dirty = true;
  }

  /// 평활된 상태. 트랙이 없으면 null.
  PoseSmoother? get smoother => _smoother;

  Duration get time => _time;

  double get aspect =>
      video.value.isInitialized ? video.value.aspectRatio : 16 / 9;

  void _tick(Duration _) {
    final value = video.value;
    if (!value.isInitialized) return;
    final time = _estimate(value);
    if (time == _time && !_dirty) return;
    _dirty = false;
    _time = time;
    _smoother?.update(_track?.sample(time), time, aspect);
    notifyListeners();
  }

  Duration _estimate(VideoPlayerValue value) {
    if (value.position != _reported) {
      _reported = value.position;
      _sinceReport
        ..reset()
        ..start();
    }
    if (!value.isPlaying) return value.position;
    var time = value.position + _sinceReport.elapsed * value.playbackSpeed;
    if (time > value.duration) time = value.duration;
    // 늦게 도착한 위치 보고 때문에 살짝 뒤로 가는 것은 무시해 화면이 되감기듯 튀지 않게 한다.
    if (_time > time && _time - time < const Duration(milliseconds: 300)) {
      return _time;
    }
    return time;
  }

  /// 앞/뒤 분석 프레임으로 한 칸 이동(일시정지 상태에서 자세를 짚어 보기용).
  Future<void> step(int direction) async {
    final frames = _track?.frames;
    if (frames == null || frames.isEmpty) return;
    await video.pause();
    final now = _time;
    final target = direction > 0
        ? frames.firstWhere(
            (f) => f.timestamp > now + const Duration(milliseconds: 5),
            orElse: () => frames.last,
          )
        : frames.lastWhere(
            (f) => f.timestamp < now - const Duration(milliseconds: 5),
            orElse: () => frames.first,
          );
    await video.seekTo(target.timestamp);
    _dirty = true;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// 관절 뼈대·점, 인식 박스, 관절 각도 라벨을 영상 위에 그린다.
class PoseOverlayPainter extends CustomPainter {
  PoseOverlayPainter(
    this.driver, {
    required this.labels,
    required this.textStyle,
    this.large = false,
  }) : super(repaint: driver);

  final PoseOverlayDriver driver;

  /// 캔버스 글자는 테마를 상속하지 않으므로 화면의 기본 글꼴을 넘겨받는다.
  final TextStyle textStyle;

  /// 영상 위에 각도 숫자를 붙일 관절.
  final Set<RiskJoint> labels;
  final bool large;

  static const bone = Color(0xFF00E5FF);
  static const dot = Color(0xFFFFD740);
  static const caution = Color(0xFFFF9F0A);

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
    final smoother = driver.smoother;
    if (smoother == null || smoother.points.isEmpty) return;
    final points = {
      for (final MapEntry(key: joint, value: p) in smoother.points.entries)
        joint: Offset(p.dx * size.width, p.dy * size.height),
    };
    final cautionJoints = {
      for (final MapEntry(key: joint, value: degrees)
          in smoother.angles.entries)
        if (JointStatus.of(joint, degrees.toDouble()).level ==
            StatusLevel.caution)
          joint.joints.$2,
    };

    _box(canvas, size, points.values);

    final scale = large ? 1.4 : 1.0;
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 5 * scale
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = bone
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;
    for (final (start, end) in _connections) {
      final a = points[start], b = points[end];
      if (a == null || b == null) continue;
      canvas
        ..drawLine(a, b, outline)
        ..drawLine(a, b, line);
    }
    for (final MapEntry(key: joint, value: p) in points.entries) {
      final isCaution = cautionJoints.contains(joint);
      canvas
        ..drawCircle(p, 5 * scale, Paint()..color = Colors.black54)
        ..drawCircle(
          p,
          (isCaution ? 4.5 : 3.5) * scale,
          Paint()..color = isCaution ? caution : dot,
        );
    }

    _angleLabels(canvas, size, points, smoother.angles);
  }

  /// 인식된 사람 영역을 모서리 괄호로 표시한다(영상을 덜 가리도록 테두리 전체는 그리지 않는다).
  void _box(Canvas canvas, Size size, Iterable<Offset> points) {
    final box = personBox(points, size);
    if (box == null) return;
    final corner = math.min(box.shortestSide * 0.18, large ? 26.0 : 16.0);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = large ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;
    for (final (origin, dx, dy) in [
      (box.topLeft, 1.0, 1.0),
      (box.topRight, -1.0, 1.0),
      (box.bottomLeft, 1.0, -1.0),
      (box.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx + corner * dx, origin.dy)
          ..lineTo(origin.dx, origin.dy)
          ..lineTo(origin.dx, origin.dy + corner * dy),
        paint,
      );
    }
  }

  void _angleLabels(
    Canvas canvas,
    Size size,
    Map<Joint, Offset> points,
    Map<RiskJoint, int> angles,
  ) {
    final placed = <Rect>[];
    final center = _centroid(points.values);
    for (final joint in RiskJoint.values) {
      if (!labels.contains(joint)) continue;
      final degrees = angles[joint];
      if (degrees == null) continue;
      final (a, b, c) = joint.joints;
      final pa = points[a], pb = points[b], pc = points[c];
      if (pa == null || pb == null || pc == null) continue;
      final isCaution =
          JointStatus.of(joint, degrees.toDouble()).level ==
          StatusLevel.caution;

      final text = TextPainter(
        text: TextSpan(
          text: '$degrees°',
          style: textStyle.copyWith(
            fontSize: large ? 14 : 10,
            fontWeight: FontWeight.w700,
            color: isCaution ? caution : Colors.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final padding = EdgeInsets.symmetric(
        horizontal: large ? 7 : 5,
        vertical: large ? 3 : 2,
      );
      final labelSize = Size(
        text.width + padding.horizontal,
        text.height + padding.vertical,
      );

      // 관절 각의 바깥쪽(두 뼈 사이가 아닌 쪽)으로 라벨을 띄워 뼈대를 가리지 않게 한다.
      final u = _unit(pa - pb), v = _unit(pc - pb);
      var direction = -(u + v);
      if (direction.distance < 0.2) {
        // 거의 펴진 관절: 뼈에 수직이면서 몸 중심 바깥쪽.
        direction = Offset(-u.dy, u.dx);
        if ((pb + direction - center).distance < (pb - center).distance) {
          direction = -direction;
        }
      }
      direction = _unit(direction);
      // 라벨 가장자리가 관절 점에서 gap만큼 떨어지도록 라벨 크기만큼 더 민다.
      final gap = large ? 12.0 : 8.0;
      final halfExtent =
          direction.dx.abs() * labelSize.width / 2 +
          direction.dy.abs() * labelSize.height / 2;
      final anchor = pb + direction * (gap + halfExtent);
      var rect = Rect.fromCenter(
        center: anchor,
        width: labelSize.width,
        height: labelSize.height,
      );
      rect = _clamp(rect, size);
      // 다른 라벨과 겹치면 아래로 비켜 놓는다.
      for (var i = 0; i < 4 && placed.any(rect.overlaps); i++) {
        rect = _clamp(rect.shift(Offset(0, labelSize.height + 2)), size);
      }
      placed.add(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(labelSize.height / 2)),
        Paint()..color = Colors.black.withValues(alpha: isCaution ? 0.75 : 0.6),
      );
      if (isCaution) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(labelSize.height / 2)),
          Paint()
            ..color = caution
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      text.paint(canvas, rect.topLeft + Offset(padding.left, padding.top));
    }
  }

  static Offset _unit(Offset o) => o.distance == 0 ? o : o / o.distance;

  static Offset _centroid(Iterable<Offset> points) {
    var sum = Offset.zero;
    for (final p in points) {
      sum += p;
    }
    return points.isEmpty ? Offset.zero : sum / points.length.toDouble();
  }

  static Rect _clamp(Rect rect, Size size) => rect.shift(
    Offset(
      rect.left < 0
          ? -rect.left
          : rect.right > size.width
          ? size.width - rect.right
          : 0,
      rect.top < 0
          ? -rect.top
          : rect.bottom > size.height
          ? size.height - rect.bottom
          : 0,
    ),
  );

  @override
  bool shouldRepaint(PoseOverlayPainter oldDelegate) =>
      oldDelegate.driver != driver ||
      oldDelegate.large != large ||
      oldDelegate.labels != labels ||
      oldDelegate.textStyle != textStyle;
}

/// 관절 점들을 감싸는 사람 영역(머리·발끝 여유 포함).
Rect? personBox(Iterable<Offset> points, Size size) {
  if (points.length < 3) return null;
  var box = Rect.fromPoints(points.first, points.first);
  for (final p in points) {
    box = box.expandToInclude(Rect.fromPoints(p, p));
  }
  final pad = math.max(box.height * 0.08, 10.0);
  return Rect.fromLTRB(
    box.left - pad,
    box.top - pad * 1.6,
    box.right + pad,
    box.bottom + pad,
  ).intersect(Offset.zero & size);
}
