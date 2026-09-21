import 'dart:async';

import 'package:feature_video/src/pose_track.dart';
import 'package:feature_video/src/video_analysis_controller.dart';
import 'package:feature_video/src/video_analysis_screen.dart';
import 'package:feature_video/src/video_analysis_state.dart';
import 'package:feature_video/src/video_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// 항상 초기화에 성공하는 가짜 플레이어.
class _RecordingPlatform extends VideoPlayerPlatform {
  final opened = <String>[];
  final calls = <String>[];
  final _streams = <int, StreamController<VideoEvent>>{};
  var _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final uri = options.dataSource.uri!;
    opened.add(uri);
    final id = ++_nextId;
    final events = _streams[id] = StreamController<VideoEvent>();
    scheduleMicrotask(() {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 10),
          size: const Size(1080, 1920),
        ),
      );
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async => calls.add('play:$playerId');
  @override
  Future<void> pause(int playerId) async => calls.add('pause:$playerId');
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      Texture(textureId: options.playerId);
}

class _FakeController extends VideoAnalysisController {
  _FakeController(this._state);

  final VideoAnalysisState _state;

  @override
  Future<VideoAnalysisState> build() async => _state;
}

AnalysisRecord _record() => AnalysisRecord(
  id: 'a',
  videoPath: '/tmp/a.mov',
  createdAt: DateTime(2026),
  result: const AnalysisResult(
    exercise: ExerciseType.running,
    probabilities: {ExerciseType.running: 1},
    repetitions: 0,
    coaching: [],
    duration: Duration(seconds: 10),
    riskEvents: 0,
  ),
);

Widget _app(VideoAnalysisState state) => ProviderScope(
  overrides: [
    poseTrackProvider.overrideWith((ref, path) async => null),
    videoAnalysisControllerProvider.overrideWith(() => _FakeController(state)),
  ],
  child: const MaterialApp(home: VideoAnalysisScreen()),
);

/// 화면 가로 폭 대비 영상 페이지의 왼쪽 끝 위치(0 = 제자리, 1 = 화면 밖 오른쪽).
double _videoPageOffset(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('video'))).dx /
    tester.view.physicalSize.width *
    tester.view.devicePixelRatio;

void main() {
  testWidgets('뒤로 가면 영상 페이지가 오른쪽으로 슬라이드되며 목록이 드러난다', (tester) async {
    VideoPlayerPlatform.instance = _RecordingPlatform();
    final record = _record();
    await tester.pumpWidget(
      _app(
        VideoAnalysisState(
          history: [record],
          selectedPath: record.videoPath,
          latest: record,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('앨범에서 새 영상 분석'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    // 전환 도중에는 두 페이지가 함께 있고, 영상 페이지는 제자리와 화면 밖 사이에 있다.
    expect(find.text('앨범에서 새 영상 분석'), findsOneWidget);
    final midway = _videoPageOffset(tester);
    expect(midway, greaterThan(0.05));
    expect(midway, lessThan(0.95));

    await tester.pumpAndSettle();
    expect(find.byType(VideoPreview), findsNothing);
  });

  testWidgets('기록을 고르면 영상 페이지가 오른쪽에서 밀려 들어온다', (tester) async {
    VideoPlayerPlatform.instance = _RecordingPlatform();
    final record = _record();
    await tester.pumpWidget(_app(VideoAnalysisState(history: [record])));
    await tester.pump();

    await tester.tap(find.text(record.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final midway = _videoPageOffset(tester);
    expect(midway, greaterThan(0.05));
    expect(midway, lessThan(0.95));
    expect(find.text('앨범에서 새 영상 분석'), findsOneWidget);

    // 영상 로딩 스피너가 계속 돌아 pumpAndSettle은 끝나지 않으므로 전환 시간만큼 진행한다.
    await tester.pump(const Duration(milliseconds: 400));
    expect(_videoPageOffset(tester), 0);
    expect(find.text('앨범에서 새 영상 분석'), findsNothing);
  });
}
