import 'dart:async';

import 'package:feature_video/src/pose_track.dart';
import 'package:feature_video/src/video_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      Texture(textureId: options.playerId);
}

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
}
