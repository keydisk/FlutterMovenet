import 'package:flutter/material.dart';
import 'package:movenet_domain/movenet_domain.dart';

import 'analysis_result_card.dart';

class HistoryTile extends StatelessWidget {
  const HistoryTile({required this.record, super.key});

  final AnalysisRecord record;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
      title: Text(record.fileName),
      subtitle: Text(
        '${record.result.exercise.label} · ${record.result.repetitions}회'
        '${record.result.riskEvents > 0 ? ' · 위험 ${record.result.riskEvents}건' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [AnalysisResultCard(record: record)],
          ),
        ),
      ),
    ),
  );
}
