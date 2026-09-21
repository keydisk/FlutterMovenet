import 'dart:async';

import 'package:feature_video/src/pose_track.dart';
import 'package:feature_video/src/report_card.dart';
import 'package:feature_video/src/video_analysis_controller.dart';
import 'package:feature_video/src/video_analysis_state.dart';
import 'package:feature_video/src/video_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// 열린 파일과 재생 호출을 기록하는 가짜 플레이어. [failing] 경로는 초기화에 실패한다.
class _RecordingPlatform extends VideoPlayerPlatform {
  _RecordingPlatform({this.failing});

  final String? failing;
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
      if (failing != null && uri.endsWith(failing!)) {
        events.addError(
          PlatformException(code: 'VideoError', message: 'Cannot Decode'),
        );
      } else {
        events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 10),
            size: const Size(1080, 1920),
          ),
        );
      }
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

/// 호출할 때마다 새 인스턴스(서로 다른 기록의 결과를 흉내 낸다).
AnalysisResult _result() => AnalysisResult(
  exercise: ExerciseType.running,
  probabilities: const {ExerciseType.running: 1},
  repetitions: 0,
  coaching: const [],
  duration: const Duration(seconds: 10),
  riskEvents: 1,
  risks: const [
    RiskEvent(
      timestamp: Duration(milliseconds: 3200),
      joint: RiskJoint.leftKnee,
      degrees: 108,
      description: '왼쪽 무릎 과도한 굴곡(108°) - 관절 압박 주의',
    ),
  ],
);

/// 분석 화면처럼 영상 아래에 리포트 카드를 둔다. [shown]은 지금 선택된 기록의 결과.
Widget _screen(AnalysisResult shown, AnalysisResult card) => ProviderScope(
  overrides: [
    poseTrackProvider.overrideWith((ref, path) async => null),
    videoAnalysisControllerProvider.overrideWith(
      () => _FakeController(
        VideoAnalysisState(
          history: const [],
          selectedPath: '/tmp/a.mov',
          latest: AnalysisRecord(
            id: 'a',
            videoPath: '/tmp/a.mov',
            createdAt: DateTime(2026),
            result: shown,
          ),
        ),
      ),
    ),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 240, child: VideoPreview(path: '/tmp/a.mov')),
          Expanded(
            child: SingleChildScrollView(child: ReportCard(result: card)),
          ),
        ],
      ),
    ),
  ),
);

Widget _app(String path) => ProviderScope(
  overrides: [poseTrackProvider.overrideWith((ref, path) async => null)],
  child: MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(height: 300, child: VideoPreview(path: path)),
      ),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

void main() {
  testWidgets('탭하면 재생된다', (tester) async {
    final platform = _RecordingPlatform();
    VideoPlayerPlatform.instance = platform;
    await tester.pumpWidget(_app('/tmp/a.mov'));
    await _settle(tester);

    await tester.tap(find.byType(VideoPlayer));
    await _settle(tester);
    expect(platform.calls.last, 'play:1');
  });

  testWidgets('다른 기록을 고르면 새 영상으로 다시 연다', (tester) async {
    final platform = _RecordingPlatform();
    VideoPlayerPlatform.instance = platform;
    await tester.pumpWidget(_app('/tmp/a.mov'));
    await _settle(tester);
    await tester.pumpWidget(_app('/tmp/b.mov'));
    await _settle(tester);

    expect(platform.opened, hasLength(2));
    expect(platform.opened.last, endsWith('b.mov'));
    await tester.tap(find.byType(VideoPlayer));
    await _settle(tester);
    expect(platform.calls.last, 'play:2');
  });

  testWidgets('플레이어가 실패하면 멈춘 화면 대신 다시 불러오기를 보여 준다', (tester) async {
    final platform = _RecordingPlatform(failing: 'broken.mov');
    VideoPlayerPlatform.instance = platform;
    await tester.pumpWidget(_app('/tmp/broken.mov'));
    await _settle(tester);

    expect(find.text('영상을 재생할 수 없어요.'), findsOneWidget);
    await tester.tap(find.text('다시 불러오기'));
    await _settle(tester);
    expect(platform.opened, hasLength(2));
  });

  testWidgets('위험 각도 카드를 누르면 일시정지한 채 그 순간으로 이동한다', (tester) async {
    final platform = _RecordingPlatform();
    VideoPlayerPlatform.instance = platform;
    final result = _result();
    await tester.pumpWidget(_screen(result, result));
    await _settle(tester);
    await tester.tap(find.byType(VideoPlayer));
    await _settle(tester);
    expect(platform.calls.last, 'play:1');

    await tester.ensureVisible(find.text('왼쪽 무릎'));
    await tester.pump();
    await tester.tap(find.text('왼쪽 무릎'));
    await _settle(tester);
    expect(platform.calls.sublist(platform.calls.length - 2), [
      'pause:1',
      'seek:3200',
    ]);
    final controller = tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller;
    expect(controller.value.isPlaying, isFalse);
    expect(controller.value.position, const Duration(milliseconds: 3200));
  });

  testWidgets('다른 기록의 리포트에서 누른 것은 지금 영상에 적용하지 않는다', (tester) async {
    final platform = _RecordingPlatform();
    VideoPlayerPlatform.instance = platform;
    await tester.pumpWidget(_screen(_result(), _result()));
    await _settle(tester);

    await tester.ensureVisible(find.text('왼쪽 무릎'));
    await tester.pump();
    await tester.tap(find.text('왼쪽 무릎'));
    await _settle(tester);
    expect(platform.calls.where((c) => c.startsWith('seek')), isEmpty);
  });
}
