import 'dart:async';
import 'dart:io';

import 'package:feature_video/src/fullscreen_video_page.dart';
import 'package:feature_video/src/pose_track.dart';
import 'package:feature_video/src/video_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// 텍스처 대신 회색 판을 그리는 가짜 플레이어(세로 영상 1080x1920, 10초).
class _FakeVideoPlatform extends VideoPlayerPlatform {
  final _events = StreamController<VideoEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(
      () => _events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 10),
          size: const Size(1080, 1920),
        ),
      ),
    );
    return _events.stream;
  }

  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Color(0xFF3A3F47));
}

/// 옆에서 찍은 러너: 왼 무릎을 크게 굽힌(주의) 자세.
final _track = PoseTrack([
  for (var ms = 0; ms <= 1000; ms += 66)
    PoseFrame(
      timestamp: Duration(milliseconds: ms),
      points: const {
        Joint.nose: PosePoint(x: 0.52, y: 0.16, confidence: 0.9),
        Joint.leftShoulder: PosePoint(x: 0.44, y: 0.28, confidence: 0.9),
        Joint.rightShoulder: PosePoint(x: 0.58, y: 0.28, confidence: 0.9),
        Joint.leftElbow: PosePoint(x: 0.40, y: 0.37, confidence: 0.9),
        Joint.rightElbow: PosePoint(x: 0.62, y: 0.35, confidence: 0.9),
        Joint.leftWrist: PosePoint(x: 0.45, y: 0.45, confidence: 0.9),
        Joint.rightWrist: PosePoint(x: 0.66, y: 0.28, confidence: 0.9),
        Joint.leftHip: PosePoint(x: 0.48, y: 0.52, confidence: 0.9),
        Joint.rightHip: PosePoint(x: 0.54, y: 0.52, confidence: 0.9),
        Joint.leftKnee: PosePoint(x: 0.60, y: 0.63, confidence: 0.9),
        Joint.rightKnee: PosePoint(x: 0.50, y: 0.69, confidence: 0.9),
        Joint.leftAnkle: PosePoint(x: 0.47, y: 0.68, confidence: 0.9),
        Joint.rightAnkle: PosePoint(x: 0.44, y: 0.85, confidence: 0.9),
      },
    ),
]);

const _fontPath = '/System/Library/Fonts/Supplemental/AppleGothic.ttf';

void main() {
  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeVideoPlatform();
    if (!File(_fontPath).existsSync()) return;
    final loader = FontLoader('AppleGothic')
      ..addFont(File(_fontPath).readAsBytes().then(ByteData.sublistView));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await icons.load().catchError((_) {});
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('작은 미리보기: 관절·각도 + 오른쪽 아래 전체 화면 버튼', (tester) async {
    tester.view
      ..physicalSize = const Size(1179, 1100)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poseTrackProvider.overrideWith((ref, path) async => _track),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'AppleGothic'),
          home: const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: VideoPreview(path: '/tmp/fake.mov')),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.bySemanticsLabel('전체 화면으로 보기'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/preview_overlay.png'),
    );
  }, skip: !File(_fontPath).existsSync());

  for (final (name, size) in [
    ('landscape', const Size(2556, 1179)),
    ('portrait', const Size(1179, 2556)),
  ]) {
    testWidgets('전체 화면($name): 측면 설명 패널이 영상을 가리지 않는다', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final video = VideoPlayerController.file(File('/tmp/fake.mov'));
      await tester.runAsync(video.initialize);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'AppleGothic'),
          home: FullscreenVideoPage(video: video, track: _track),
        ),
      );
      await settle(tester);
      expect(find.text('관절 각도'), findsOneWidget);
      // 패널과 영상 영역이 겹치지 않는다.
      final panel = tester.getRect(find.text('관절 각도'));
      final stage = tester.getRect(find.byType(VideoPlayer));
      expect(panel.left, greaterThanOrEqualTo(stage.right));
      await expectLater(
        find.byType(FullscreenVideoPage),
        matchesGoldenFile('goldens/fullscreen_$name.png'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(video.dispose);
    }, skip: !File(_fontPath).existsSync());
  }
}
