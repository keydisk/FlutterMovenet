import 'package:flutter/material.dart';
import 'package:movenet_core/movenet_core.dart';
import 'package:movenet_domain/movenet_domain.dart';

class AnalysisResultCard extends StatelessWidget {
  const AnalysisResultCard({required this.record, super.key});

  final AnalysisRecord record;

  @override
  Widget build(BuildContext context) {
    final result = record.result;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.exercise.label} · ${result.repetitions}회',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('영상 전체 ${result.duration.inSeconds}초 분석'),
          if (result.riskEvents > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                label: Text('위험 자세 ${result.riskEvents}건 감지'),
              ),
            ),
          const SizedBox(height: 12),
          if (result.isCertain)
            Chip(
              label: Text(
                '${result.exercise.label} ${(result.probabilities[result.exercise]! * 100).round()}% 확실',
              ),
            )
          else ...[
            Text('운동별 확률', style: Theme.of(context).textTheme.titleMedium),
            for (final entry
                in result.probabilities.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
              Row(
                children: [
                  Expanded(child: Text(entry.key.label)),
                  Text('${(entry.value * 100).round()}%'),
                ],
              ),
          ],
          if (result.runningMetrics case final metrics?) ...[
            const Divider(height: 28),
            Text('러닝·보행 지표', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${metrics.cadence.round()} SPM')),
                Chip(
                  label: Text('상체 ${metrics.trunkLean.toStringAsFixed(1)}°'),
                ),
                Chip(
                  label: Text('무릎 ${metrics.kneeAngle.toStringAsFixed(1)}°'),
                ),
                Chip(
                  label: Text('고관절 ${metrics.hipMobility.toStringAsFixed(1)}°'),
                ),
              ],
            ),
          ],
          const Divider(height: 28),
          Text('맞춤 코칭', style: Theme.of(context).textTheme.titleMedium),
          for (final tip in result.coaching)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tips_and_updates_outlined),
              title: Text(tip.title),
              subtitle: Text(tip.message),
            ),
        ],
      ),
    );
  }
}
