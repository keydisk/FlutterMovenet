import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:movenet_data/movenet_data.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';

import 'video_analysis_state.dart';

part 'video_analysis_controller.g.dart';

@riverpod
class VideoAnalysisController extends _$VideoAnalysisController {
  final _history = AnalysisStorage();
  final _sampler = VideoFrameSampler();
  final _storage = VideoStorage();
  final _analyzer = const MovementAnalyzer();

  @override
  Future<VideoAnalysisState> build() async =>
      VideoAnalysisState(history: await _history.load());

  Future<void> chooseAndAnalyze() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isAnalyzing: true, progress: 0));
    PoseDetectorService? detector;
    VideoPlayerController? player;
    try {
      final videoPath = await _storage.persist(picked.path);
      player = VideoPlayerController.file(File(videoPath));
      await player.initialize();
      final duration = player.value.duration;
      detector = PoseDetectorService.single();
      final frames = <PoseFrame>[];
      const intervalMs = 250;
      final total = duration.inMilliseconds.clamp(intervalMs, 1 << 31);
      for (
        var timeMs = 0;
        timeMs <= duration.inMilliseconds;
        timeMs += intervalMs
      ) {
        final path = await _sampler.frame(videoPath, timeMs);
        if (path != null) {
          final frame = await detector.detectFile(
            path,
            Duration(milliseconds: timeMs),
          );
          if (frame != null) frames.add(frame);
          await File(path).delete().catchError((_) => File(path));
        }
        state = AsyncData(
          state.requireValue.copyWith(progress: (timeMs / total).clamp(0, 1)),
        );
      }
      final result = _analyzer.analyze(frames, duration);
      final record = AnalysisRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fileName: picked.name,
        videoPath: videoPath,
        createdAt: DateTime.now(),
        result: result,
      );
      await _history.prepend(record);
      state = AsyncData(
        state.requireValue.copyWith(
          history: [record, ...state.requireValue.history],
          isAnalyzing: false,
          progress: 1,
          selectedPath: videoPath,
          latest: record,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } finally {
      await detector?.close();
      await player?.dispose();
    }
  }
}
