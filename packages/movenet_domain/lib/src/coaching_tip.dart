class CoachingTip {
  const CoachingTip({
    required this.title,
    required this.message,
    this.isWarning = false,
  });

  factory CoachingTip.fromJson(Map<String, Object?> json) => CoachingTip(
    title: json['title']! as String,
    message: json['message']! as String,
    isWarning: json['isWarning'] as bool? ?? false,
  );

  final String title;
  final String message;
  final bool isWarning;

  Map<String, Object> toJson() => {
    'title': title,
    'message': message,
    'isWarning': isWarning,
  };
}
