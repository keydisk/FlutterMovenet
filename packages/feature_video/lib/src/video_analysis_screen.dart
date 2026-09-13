import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analysis_result_card.dart';
import 'history_tile.dart';
import 'video_analysis_controller.dart';
import 'video_preview.dart';

class VideoAnalysisScreen extends ConsumerWidget {
  const VideoAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(videoAnalysisControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('영상 분석')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: analysis.value?.isAnalyzing == true
            ? null
            : () => ref
                  .read(videoAnalysisControllerProvider.notifier)
                  .chooseAndAnalyze(),
        icon: const Icon(Icons.video_library_outlined),
        label: const Text('영상 선택'),
      ),
      body: analysis.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('분석하지 못했습니다: $error'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(videoAnalysisControllerProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (value) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                if (value.isAnalyzing) ...[
                  LinearProgressIndicator(value: value.progress),
                  const SizedBox(height: 8),
                  Text('영상 전체 분석 중 ${(value.progress * 100).round()}%'),
                ],
                if (value.selectedPath != null) ...[
                  VideoPreview(path: value.selectedPath!),
                  const SizedBox(height: 16),
                ],
                if (value.latest != null) ...[
                  AnalysisResultCard(record: value.latest!),
                  const SizedBox(height: 28),
                ],
                Text(
                  '분석 히스토리 ${value.history.length}개',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (value.history.isEmpty) const Text('아직 분석 기록이 없습니다.'),
                for (final record in value.history) ...[
                  HistoryTile(record: record),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
