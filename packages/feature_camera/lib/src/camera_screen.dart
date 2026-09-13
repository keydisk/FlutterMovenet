import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movenet_core/movenet_core.dart';

import 'camera_analysis_state.dart';
import 'camera_session.dart';
import 'pose_painter.dart';

class CameraScreen extends ConsumerWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cameraSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('실시간 자세 분석')),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error'),
          ),
        ),
        data: (value) => _CameraContent(
          value: value,
          controller: ref.read(cameraSessionProvider.notifier).controller,
        ),
      ),
    );
  }
}

class _CameraContent extends StatelessWidget {
  const _CameraContent({required this.value, required this.controller});

  final CameraAnalysisState value;
  final CameraController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 700;
      final preview = _preview();
      final report = _report(context);
      return wide
          ? Row(
              children: [
                Expanded(flex: 3, child: preview),
                Expanded(flex: 2, child: report),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 3, child: preview),
                Expanded(flex: 2, child: report),
              ],
            );
    },
  );

  Widget _preview() => ColoredBox(
    color: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
        if (value.showSkeleton && value.pose != null)
          CustomPaint(
            painter: PosePainter(value.pose!, value.minimumConfidence),
          ),
        if (value.showFps)
          Positioned(
            top: 12,
            right: 12,
            child: Chip(label: Text('${value.fps.toStringAsFixed(1)} FPS')),
          ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Chip(
            avatar: const Icon(Icons.repeat, size: 18),
            label: Text('${value.exercise.label} ${value.repetitions}회'),
          ),
        ),
      ],
    ),
  );

  Widget _report(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        '${value.exercise.label} · ${value.repetitions}회',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      for (final tip in value.coaching)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tip.title),
              subtitle: Text(tip.message),
            ),
          ),
        ),
      if (value.probabilities.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('운동 확률', style: Theme.of(context).textTheme.titleMedium),
        for (final entry in value.probabilities.entries)
          Row(
            children: [
              Expanded(child: Text(entry.key.label)),
              Text('${(entry.value * 100).round()}%'),
            ],
          ),
      ],
    ],
  );
}
