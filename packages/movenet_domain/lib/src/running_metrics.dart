class RunningMetrics {
  const RunningMetrics({
    this.cadence,
    this.trunkLean,
    this.kneeAngle,
    this.hipFlexion,
  });

  factory RunningMetrics.fromJson(Map<String, Object?> json) => RunningMetrics(
    cadence: (json['cadence'] as num?)?.toDouble(),
    trunkLean: (json['trunkLean'] as num?)?.toDouble(),
    kneeAngle: (json['kneeAngle'] as num?)?.toDouble(),
    hipFlexion: (json['hipFlexion'] as num?)?.toDouble(),
  );

  /// 분당 보수(spm). 데이터 부족 시 null.
  final double? cadence;

  /// 상체 기울기(도). +면 진행 방향으로 숙임.
  final double? trunkLean;

  /// 무릎 굽힘 평균 내각(도).
  final double? kneeAngle;

  /// 고관절 굽힘 평균 내각(도).
  final double? hipFlexion;

  Map<String, Object> toJson() => {
    'cadence': ?cadence,
    'trunkLean': ?trunkLean,
    'kneeAngle': ?kneeAngle,
    'hipFlexion': ?hipFlexion,
  };
}
