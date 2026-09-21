import 'dart:math' as math;

import 'exercise_type.dart';

/// 자동 감지된 운동 후보(판정이 애매할 때 노출).
class ExerciseCandidate {
  const ExerciseCandidate({required this.id, required this.confidence});

  factory ExerciseCandidate.fromJson(Map<String, Object?> json) =>
      ExerciseCandidate(
        id: json['id']! as String,
        confidence: (json['confidence']! as num).toDouble(),
      );

  /// 큐레이션 운동 식별자.
  final String id;

  /// 큐레이션 운동 전체 확률 대비 이 운동의 비율(0~1).
  final double confidence;

  String get label => _names[id] ?? id;

  Map<String, Object> toJson() => {'id': id, 'confidence': confidence};

  static const _names = {
    'walking': '걷기',
    'running': '러닝',
    'squat': '스쿼트',
    'pullUp': '풀업',
    'pushUp': '푸시업',
    'lunge': '런지',
    'deadlift': '데드리프트',
    'benchPress': '벤치프레스',
    'snatch': '역도(스내치)',
    'mountainClimber': '마운틴 클라이머',
    'exerciseBall': '짐볼 운동',
    'stretching': '스트레칭',
  };
}

/// MoViNet 분류 결과: 지원 종목 확정 판정 + 큐레이션 후보 + 후보 노출 여부.
class ExerciseClassification {
  const ExerciseClassification({
    this.prediction,
    this.confidence = 0,
    this.candidates = const [],
  });

  /// 걷기/러닝/스쿼트/풀업/푸시업 확정 판정. 미지원/근거 부족이면 null.
  final ExerciseType? prediction;
  final double confidence;
  final List<ExerciseCandidate> candidates;

  /// 확정이 아니어서 후보를 보여줘야 하는지.
  bool get showsCandidates => prediction == null && candidates.isNotEmpty;
}

/// MoViNet(Kinetics-600) 로짓을 운동 종류로 해석한다.
/// iOS `KineticsLocomotionMapper` + `ExerciseCatalog` + `ExerciseClassifier`를 옮긴 것.
///
/// 정책: 지원 종목이 최고 확률이면 그 종목으로 확정, 지원 외 운동이 최고일 때만 후보를 보여준다.
class ExerciseClassifier {
  const ExerciseClassifier({
    this.minRelevantMass = 0.15,
    this.minCandidateMass = 0.03,
    this.maxCandidates = 3,
  });

  /// 지원 종목 확률 합이 이보다 작으면 판정 보류.
  final double minRelevantMass;

  /// 후보로 채택할 최소 비율.
  final double minCandidateMass;
  final int maxCandidates;

  static const _pullUp = ['pull up'];
  static const _pushUp = ['push up'];
  static const _squat = ['squat'];
  static const _running = ['running', 'jog', 'sprint'];
  static const _walking = ['walk'];
  static const _excluded = [
    'deadlift',
    'lunge',
    'bench pressing',
    'snatch',
    'mountain climber',
    'exercise ball',
  ];

  /// Kinetics-600에 실제 있는 운동 라벨만 큐레이션(엔트리 순서가 우선순위).
  static const _catalog = [
    ('walking', ['walk']),
    ('running', ['running', 'jog', 'sprint']),
    ('squat', ['squat']),
    ('pullUp', ['pull up']),
    ('pushUp', ['push up']),
    ('lunge', ['lunge']),
    ('deadlift', ['deadlift']),
    ('benchPress', ['bench press']),
    ('snatch', ['snatch']),
    ('mountainClimber', ['mountain climber']),
    ('exerciseBall', ['exercise ball']),
    ('stretching', ['stretching']),
  ];

  ExerciseClassification classify(List<double> logits, List<String> labels) {
    if (logits.isEmpty || logits.length != labels.length) {
      return const ExerciseClassification();
    }
    final probs = softmax(logits);
    final (prediction, confidence) = _predict(probs, labels) ?? (null, 0.0);
    return ExerciseClassification(
      prediction: prediction,
      confidence: confidence,
      candidates: _candidates(probs, labels),
    );
  }

  (ExerciseType, double)? _predict(List<double> probs, List<String> labels) {
    final mass = <ExerciseType, double>{};
    var excluded = 0.0;
    bool has(String name, List<String> keywords) => keywords.any(name.contains);
    for (var i = 0; i < labels.length; i++) {
      final name = labels[i].toLowerCase();
      // 더 구체적인 키워드("pull up"/"push up")를 먼저 본다.
      final type = has(name, _pullUp)
          ? ExerciseType.pullUp
          : has(name, _pushUp)
          ? ExerciseType.pushUp
          : has(name, _excluded)
          ? null
          : has(name, _squat)
          ? ExerciseType.squat
          : has(name, _running)
          ? ExerciseType.running
          : has(name, _walking)
          ? ExerciseType.walking
          : ExerciseType.unknown;
      if (type == null) {
        excluded += probs[i];
      } else if (type != ExerciseType.unknown) {
        mass.update(
          type,
          (value) => value + probs[i],
          ifAbsent: () => probs[i],
        );
      }
    }
    final total = mass.values.fold(0.0, (a, b) => a + b);
    if (total < minRelevantMass) return null;
    // 동률이면 iOS와 같은 순서(스쿼트 > 러닝 > 걷기 > 풀업 > 푸시업)를 우선한다.
    const order = [
      ExerciseType.squat,
      ExerciseType.running,
      ExerciseType.walking,
      ExerciseType.pullUp,
      ExerciseType.pushUp,
    ];
    final winner = order.reduce(
      (a, b) => (mass[b] ?? 0) > (mass[a] ?? 0) ? b : a,
    );
    final winnerMass = mass[winner] ?? 0;
    // 지원 외 운동 질량이 승자보다 크면 오판 방지로 보류(후보로 넘김).
    if (excluded >= winnerMass) return null;
    return (winner, winnerMass / total);
  }

  List<ExerciseCandidate> _candidates(List<double> probs, List<String> labels) {
    final mass = <String, double>{};
    for (var i = 0; i < labels.length; i++) {
      final name = labels[i].toLowerCase();
      for (final (id, keywords) in _catalog) {
        if (keywords.any(name.contains)) {
          mass.update(
            id,
            (value) => value + probs[i],
            ifAbsent: () => probs[i],
          );
          break;
        }
      }
    }
    final total = mass.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const [];
    final candidates = [
      for (final MapEntry(:key, :value) in mass.entries)
        if (value / total >= minCandidateMass)
          ExerciseCandidate(id: key, confidence: value / total),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.take(maxCandidates).toList();
  }

  /// 수치 안정 softmax.
  static List<double> softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = [for (final logit in logits) math.exp(logit - maxLogit)];
    final sum = exps.fold(0.0, (a, b) => a + b);
    return [for (final value in exps) sum > 0 ? value / sum : 0];
  }
}
