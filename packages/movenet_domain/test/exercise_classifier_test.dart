import 'package:movenet_domain/movenet_domain.dart';
import 'package:test/test.dart';

void main() {
  const classifier = ExerciseClassifier();
  const labels = [
    'squat',
    'walking the dog',
    'deadlifting',
    'cooking egg',
    'pull ups',
  ];

  test('supported exercise with the highest mass is confirmed', () {
    final result = classifier.classify([5, 1, 0, 0, 0], labels);
    expect(result.prediction, ExerciseType.squat);
    expect(result.showsCandidates, isFalse);
  });

  test('unsupported exercise on top falls back to candidates', () {
    final result = classifier.classify([1, 0, 5, 0, 0], labels);
    expect(result.prediction, isNull);
    expect(result.showsCandidates, isTrue);
    expect(result.candidates.first.id, 'deadlift');
    expect(result.candidates.first.label, '데드리프트');
  });

  test('low relevant mass is not confirmed', () {
    final result = classifier.classify([0, 0, 0, 8, 0], labels);
    expect(result.prediction, isNull);
  });
}
