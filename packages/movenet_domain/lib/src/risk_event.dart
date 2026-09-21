import 'joint.dart';

/// 위험 각도 판정 대상 관절 (정점 기준 3관절 각도).
enum RiskJoint {
  leftElbow('왼쪽 팔꿈치', (Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist)),
  rightElbow('오른쪽 팔꿈치', (
    Joint.rightShoulder,
    Joint.rightElbow,
    Joint.rightWrist,
  )),
  leftKnee('왼쪽 무릎', (Joint.leftHip, Joint.leftKnee, Joint.leftAnkle)),
  rightKnee('오른쪽 무릎', (Joint.rightHip, Joint.rightKnee, Joint.rightAnkle)),
  leftShoulder('왼쪽 어깨', (Joint.leftHip, Joint.leftShoulder, Joint.leftElbow)),
  rightShoulder('오른쪽 어깨', (
    Joint.rightHip,
    Joint.rightShoulder,
    Joint.rightElbow,
  )),
  leftHip('왼쪽 고관절', (Joint.leftShoulder, Joint.leftHip, Joint.leftKnee)),
  rightHip('오른쪽 고관절', (Joint.rightShoulder, Joint.rightHip, Joint.rightKnee));

  const RiskJoint(this.label, this.joints);

  final String label;
  final (Joint, Joint, Joint) joints;

  bool get isUpperBody =>
      this == leftElbow ||
      this == rightElbow ||
      this == leftShoulder ||
      this == rightShoulder;
}

class RiskEvent {
  const RiskEvent({
    required this.timestamp,
    required this.joint,
    required this.degrees,
    required this.description,
    this.critical = false,
    this.imagePath,
  });

  factory RiskEvent.fromJson(Map<String, Object?> json) => RiskEvent(
    timestamp: Duration(milliseconds: json['timestampMs']! as int),
    joint: RiskJoint.values.byName(json['joint']! as String),
    degrees: (json['degrees']! as num).toDouble(),
    description: json['description']! as String,
    critical: json['critical'] as bool? ?? false,
    imagePath: json['imagePath'] as String?,
  );

  final Duration timestamp;
  final RiskJoint joint;
  final double degrees;
  final String description;
  final bool critical;

  /// 위험이 감지된 순간의 프레임 이미지 경로.
  final String? imagePath;

  Map<String, Object> toJson() => {
    'timestampMs': timestamp.inMilliseconds,
    'joint': joint.name,
    'degrees': degrees,
    'description': description,
    'critical': critical,
    'imagePath': ?imagePath,
  };

  RiskEvent withImage(String? path) => RiskEvent(
    timestamp: timestamp,
    joint: joint,
    degrees: degrees,
    description: description,
    critical: critical,
    imagePath: path,
  );
}
