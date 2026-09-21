enum ExerciseType {
  pullUp('풀업'),
  squat('스쿼트'),
  pushUp('푸쉬업'),
  running('러닝'),
  walking('걷기'),
  unknown('분석 중');

  const ExerciseType(this.label);

  final String label;

  /// 반복 횟수를 세는 근력운동 여부.
  bool get isRepExercise => this == squat || this == pullUp || this == pushUp;
}
