import 'dart:math' as math;

import 'analysis_result.dart';
import 'coaching_tip.dart';
import 'exercise_classifier.dart';
import 'exercise_type.dart';
import 'joint.dart';
import 'pose_frame.dart';
import 'risk_event.dart';
import 'running_metrics.dart';

/// 영상 전체 pose 시퀀스를 규칙 기반으로 분석한다.
/// iOS `AnalyzeRunningFormUseCase` + `ExerciseFormAnalyzer` + 사전분석 위험 감지를 옮긴 것.
/// 좌표는 표시 방향 정규화 좌표(y 아래로 증가), x에 종횡비를 곱해 y와 단위를 맞춘다.
class FormAnalyzer {
  const FormAnalyzer({this.minConfidence = 0.2});

  final double minConfidence;

  static const _minStepInterval = 0.2;
  static const _minimumFlightHeight = 0.025;
  static const _minimumFlightFrames = 2;

  AnalysisResult analyze(
    List<PoseFrame> frames, {
    required Duration duration,
    double aspectRatio = 1,
    List<RiskEvent> risks = const [],
    ExerciseClassification? classification,
  }) {
    final aspect = aspectRatio > 0 ? aspectRatio : 1.0;

    final hipY = <double>[];
    final hipX = <double>[];
    final hipTimes = <double>[];
    var leanSum = 0.0, leanCount = 0;
    var kneeSum = 0.0, kneeCount = 0;
    final kneeSeq = <double>[];
    final elbowSeq = <double>[];
    var hipFlexionSum = 0.0, hipFlexionCount = 0;

    for (final frame in frames) {
      final hip = _midpoint(frame, Joint.leftHip, Joint.rightHip, aspect);
      final shoulder = _midpoint(
        frame,
        Joint.leftShoulder,
        Joint.rightShoulder,
        aspect,
      );
      if (shoulder == null || hip == null) continue;
      // 상체 기울기: 골반→어깨 벡터가 수직에서 벗어난 각도 (+x쪽 = 오른쪽으로 숙임)
      leanSum +=
          math.atan2(shoulder.x - hip.x, hip.y - shoulder.y) * 180 / math.pi;
      leanCount++;

      hipY.add(hip.y);
      hipX.add(hip.x);
      hipTimes.add(_seconds(frame));

      if (_limbAngle(frame, _legs, aspect) case final knee?) {
        kneeSum += knee;
        kneeCount++;
        kneeSeq.add(knee);
      }
      if (_limbAngle(frame, _arms, aspect) case final elbow?) {
        elbowSeq.add(elbow);
      }
      if (_limbAngle(frame, _torsoLegs, aspect) case final hipFlexion?) {
        hipFlexionSum += hipFlexion;
        hipFlexionCount++;
      }
    }

    final analyzed = hipTimes.length;

    // MoViNet 판정이 애매하면(지원 외 운동이 최고) 지표 코칭 대신 후보 목록만 제시한다.
    if (classification != null && classification.showsCandidates) {
      return AnalysisResult(
        exercise: ExerciseType.unknown,
        probabilities: const {ExerciseType.unknown: 1},
        repetitions: 0,
        coaching: const [
          CoachingTip(
            title: '운동 종류',
            message: '운동 종류가 명확하지 않아요. 아래 후보를 확인하거나 옆모습으로 다시 촬영해 주세요.',
            isWarning: true,
          ),
        ],
        duration: duration,
        riskEvents: risks.length,
        risks: risks,
        analyzedFrames: analyzed,
        candidates: classification.candidates,
      );
    }
    final modelType = classification?.prediction;
    final avgLean = leanCount > 0 ? leanSum / leanCount : null;
    final avgKnee = kneeCount > 0 ? kneeSum / kneeCount : null;
    final avgHipFlexion = hipFlexionCount > 0
        ? hipFlexionSum / hipFlexionCount
        : null;

    // 진행 방향: 골반 x의 순변위 부호. 거의 안 움직이면(트레드밀 등) 불명.
    double? travel;
    if (hipX.isNotEmpty) {
      final displacement = hipX.last - hipX.first;
      if (displacement.abs() > 0.05) travel = displacement > 0 ? 1 : -1;
    }

    final cadenceValue = cadence(hipY, hipTimes);
    final tiers = _locomotionTiers(hipY, hipTimes);
    final forwardLean = avgLean == null
        ? null
        : travel != null
        ? avgLean * travel
        : avgLean.abs();

    final (squatReps, squatDepth) = countReps(kneeSeq);
    final kneeTopExtension = kneeSeq.isEmpty ? null : kneeSeq.reduce(math.max);
    final armsOverhead = _armsOverheadFraction(frames);
    final (armReps, elbowMin) = countArmReps(elbowSeq);
    final bodyHorizontal = _bodyHorizontalFraction(frames);
    final hasFlight = _hasFlightPhase(frames);

    final ExerciseType type;
    if (analyzed < 8) {
      type = ExerciseType.unknown;
    } else if (modelType != null) {
      // MoViNet이 확정하면 그 결과를 우선한다(휴리스틱 대체).
      type = modelType;
    } else if (squatReps >= 1 &&
        squatDepth != null &&
        squatDepth < 120 &&
        travel == null &&
        kneeTopExtension != null &&
        kneeTopExtension >= 160 &&
        armsOverhead < 0.3) {
      type = ExerciseType.squat;
    } else if (armReps >= 1 &&
        elbowMin != null &&
        elbowMin < 110 &&
        armsOverhead >= 0.5 &&
        travel == null) {
      type = ExerciseType.pullUp;
    } else if (armReps >= 1 &&
        elbowMin != null &&
        elbowMin < 110 &&
        bodyHorizontal >= 0.5) {
      type = ExerciseType.pushUp;
    } else if (hasFlight != null) {
      type = hasFlight && !(cadenceValue != null && cadenceValue < 135)
          ? ExerciseType.running
          : ExerciseType.walking;
    } else if (cadenceValue != null) {
      type = cadenceValue < 145 ? ExerciseType.walking : ExerciseType.running;
    } else if (avgKnee != null &&
        avgKnee > 168 &&
        forwardLean != null &&
        forwardLean < 4) {
      type = ExerciseType.walking;
    } else {
      type = ExerciseType.running;
    }

    final relevantRisks = relevantRiskEvents(risks, type);
    final metrics = RunningMetrics(
      cadence: type.isRepExercise ? null : cadenceValue,
      trunkLean: forwardLean,
      kneeAngle: avgKnee,
      hipFlexion: avgHipFlexion,
    );

    if (type.isRepExercise) {
      final reps = type == ExerciseType.squat ? squatReps : armReps;
      final depth = type == ExerciseType.squat ? squatDepth : elbowMin;
      final form = _formMetrics(frames, aspect);
      return AnalysisResult(
        exercise: type,
        probabilities: {type: 1},
        repetitions: reps,
        coaching: type == ExerciseType.squat
            ? _squatTips(reps, depth, forwardLean, analyzed, form)
            : _armTips(type, reps, depth, analyzed, form),
        duration: duration,
        riskEvents: relevantRisks.length,
        risks: relevantRisks,
        runningMetrics: metrics,
        analyzedFrames: analyzed,
        depthDegrees: depth,
        modelConfidence: _modelConfidence(classification, type),
      );
    }

    final primaryTier =
        _primaryTier(tiers) ??
        (type == ExerciseType.walking ? _Tier.walking : _Tier.running);
    return AnalysisResult(
      exercise: type,
      probabilities: {type: 1},
      repetitions: 0,
      coaching: _locomotionTips(
        type: type,
        tier: primaryTier,
        cadence: cadenceValue,
        forwardLean: forwardLean,
        directionKnown: travel != null,
        avgKnee: avgKnee,
        avgHipFlexion: avgHipFlexion,
        analyzed: analyzed,
      ),
      duration: duration,
      riskEvents: relevantRisks.length,
      risks: relevantRisks,
      runningMetrics: metrics,
      analyzedFrames: analyzed,
      modelConfidence: _modelConfidence(classification, type),
      locomotionSummary: tiers.isEmpty
          ? null
          : _Tier.values
                .where(tiers.contains)
                .map((tier) => tier.label)
                .join(' + '),
    );
  }

  static double? _modelConfidence(
    ExerciseClassification? classification,
    ExerciseType type,
  ) => classification?.prediction == type ? classification!.confidence : null;

  static List<RiskEvent> relevantRiskEvents(
    List<RiskEvent> events,
    ExerciseType type,
  ) => events.where((event) {
    return switch (type) {
      ExerciseType.pullUp || ExerciseType.pushUp => event.joint.isUpperBody,
      ExerciseType.unknown => true,
      _ => !event.joint.isUpperBody,
    };
  }).toList();

  // MARK: rep 카운트

  /// 굽힘 임계(down) 아래로 내려갔다가 폄 임계(up) 위로 돌아오면 1회.
  static (int, double?) countReps(
    List<double> angles, {
    double downThreshold = 120,
    double upThreshold = 150,
  }) {
    if (angles.length < 4) return (0, null);
    var reps = 0;
    var inBottom = false;
    for (final angle in angles) {
      if (angle <= downThreshold) {
        inBottom = true;
      } else if (angle >= upThreshold && inBottom) {
        reps++;
        inBottom = false;
      }
    }
    return (reps, angles.reduce(math.min));
  }

  /// 영상에서 실제 관측된 팔꿈치 가동범위의 왕복으로 센다.
  static (int, double?) countArmReps(List<double> angles) {
    if (angles.isEmpty) return (0, null);
    final minimum = angles.reduce(math.min);
    final range = angles.reduce(math.max) - minimum;
    if (range < 20) return (0, minimum);
    return countReps(
      angles,
      downThreshold: minimum + range * 0.35,
      upThreshold: minimum + range * 0.7,
    );
  }

  // MARK: 케이던스 (골반 상하 진동 피크 수)

  static double? cadence(List<double> hipY, List<double> times) {
    if (hipY.length < 8) return null;
    final minY = hipY.reduce(math.min);
    final amplitude = hipY.reduce(math.max) - minY;
    if (amplitude <= 0.01) return null;
    final floor = minY + amplitude * 0.3;
    var steps = 0;
    var lastPeak = double.negativeInfinity;
    for (var i = 1; i < hipY.length - 1; i++) {
      final isLocalMax = hipY[i] > hipY[i - 1] && hipY[i] >= hipY[i + 1];
      if (!isLocalMax || hipY[i] < floor) continue;
      if (times[i] - lastPeak < _minStepInterval) continue;
      steps++;
      lastPeak = times[i];
    }
    final span = times.reduce(math.max) - times.reduce(math.min);
    if (span < 1.5 || steps < 3) return null;
    return steps / span * 60;
  }

  /// 4초 윈도우별 케이던스 티어 목록 (iOS LocomotionSegmentAnalyzer).
  static List<_Tier> _locomotionTiers(List<double> hipY, List<double> times) {
    if (hipY.length < 8 || times.last <= times.first) return const [];
    final tiers = <_Tier>[];
    for (var start = times.first; start < times.last; start += 4) {
      final windowY = <double>[];
      final windowTimes = <double>[];
      for (var i = 0; i < times.length; i++) {
        if (times[i] >= start && times[i] < start + 4) {
          windowY.add(hipY[i]);
          windowTimes.add(times[i]);
        }
      }
      if (cadence(windowY, windowTimes) case final value?) {
        tiers.add(_Tier.forCadence(value));
      }
    }
    return tiers;
  }

  static _Tier? _primaryTier(List<_Tier> tiers) {
    if (tiers.isEmpty) return null;
    // 최빈 티어, 동률이면 더 높은 강도 우선
    return _Tier.values.where(tiers.contains).reduce((a, b) {
      final countA = tiers.where((tier) => tier == a).length;
      final countB = tiers.where((tier) => tier == b).length;
      return countB >= countA ? b : a;
    });
  }

  // MARK: 동작 판별 보조

  bool? _hasFlightPhase(List<PoseFrame> frames) {
    final pairs = <(double, double)>[];
    for (final frame in frames) {
      final left = frame.point(Joint.leftAnkle, minConfidence);
      final right = frame.point(Joint.rightAnkle, minConfidence);
      if (left != null && right != null) pairs.add((left.y, right.y));
    }
    if (pairs.length < 8) return null;
    final heights = [
      for (final (l, r) in pairs) ...[l, r],
    ]..sort();
    final groundY = heights[((heights.length - 1) * 0.9).toInt()];
    var consecutive = 0;
    for (final (left, right) in pairs) {
      if (groundY - math.max(left, right) >= _minimumFlightHeight) {
        if (++consecutive >= _minimumFlightFrames) return true;
      } else {
        consecutive = 0;
      }
    }
    return false;
  }

  double _armsOverheadFraction(List<PoseFrame> frames) {
    var valid = 0, overhead = 0;
    for (final frame in frames) {
      final lw = frame.point(Joint.leftWrist, minConfidence);
      final rw = frame.point(Joint.rightWrist, minConfidence);
      final ls = frame.point(Joint.leftShoulder, minConfidence);
      final rs = frame.point(Joint.rightShoulder, minConfidence);
      if (lw == null || rw == null || ls == null || rs == null) continue;
      valid++;
      if (lw.y < ls.y && rw.y < rs.y) overhead++;
    }
    return valid == 0 ? 0 : overhead / valid;
  }

  double _bodyHorizontalFraction(List<PoseFrame> frames) {
    var valid = 0, horizontal = 0;
    for (final frame in frames) {
      final shoulder = _midpoint(
        frame,
        Joint.leftShoulder,
        Joint.rightShoulder,
        1,
      );
      final hip = _midpoint(frame, Joint.leftHip, Joint.rightHip, 1);
      if (shoulder == null || hip == null) continue;
      valid++;
      if ((shoulder.x - hip.x).abs() > (shoulder.y - hip.y).abs()) {
        horizontal++;
      }
    }
    return valid == 0 ? 0 : horizontal / valid;
  }

  // MARK: 근력운동 자세 지표 (iOS ExerciseFormAnalyzer)

  _FormMetrics _formMetrics(List<PoseFrame> frames, double aspect) {
    if (frames.isEmpty) return const _FormMetrics();
    final frontalRatio = _frontalRatio(frames, aspect);
    final frontal = frontalRatio != null && frontalRatio >= 0.4;

    final elbowPerFrame = [
      for (final frame in frames) _limbAngle(frame, _arms, aspect),
    ];
    final elbowValues = elbowPerFrame.whereType<double>();
    final elbowMax = elbowValues.isEmpty ? null : elbowValues.reduce(math.max);

    final kneeDiffs = <double>[];
    final kneeMeanPerFrame = <double?>[];
    for (final frame in frames) {
      final l = _angle(frame, _legs[0], aspect);
      final r = _angle(frame, _legs[1], aspect);
      if (l != null && r != null) kneeDiffs.add((l - r).abs());
      final both = [?l, ?r];
      kneeMeanPerFrame.add(
        both.isEmpty ? null : both.reduce((a, b) => a + b) / both.length,
      );
    }

    final squatBottom = _bottomIndices(kneeMeanPerFrame);
    final armBottom = _bottomIndices(elbowPerFrame);
    final (bodyLine, sags) = _bodyLine(frames, aspect);
    return _FormMetrics(
      kneeValgusRatio: frontal
          ? _valgusRatio(frames, squatBottom, aspect)
          : null,
      kneeAsymmetry: kneeDiffs.isEmpty ? null : _mean(kneeDiffs),
      bodyLine: bodyLine,
      bodyLineSags: sags,
      shoulderAbduction: frontal
          ? _shoulderAbduction(frames, armBottom, aspect)
          : null,
      elbowMax: elbowMax,
      chinOverBar: _chinOverBar(frames, armBottom),
      swing: _swing(frames, aspect),
    );
  }

  double? _frontalRatio(List<PoseFrame> frames, double aspect) {
    final ratios = <double>[];
    for (final frame in frames) {
      final ls = _point(frame, Joint.leftShoulder, aspect);
      final rs = _point(frame, Joint.rightShoulder, aspect);
      final hip = _midpoint(frame, Joint.leftHip, Joint.rightHip, aspect);
      if (ls == null || rs == null || hip == null) continue;
      final torso = (hip.y - (ls.y + rs.y) / 2).abs();
      if (torso <= 0.02) continue;
      ratios.add((ls.x - rs.x).abs() / torso);
    }
    return _median(ratios);
  }

  static List<int> _bottomIndices(List<double?> values) {
    final indexed = [
      for (var i = 0; i < values.length; i++)
        if (values[i] case final value?) (i, value),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (indexed.isEmpty) return const [];
    final count = math.max(1, (indexed.length * 0.25).toInt());
    return [for (final (i, _) in indexed.take(count)) i];
  }

  double? _valgusRatio(
    List<PoseFrame> frames,
    List<int> indices,
    double aspect,
  ) {
    final ratios = <double>[];
    for (final i in indices) {
      final frame = frames[i];
      final lk = _point(frame, Joint.leftKnee, aspect);
      final rk = _point(frame, Joint.rightKnee, aspect);
      final la = _point(frame, Joint.leftAnkle, aspect);
      final ra = _point(frame, Joint.rightAnkle, aspect);
      if (lk == null || rk == null || la == null || ra == null) continue;
      final ankleGap = (la.x - ra.x).abs();
      if (ankleGap <= 0.02) continue;
      ratios.add((lk.x - rk.x).abs() / ankleGap);
    }
    return _median(ratios);
  }

  (double?, bool?) _bodyLine(List<PoseFrame> frames, double aspect) {
    final angles = <double>[];
    var sag = 0, pike = 0;
    for (final frame in frames) {
      final shoulder = _midpoint(
        frame,
        Joint.leftShoulder,
        Joint.rightShoulder,
        aspect,
      );
      final hip = _midpoint(frame, Joint.leftHip, Joint.rightHip, aspect);
      final knee = _midpoint(frame, Joint.leftKnee, Joint.rightKnee, aspect);
      if (shoulder == null || hip == null || knee == null) continue;
      angles.add(_vertexAngle(shoulder, hip, knee));
      final dx = knee.x - shoulder.x;
      if (dx.abs() <= 0.02) continue;
      final lineY =
          shoulder.y + (hip.x - shoulder.x) / dx * (knee.y - shoulder.y);
      hip.y > lineY ? sag++ : pike++;
    }
    if (angles.isEmpty) return (null, null);
    return (_mean(angles), sag + pike == 0 ? null : sag >= pike);
  }

  double? _shoulderAbduction(
    List<PoseFrame> frames,
    List<int> indices,
    double aspect,
  ) {
    final angles = <double>[
      for (final i in indices)
        for (final side in _shoulders) ?_angle(frames[i], side, aspect),
    ];
    return angles.isEmpty ? null : _mean(angles);
  }

  bool? _chinOverBar(List<PoseFrame> frames, List<int> indices) {
    var over = 0, total = 0;
    for (final i in indices) {
      final nose = frames[i].point(Joint.nose, minConfidence);
      final wrists = [
        ?frames[i].point(Joint.leftWrist, minConfidence),
        ?frames[i].point(Joint.rightWrist, minConfidence),
      ];
      if (nose == null || wrists.isEmpty) continue;
      total++;
      if (nose.y < _mean([for (final wrist in wrists) wrist.y])) over++;
    }
    return total == 0 ? null : over * 2 >= total;
  }

  double? _swing(List<PoseFrame> frames, double aspect) {
    final xs = <double>[];
    final torsos = <double>[];
    for (final frame in frames) {
      final hip = _midpoint(frame, Joint.leftHip, Joint.rightHip, aspect);
      final shoulder = _midpoint(
        frame,
        Joint.leftShoulder,
        Joint.rightShoulder,
        aspect,
      );
      if (hip == null || shoulder == null) continue;
      xs.add(hip.x);
      torsos.add((hip.y - shoulder.y).abs());
    }
    final torso = _median(torsos);
    if (xs.length < 4 || torso == null || torso <= 0.02) return null;
    return (xs.reduce(math.max) - xs.reduce(math.min)) / torso;
  }

  // MARK: 코칭

  List<CoachingTip> _armTips(
    ExerciseType type,
    int reps,
    double? elbowMin,
    int analyzed,
    _FormMetrics form,
  ) {
    final pullUp = type == ExerciseType.pullUp;
    return [
      if (analyzed < 10) _insufficientFrames,
      CoachingTip(
        title: '반복 횟수',
        message: '${pullUp ? '풀업' : '푸시업'} $reps회를 완료했어요.',
      ),
      if (elbowMin != null)
        elbowMin > 105
            ? CoachingTip(
                title: '가동 범위',
                message: pullUp
                    ? '가동범위가 좁아요(최저 팔꿈치 ${elbowMin.round()}°). 턱이 바 위로 오도록 더 당겨 올라가세요.'
                    : '가동범위가 좁아요(최저 팔꿈치 ${elbowMin.round()}°). 가슴이 바닥에 가까워지도록 더 내려가세요.',
                isWarning: true,
              )
            : CoachingTip(
                title: '가동 범위',
                message: pullUp
                    ? '충분히 당겨 올라갔어요(최저 팔꿈치 ${elbowMin.round()}°). 좋습니다.'
                    : '충분히 내려갔어요(최저 팔꿈치 ${elbowMin.round()}°). 좋습니다.',
              ),
      if (!pullUp) ...[
        if (form.bodyLine case final line?)
          line < 165
              ? CoachingTip(
                  title: '몸통 라인',
                  message: form.bodyLineSags ?? true
                      ? '엉덩이가 처졌어요(몸통 ${line.round()}°). 배와 엉덩이에 힘을 줘 머리-엉덩이-발을 일직선으로 유지하세요.'
                      : '엉덩이가 솟았어요(몸통 ${line.round()}°). 골반을 내려 몸을 일직선으로 만드세요.',
                  isWarning: true,
                )
              : CoachingTip(
                  title: '몸통 라인',
                  message: '몸통이 일직선으로 잘 유지됐어요(${line.round()}°).',
                ),
        if (form.shoulderAbduction case final abduction?)
          abduction > 75
              ? CoachingTip(
                  title: '몸통 라인',
                  message:
                      '팔꿈치가 너무 벌어졌어요(${abduction.round()}°). 몸통과 45° 정도가 되도록 붙여주세요.',
                  isWarning: true,
                )
              : CoachingTip(
                  title: '몸통 라인',
                  message: '팔꿈치 각도가 적절해요(${abduction.round()}°).',
                ),
        if (form.elbowMax case final maxElbow? when maxElbow < 160)
          CoachingTip(
            title: '락아웃',
            message: '상단에서 팔을 끝까지 펴세요(최대 ${maxElbow.round()}°).',
            isWarning: true,
          ),
      ] else ...[
        if (form.chinOverBar case final chin?)
          chin
              ? const CoachingTip(title: '락아웃', message: '턱이 바 위로 잘 올라왔어요.')
              : const CoachingTip(
                  title: '락아웃',
                  message: '턱이 바 위로 올라오지 않았어요. 가슴을 바에 가깝게 당겨 올라가세요.',
                  isWarning: true,
                ),
        if (form.elbowMax case final maxElbow? when maxElbow < 160)
          CoachingTip(
            title: '락아웃',
            message:
                '하단에서 팔을 완전히 펴세요(최대 ${maxElbow.round()}°). 데드행에서 시작하면 가동범위가 온전해집니다.',
            isWarning: true,
          ),
        if (form.swing case final swing? when swing > 0.3)
          const CoachingTip(
            title: '반동',
            message: '반동(킥핑)이 커요. 몸의 흔들림을 줄이고 등 근육으로 당겨보세요.',
            isWarning: true,
          ),
      ],
    ];
  }

  List<CoachingTip> _squatTips(
    int reps,
    double? depth,
    double? forwardLean,
    int analyzed,
    _FormMetrics form,
  ) => [
    if (analyzed < 10) _insufficientFrames,
    CoachingTip(title: '반복 횟수', message: '스쿼트 $reps회를 완료했어요.'),
    if (depth != null)
      depth > 120
          ? CoachingTip(
              title: '깊이',
              message:
                  '깊이가 얕아요(최저 ${depth.round()}°). 허벅지가 수평에 가까워지도록 더 앉아 보세요.',
              isWarning: true,
            )
          : CoachingTip(
              title: '깊이',
              message: depth >= 80
                  ? '적절한 깊이예요(최저 ${depth.round()}°). 좋습니다.'
                  : '아주 깊게 앉았어요(최저 ${depth.round()}°). 무릎·허리에 무리가 없다면 좋아요.',
            ),
    if (forwardLean != null)
      forwardLean.abs() > 50
          ? CoachingTip(
              title: '상체 기울기',
              message:
                  '상체가 너무 많이 숙여졌어요(${forwardLean.abs().round()}°). 가슴을 세우고 시선을 정면으로 두세요.',
              isWarning: true,
            )
          : CoachingTip(
              title: '상체 기울기',
              message: '상체 각도가 안정적이에요(${forwardLean.abs().round()}°).',
            ),
    if (form.kneeValgusRatio case final ratio?)
      ratio < 0.85
          ? const CoachingTip(
              title: '무릎 정렬',
              message: '무릎이 안쪽으로 모여요. 무릎을 발끝 방향으로 밀어내며 앉으세요.',
              isWarning: true,
            )
          : const CoachingTip(
              title: '무릎 정렬',
              message: '무릎이 발끝 방향으로 잘 정렬돼 있어요.',
            ),
    if (form.kneeAsymmetry case final asymmetry? when asymmetry > 15)
      CoachingTip(
        title: '무릎 정렬',
        message: '좌우 무릎 각도 차이가 커요(${asymmetry.round()}°). 양발에 체중을 균등하게 실어보세요.',
        isWarning: true,
      ),
  ];

  List<CoachingTip> _locomotionTips({
    required ExerciseType type,
    required _Tier tier,
    required double? cadence,
    required double? forwardLean,
    required bool directionKnown,
    required double? avgKnee,
    required double? avgHipFlexion,
    required int analyzed,
  }) {
    final walking = type == ExerciseType.walking;
    final tips = <CoachingTip>[
      if (analyzed < 10) _insufficientFrames,
      cadence == null
          ? const CoachingTip(
              title: '케이던스',
              message: '케이던스를 측정하기엔 영상이 짧거나 상하 움직임이 약해요.',
              isWarning: true,
            )
          : _cadenceTip(tier, cadence),
    ];
    if (forwardLean != null) {
      final deg = forwardLean.abs().round();
      final (message, warning) = !directionKnown
          ? ('진행 방향을 알 수 없어 전/후 기울기 판별이 어려워요(기울기 약 $deg°).', true)
          : walking
          ? forwardLean < -2
                ? ('상체가 뒤로 젖혀져 허리에 부담이 갈 수 있어요(약 $deg°). 척추를 곧게 세우세요.', true)
                : forwardLean <= 5
                ? ('바른 척추 정렬과 상체 자세를 유지하고 있어요(약 $deg°).', false)
                : ('상체를 앞으로 숙였어요(약 $deg°). 시선을 정면에 두고 턱을 가볍게 당기세요.', true)
          : forwardLean < -3
          ? ('상체가 뒤로 젖혀져 있어요(약 $deg°). 발목부터 살짝 앞으로 기울여보세요.', true)
          : forwardLean < 3
          ? ('상체가 곧게 서 있어요. 5~10° 정도 앞으로 기울이면 추진에 유리해요.', true)
          : forwardLean <= 12
          ? ('상체 기울기 좋아요(약 $deg°).', false)
          : ('상체를 너무 숙였어요(약 $deg°). 허리가 아닌 발목부터 기울이세요.', true);
      tips.add(
        CoachingTip(title: '상체 기울기', message: message, isWarning: warning),
      );
    }
    if (walking) {
      if (avgKnee != null) {
        tips.add(
          avgKnee > 172
              ? CoachingTip(
                  title: '무릎',
                  message:
                      '무릎 관절을 과도하게 펴서(락킹) 걸을 수 있어요(평균 ${avgKnee.round()}°). 부드럽게 디뎌주세요.',
                  isWarning: true,
                )
              : CoachingTip(
                  title: '무릎',
                  message: '자연스러운 무릎 관절 가동 범위입니다(평균 ${avgKnee.round()}°).',
                ),
        );
      }
      if (avgHipFlexion != null && avgHipFlexion > 165) {
        tips.add(
          const CoachingTip(
            title: '고관절',
            message: '보폭이 다소 좁을 수 있어요. 골반을 부드럽게 회전하며 뒤쪽 발끝으로 가볍게 밀어내세요.',
            isWarning: true,
          ),
        );
      }
    } else {
      if (avgKnee != null && avgKnee > 165) {
        tips.add(
          CoachingTip(
            title: '무릎',
            message: '무릎 굽힘이 적어요(평균 ${avgKnee.round()}°). 무릎을 조금 더 들어 추진하세요.',
            isWarning: true,
          ),
        );
      }
      if (avgHipFlexion != null && avgHipFlexion > 165) {
        tips.add(
          CoachingTip(
            title: '고관절',
            message:
                '고관절 굽힘이 적어요(평균 ${avgHipFlexion.round()}°). 다리를 뒤로 보내기보다 골반 아래에서 회수해 보세요.',
            isWarning: true,
          ),
        );
      }
    }
    return tips;
  }

  static CoachingTip _cadenceTip(_Tier tier, double cadence) {
    final spm = cadence.round();
    final (message, warning) = switch (tier) {
      _Tier.walking when cadence < 95 => (
        '보행 속도가 다소 느려요(약 $spm spm). 105~125 spm으로 리듬감 있게 걸어보세요.',
        true,
      ),
      _Tier.walking when cadence <= 135 => (
        '적절하고 활기찬 걷기 케이던스입니다(약 $spm spm).',
        false,
      ),
      _Tier.walking => ('빠른 파워 워킹 케이던스입니다(약 $spm spm).', false),
      _Tier.jogging when cadence < 150 => (
        '가벼운 조깅이에요(약 $spm spm). 보폭을 줄이고 회전수를 155~170으로 올리면 부담이 줄어요.',
        true,
      ),
      _Tier.jogging => ('편안한 조깅 케이던스입니다(약 $spm spm). 리듬을 유지하세요.', false),
      _Tier.running when cadence < 165 => (
        '케이던스가 낮아요(약 $spm spm). 보폭을 줄이고 회전수를 170~180으로 올려보세요.',
        true,
      ),
      _Tier.running when cadence <= 190 => ('러닝 케이던스 양호(약 $spm spm).', false),
      _Tier.running => ('러닝 케이던스 높음(약 $spm spm).', false),
      _Tier.sprinting => (
        '스프린트 고회전 케이던스입니다(약 $spm spm). 짧고 강하게, 상체 안정과 팔치기에 집중하세요.',
        false,
      ),
    };
    return CoachingTip(title: '케이던스', message: message, isWarning: warning);
  }

  static const _insufficientFrames = CoachingTip(
    title: '데이터',
    message: '분석 프레임이 부족합니다. 옆모습으로 더 길게 촬영해 주세요.',
    isWarning: true,
  );

  // MARK: 기하 헬퍼

  static const _legs = [
    (Joint.leftHip, Joint.leftKnee, Joint.leftAnkle),
    (Joint.rightHip, Joint.rightKnee, Joint.rightAnkle),
  ];
  static const _arms = [
    (Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist),
    (Joint.rightShoulder, Joint.rightElbow, Joint.rightWrist),
  ];
  static const _torsoLegs = [
    (Joint.leftShoulder, Joint.leftHip, Joint.leftKnee),
    (Joint.rightShoulder, Joint.rightHip, Joint.rightKnee),
  ];
  static const _shoulders = [
    (Joint.leftHip, Joint.leftShoulder, Joint.leftElbow),
    (Joint.rightHip, Joint.rightShoulder, Joint.rightElbow),
  ];

  static double _seconds(PoseFrame frame) =>
      frame.timestamp.inMicroseconds / Duration.microsecondsPerSecond;

  _Point? _point(PoseFrame frame, Joint joint, double aspect) {
    final point = frame.point(joint, minConfidence);
    return point == null ? null : _Point(point.x * aspect, point.y);
  }

  /// 좌/우 중 신뢰도 있는 관절들의 평균점.
  _Point? _midpoint(PoseFrame frame, Joint a, Joint b, double aspect) {
    final points = [?_point(frame, a, aspect), ?_point(frame, b, aspect)];
    if (points.isEmpty) return null;
    return _Point(
      _mean([for (final p in points) p.x]),
      _mean([for (final p in points) p.y]),
    );
  }

  double? _angle(PoseFrame frame, (Joint, Joint, Joint) joints, double aspect) {
    final a = _point(frame, joints.$1, aspect);
    final b = _point(frame, joints.$2, aspect);
    final c = _point(frame, joints.$3, aspect);
    return a == null || b == null || c == null ? null : _vertexAngle(a, b, c);
  }

  /// 신뢰도 있는 좌/우 각도의 평균.
  double? _limbAngle(
    PoseFrame frame,
    List<(Joint, Joint, Joint)> sides,
    double aspect,
  ) {
    final angles = [for (final side in sides) ?_angle(frame, side, aspect)];
    return angles.isEmpty ? null : _mean(angles);
  }

  /// 정점 b에서의 내각(도).
  static double _vertexAngle(_Point a, _Point b, _Point c) {
    final u = _Point(a.x - b.x, a.y - b.y);
    final v = _Point(c.x - b.x, c.y - b.y);
    if (u.length == 0 || v.length == 0) return 0;
    final cos = ((u.x * v.x + u.y * v.y) / (u.length * v.length)).clamp(-1, 1);
    return math.acos(cos) * 180 / math.pi;
  }

  static double _mean(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;

  double get length => math.sqrt(x * x + y * y);
}

class _FormMetrics {
  const _FormMetrics({
    this.kneeValgusRatio,
    this.kneeAsymmetry,
    this.bodyLine,
    this.bodyLineSags,
    this.shoulderAbduction,
    this.elbowMax,
    this.chinOverBar,
    this.swing,
  });

  final double? kneeValgusRatio;
  final double? kneeAsymmetry;
  final double? bodyLine;
  final bool? bodyLineSags;
  final double? shoulderAbduction;
  final double? elbowMax;
  final bool? chinOverBar;
  final double? swing;
}

/// 케이던스 기반 이동 강도 티어 (케이던스 오름차순).
enum _Tier {
  walking('걷기'),
  jogging('조깅'),
  running('러닝'),
  sprinting('스프린트');

  const _Tier(this.label);

  final String label;

  static _Tier forCadence(double cadence) => cadence < 135
      ? walking
      : cadence < 160
      ? jogging
      : cadence < 190
      ? running
      : sprinting;
}
