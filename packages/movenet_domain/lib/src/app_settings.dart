class AppSettings {
  const AppSettings({
    this.minimumConfidence = 0.35,
    this.showSkeleton = true,
    this.showFps = true,
    this.useFrontCamera = false,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    minimumConfidence: (json['minimumConfidence'] as num?)?.toDouble() ?? 0.35,
    showSkeleton: json['showSkeleton'] as bool? ?? true,
    showFps: json['showFps'] as bool? ?? true,
    useFrontCamera: json['useFrontCamera'] as bool? ?? false,
  );

  final double minimumConfidence;
  final bool showSkeleton;
  final bool showFps;
  final bool useFrontCamera;

  AppSettings copyWith({
    double? minimumConfidence,
    bool? showSkeleton,
    bool? showFps,
    bool? useFrontCamera,
  }) => AppSettings(
    minimumConfidence: minimumConfidence ?? this.minimumConfidence,
    showSkeleton: showSkeleton ?? this.showSkeleton,
    showFps: showFps ?? this.showFps,
    useFrontCamera: useFrontCamera ?? this.useFrontCamera,
  );

  Map<String, Object> toJson() => {
    'minimumConfidence': minimumConfidence,
    'showSkeleton': showSkeleton,
    'showFps': showFps,
    'useFrontCamera': useFrontCamera,
  };
}
