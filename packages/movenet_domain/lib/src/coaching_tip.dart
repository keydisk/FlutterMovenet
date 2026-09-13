class CoachingTip {
  const CoachingTip({required this.title, required this.message});

  factory CoachingTip.fromJson(Map<String, Object?> json) => CoachingTip(
    title: json['title']! as String,
    message: json['message']! as String,
  );

  final String title;
  final String message;

  Map<String, Object> toJson() => {'title': title, 'message': message};
}
