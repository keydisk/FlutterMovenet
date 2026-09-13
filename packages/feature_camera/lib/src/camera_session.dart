import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:movenet_data/movenet_data.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'camera_analysis_state.dart';

part 'camera_session.g.dart';

@riverpod
class CameraSession extends _$CameraSession {
  final _analyzer = const MovementAnalyzer();
  final _counter = RepCounter();
  final _detector = PoseDetectorService();
  CameraController? _controller;
  bool _busy = false;
  bool _disposed = false;
  DateTime? _lastFrame;
  Map<ExerciseType, double> _smoothed = const {};

  CameraController get controller => _controller!;

  @override
  Future<CameraAnalysisState> build() async {
    ref.onDispose(() {
      _disposed = true;
      unawaited(_controller?.dispose());
      unawaited(_detector.close());
    });
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('카메라 자세 분석은 Android/iOS에서 지원합니다.');
    }
    final settings = await ref.watch(settingsControllerProvider.future);
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('사용 가능한 카메라가 없습니다.');
    final direction = settings.useFrontCamera
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final camera =
        cameras.where((item) => item.lensDirection == direction).firstOrNull ??
        cameras.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );
    _controller = controller;
    await controller.initialize();
    final initial = CameraAnalysisState(
      exercise: ExerciseType.unknown,
      probabilities: const {},
      repetitions: 0,
      coaching: const [],
      showSkeleton: settings.showSkeleton,
      showFps: settings.showFps,
      minimumConfidence: settings.minimumConfidence,
    );
    await controller.startImageStream(_processFrame);
    return initial;
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_busy || _disposed || state.value == null) return;
    _busy = true;
    try {
      final now = DateTime.now();
      final pose = await _detector.detectCameraImage(
        image: image,
        camera: controller.description,
        orientation: controller.value.deviceOrientation,
        timestamp: Duration(milliseconds: now.millisecondsSinceEpoch),
      );
      if (pose == null || _disposed) return;
      _counter.add(pose);
      _smoothed = _smooth(_smoothed, _analyzer.classify(pose));
      final exercise = _smoothed.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      final elapsed = _lastFrame == null
          ? null
          : now.difference(_lastFrame!).inMilliseconds;
      _lastFrame = now;
      state = AsyncData(
        state.requireValue.copyWith(
          exercise: exercise,
          probabilities: _smoothed,
          repetitions: _counter.count(exercise),
          coaching: _analyzer.coachingFor(exercise, pose),
          pose: pose,
          fps: elapsed == null || elapsed == 0 ? 0 : 1000 / elapsed,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  void resetCount() {
    for (final exercise in [
      ExerciseType.pullUp,
      ExerciseType.squat,
      ExerciseType.pushUp,
    ]) {
      _counter.reset(exercise);
    }
    if (state.value case final current?) {
      state = AsyncData(current.copyWith(repetitions: 0));
    }
  }

  Map<ExerciseType, double> _smooth(
    Map<ExerciseType, double> previous,
    Map<ExerciseType, double> next,
  ) {
    if (previous.isEmpty) return next;
    return next.map(
      (key, value) =>
          MapEntry(key, (previous[key] ?? value) * 0.75 + value * 0.25),
    );
  }
}
