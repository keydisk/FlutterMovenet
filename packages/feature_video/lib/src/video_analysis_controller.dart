import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:movenet_data/movenet_data.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'pose_track.dart';
import 'video_analysis_state.dart';

part 'video_analysis_controller.g.dart';

@riverpod
class VideoAnalysisController extends _$VideoAnalysisController {
  final _history = AnalysisStorage();
  final _settings = SettingsStorage();
  final _storage = VideoStorage();
  final _poseTracks = const PoseTrackStorage();
  final _analyzer = const FormAnalyzer();
  final _classifier = const ExerciseClassifier();

  @override
  Future<VideoAnalysisState> build() async =>
      VideoAnalysisState(history: await _history.load());

  Future<void> chooseAndAnalyze() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final videoPath = await _storage.persist(picked.path);
    final now = DateTime.now();
    await _analyze(
      videoPath,
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
    );
  }

  /// 예전에 저장된(섬네일·위험 스냅샷이 없는) 기록을 같은 영상으로 다시 분석해 채운다.
  Future<void> reanalyze(AnalysisRecord record) =>
      _analyze(record.videoPath, id: record.id, createdAt: record.createdAt);

  Future<void> _analyze(
    String videoPath, {
    required String id,
    required DateTime createdAt,
  }) async {
    state = AsyncData(
      state.requireValue.copyWith(isAnalyzing: true, progress: 0),
    );
    VideoAnalysisReader? reader;
    try {
      final settings = await _settings.load();
      // 영상 전체를 순차 디코드(15fps)하며 MoveNet MultiPose로 프레임별 포즈를 모은다.
      reader = await VideoAnalysisReader.open(videoPath);
      final frames = <PoseFrame>[];
      final risks = RiskDetector(minConfidence: settings.minimumConfidence);
      var processed = 0;
      String? thumbnailPath;
      for (
        var sample = await reader.next();
        sample != null;
        sample = await reader.next()
      ) {
        if (sample.pose case final pose?) {
          frames.add(pose);
          // iOS 사전분석과 동일하게 위험이 감지된 그 프레임을 스냅샷으로 남긴다.
          for (final risk in risks.add(pose)) {
            risks.attachImage(risk, await reader.snapshot());
          }
        }
        thumbnailPath ??= sample.thumbnailPath;
        processed++;
        state = AsyncData(
          state.requireValue.copyWith(
            progress: (processed / reader.estimatedFrameCount).clamp(0, 1),
          ),
        );
      }
      // 모아 둔 클립으로 MoViNet이 운동 종류를 판별한다(실패하면 자세 규칙으로 폴백).
      final logits = await reader.classify();
      final classification = logits == null
          ? null
          : _classifier.classify(logits, await KineticsLabels.load());
      final record = AnalysisRecord(
        id: id,
        videoPath: videoPath,
        createdAt: createdAt,
        thumbnailPath: thumbnailPath,
        result: _analyzer.analyze(
          frames,
          duration: reader.duration,
          aspectRatio: reader.aspectRatio,
          risks: risks.events,
          classification: classification,
        ),
      );
      await _history.save(record);
      // 재생 중 관절·각도 오버레이용으로 프레임별 포즈를 영상 옆에 남긴다.
      await _poseTracks.save(videoPath, frames);
      ref.invalidate(poseTrackProvider(videoPath));
      final current = state.requireValue;
      state = AsyncData(
        current.copyWith(
          history: [
            record,
            for (final item in current.history)
              if (item.id != record.id) item,
          ],
          isAnalyzing: false,
          progress: 1,
          selectedPath: videoPath,
          latest: record,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } finally {
      await reader?.close();
    }
  }

  Future<void> deleteRecord(AnalysisRecord record) async {
    final current = state.requireValue;
    final wasLatest = current.latest?.id == record.id;
    state = AsyncData(
      current.copyWith(
        history: [
          for (final item in current.history)
            if (item.id != record.id) item,
        ],
        latest: wasLatest ? null : current.latest,
        selectedPath: current.selectedPath == record.videoPath
            ? null
            : current.selectedPath,
      ),
    );
    await _history.remove(record.id);
    await _poseTracks.delete(record.videoPath);
    await _storage.delete(record.videoPath);
  }

  /// 히스토리 항목을 선택해 영상과 리포트를 보여준다.
  Future<void> selectRecord(AnalysisRecord record) async {
    // 섬네일·포즈 트랙이 없는 예전 기록은 같은 영상으로 다시 분석해 채운다.
    // 분석이 끝난 뒤에 영상을 띄운다: 분석이 같은 파일을 디코드하는 동안 플레이어를 열면
    // 기기에서 플레이어가 멈춘 채로 남을 수 있다.
    if (File(record.videoPath).existsSync() &&
        (record.thumbnailPath == null ||
            !await _poseTracks.exists(record.videoPath))) {
      await reanalyze(record);
      return;
    }
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(selectedPath: record.videoPath, latest: record),
    );
  }

  /// 선택을 해제해 목록 화면으로 돌아간다.
  void clearSelection() {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(selectedPath: null, latest: null, progress: 0),
    );
  }
}
