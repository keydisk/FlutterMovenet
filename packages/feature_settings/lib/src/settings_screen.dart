import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movenet_core/movenet_core.dart';

import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('분석 설정')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('설정을 불러오지 못했습니다: $error')),
        data: (value) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SectionCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('스켈레톤 표시'),
                        value: value.showSkeleton,
                        onChanged: (enabled) => ref
                            .read(settingsControllerProvider.notifier)
                            .saveChanged(
                              (current) =>
                                  current.copyWith(showSkeleton: enabled),
                            ),
                      ),
                      SwitchListTile(
                        title: const Text('FPS 표시'),
                        value: value.showFps,
                        onChanged: (enabled) => ref
                            .read(settingsControllerProvider.notifier)
                            .saveChanged(
                              (current) => current.copyWith(showFps: enabled),
                            ),
                      ),
                      SwitchListTile(
                        title: const Text('전면 카메라 사용'),
                        subtitle: const Text('꺼짐: 후면 카메라'),
                        value: value.useFrontCamera,
                        onChanged: (enabled) => ref
                            .read(settingsControllerProvider.notifier)
                            .saveChanged(
                              (current) =>
                                  current.copyWith(useFrontCamera: enabled),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '관절 신뢰도 ${(value.minimumConfidence * 100).round()}%',
                      ),
                      Slider(
                        value: value.minimumConfidence,
                        min: 0.2,
                        max: 0.8,
                        divisions: 12,
                        onChanged: (confidence) => ref
                            .read(settingsControllerProvider.notifier)
                            .saveChanged(
                              (current) => current.copyWith(
                                minimumConfidence: confidence,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
