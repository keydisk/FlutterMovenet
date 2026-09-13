class RunningMetrics {
  const RunningMetrics({
    required this.cadence,
    required this.trunkLean,
    required this.kneeAngle,
    required this.hipMobility,
  });

  factory RunningMetrics.fromJson(Map<String, Object?> json) => RunningMetrics(
    cadence: (json['cadence']! as num).toDouble(),
    trunkLean: (json['trunkLean']! as num).toDouble(),
    kneeAngle: (json['kneeAngle']! as num).toDouble(),
    hipMobility: (json['hipMobility']! as num).toDouble(),
  );

  final double cadence;
  final double trunkLean;
  final double kneeAngle;
  final double hipMobility;

  Map<String, Object> toJson() => {
    'cadence': cadence,
    'trunkLean': trunkLean,
    'kneeAngle': kneeAngle,
    'hipMobility': hipMobility,
  };
}
