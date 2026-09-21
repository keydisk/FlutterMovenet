import 'dart:io';

import 'package:flutter/material.dart';
import 'package:movenet_domain/movenet_domain.dart';

/// iOS 앱 RunningFormReportView와 같은 구성의 리포트 카드.
/// 헤더(제목 + 유형 뱃지 + 분석 프레임 수) → 지표 그리드 → 위험 각도 → 코칭 피드백.
class ReportCard extends StatelessWidget {
  const ReportCard({required this.result, super.key});

  final AnalysisResult result;

  static const _walkingAccent = Color(0xFF30B0C7);
  static const _weightAccent = Color(0xFFAF52DE);
  static const _cardioAccent = Color(0xFF0A84FF);
  static const _warning = Color(0xFFFF9F0A);
  static const _good = Color(0xFF30D158);
  static const _critical = Color(0xFFFF453A);

  Color get _accent => switch (result.exercise) {
    ExerciseType.walking => _walkingAccent,
    ExerciseType.squat ||
    ExerciseType.pullUp ||
    ExerciseType.pushUp => _weightAccent,
    _ => _cardioAccent,
  };

  String get _title => switch (result.exercise) {
    ExerciseType.squat ||
    ExerciseType.pullUp ||
    ExerciseType.pushUp => '웨이트 자세 분석',
    ExerciseType.walking || ExerciseType.running => '러닝·걷기 자세 분석',
    ExerciseType.unknown => '자세 분석',
  };

  @override
  Widget build(BuildContext context) {
    final analyzed = Text(
      '${result.analyzedFrames}프레임 분석',
      style: const TextStyle(fontSize: 11, color: Colors.grey),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.candidates.isNotEmpty)
            _candidates(analyzed)
          else ...[
            Row(
              children: [
                Icon(
                  exerciseIcon(result.exercise),
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _badge(
                          result.locomotionSummary ?? result.exercise.label,
                          _accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                analyzed,
              ],
            ),
            const SizedBox(height: 12),
            _metricGrid(),
          ],
          if (result.risks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: _warning,
                ),
                const SizedBox(width: 6),
                const Text(
                  '주의가 필요한 위험 각도',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _warning,
                  ),
                ),
                const Spacer(),
                _badge('${result.risks.length}건 감지', _warning),
              ],
            ),
            const SizedBox(height: 8),
            for (final risk in result.risks) ...[
              _riskCard(risk),
              const SizedBox(height: 8),
            ],
          ],
          if (result.coaching.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '코칭 피드백',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            for (final tip in result.coaching)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      tip.isWarning
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle,
                      size: 14,
                      color: tip.isWarning ? _warning : _good,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tip.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: tip.isWarning
                              ? Colors.white.withValues(alpha: 0.9)
                              : _good,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _metricGrid() {
    String degrees(double? value) => value == null ? '–' : '${value.round()}°';
    final metrics = result.runningMetrics;
    final cards = switch (result.exercise) {
      ExerciseType.squat => [
        ('반복 횟수', '${result.repetitions}회', Icons.tag),
        ('최저 깊이', degrees(result.depthDegrees), Icons.vertical_align_bottom),
        ('상체 기울기', degrees(metrics?.trunkLean), Icons.accessibility_new),
        ('무릎 각도', degrees(metrics?.kneeAngle), Icons.architecture),
      ],
      ExerciseType.pullUp || ExerciseType.pushUp => [
        ('반복 횟수', '${result.repetitions}회', Icons.tag),
        ('최저 팔꿈치각', degrees(result.depthDegrees), Icons.architecture),
      ],
      _ => [
        (
          '케이던스',
          metrics?.cadence == null ? '–' : '${metrics!.cadence!.round()} spm',
          Icons.av_timer,
        ),
        ('상체 기울기', degrees(metrics?.trunkLean), Icons.directions_walk),
        ('무릎 각도', degrees(metrics?.kneeAngle), Icons.architecture),
        ('고관절 각도', degrees(metrics?.hipFlexion), Icons.swap_horiz),
      ],
    };
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.7,
      children: [
        for (final (title, value, icon) in cards)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 11, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _candidates(Widget analyzed) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.help, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          const Text(
            '감지된 운동 후보',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          analyzed,
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        '동작이 명확하지 않아 후보를 추정했어요. 옆모습으로 더 길게 촬영하면 정확해집니다.',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      ),
      const SizedBox(height: 10),
      for (final (index, candidate) in result.candidates.indexed)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _weightAccent.withValues(
                    alpha: index == 0 ? 0.9 : 0.4,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                candidate.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${(candidate.confidence * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  /// iOS RiskAngleSnapshotCardView와 같은 구성(스냅샷 이미지는 없어 시각·경고 아이콘 박스로 대체).
  Widget _riskCard(RiskEvent risk) {
    final color = risk.critical ? _critical : _warning;
    final time = _timestamp(risk.timestamp);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: risk.critical ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: risk.critical ? 0.6 : 0.5),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: switch (risk.imagePath) {
              final path? when File(path).existsSync() => Image.file(
                File(path),
                fit: BoxFit.cover,
              ),
              _ => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 24, color: _warning),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${risk.degrees.round()}°',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      risk.critical
                          ? Icons.dangerous
                          : Icons.warning_amber_rounded,
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      risk.critical ? '위험' : '주의',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  risk.joint.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  risk.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// iOS RiskPoseSnapshot.formattedTimestamp와 동일한 "0:12.4" 형식.
  static String _timestamp(Duration time) =>
      '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}'
      '.${(time.inMilliseconds % 1000) ~/ 100}';

  static Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
    ),
  );

  static IconData exerciseIcon(ExerciseType type) => switch (type) {
    ExerciseType.walking => Icons.directions_walk,
    ExerciseType.running => Icons.directions_run,
    ExerciseType.squat => Icons.fitness_center,
    ExerciseType.pullUp => Icons.sports_gymnastics,
    ExerciseType.pushUp => Icons.self_improvement,
    ExerciseType.unknown => Icons.accessibility_new,
  };

  static Color accentFor(ExerciseType type) => switch (type) {
    ExerciseType.walking => _walkingAccent,
    ExerciseType.squat ||
    ExerciseType.pullUp ||
    ExerciseType.pushUp => _weightAccent,
    _ => _cardioAccent,
  };

  static const warningColor = _warning;
}
