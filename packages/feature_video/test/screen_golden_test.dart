import 'dart:io';

import 'package:feature_video/src/video_analysis_controller.dart';
import 'package:feature_video/src/report_card.dart';
import 'package:feature_video/src/video_analysis_screen.dart';
import 'package:feature_video/src/video_analysis_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movenet_domain/movenet_domain.dart';

class _FakeController extends VideoAnalysisController {
  _FakeController(this._state);

  final VideoAnalysisState _state;

  @override
  Future<VideoAnalysisState> build() async => _state;
}

const _fontPath = '/System/Library/Fonts/Supplemental/AppleGothic.ttf';

void main() {
  setUpAll(() async {
    if (!File(_fontPath).existsSync()) return;
    final loader = FontLoader('AppleGothic')
      ..addFont(
        File(
          '/System/Library/Fonts/Supplemental/AppleGothic.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await loader.load();
  });

  testWidgets('empty state matches the iOS layout', (tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = VideoAnalysisState(
      history: [
        _record(
          '9월 17일 17:49 영상',
          ExerciseType.unknown,
          const Duration(seconds: 30),
        ),
        _record(
          '12월 12일 12:32 영상',
          ExerciseType.pullUp,
          const Duration(seconds: 31),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoAnalysisControllerProvider.overrideWith(
            () => _FakeController(state),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'AppleGothic'),
          home: const VideoAnalysisScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(VideoAnalysisScreen),
      matchesGoldenFile('goldens/empty_state_v2.png'),
    );
  }, skip: !File(_fontPath).existsSync());

  _reportGolden();
}

AnalysisRecord _record(String name, ExerciseType type, Duration duration) =>
    AnalysisRecord(
      id: name,
      videoPath: '/tmp/$name.mov',
      createdAt: DateTime(
        2025,
        type == ExerciseType.pullUp ? 12 : 9,
        17,
        17,
        49,
      ),
      result: AnalysisResult(
        exercise: type,
        probabilities: {type: 1},
        repetitions: type == ExerciseType.pullUp ? 3 : 0,
        coaching: const [],
        duration: duration,
        analyzedFrames: 120,
        runningMetrics: type == ExerciseType.pullUp
            ? const RunningMetrics(kneeAngle: 105)
            : null,
      ),
    );

void _reportGolden() {
  testWidgets('report card matches the iOS report layout', (tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const result = AnalysisResult(
      exercise: ExerciseType.running,
      probabilities: {ExerciseType.running: 1},
      repetitions: 0,
      coaching: [
        CoachingTip(title: '케이던스', message: '러닝 케이던스 양호(약 176 spm).'),
        CoachingTip(
          title: '상체 기울기',
          message: '상체를 너무 숙였어요(약 15°). 허리가 아닌 발목부터 기울이세요.',
          isWarning: true,
        ),
      ],
      duration: Duration(seconds: 31),
      riskEvents: 1,
      risks: [
        RiskEvent(
          timestamp: Duration(milliseconds: 12400),
          joint: RiskJoint.leftKnee,
          degrees: 185,
          description: '왼쪽 무릎 과신전(185°) - 인대 및 관절 부하 위험',
          critical: true,
        ),
      ],
      runningMetrics: RunningMetrics(
        cadence: 176,
        trunkLean: 15,
        kneeAngle: 154,
        hipFlexion: 162,
      ),
      analyzedFrames: 120,
      locomotionSummary: '걷기 + 러닝',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'AppleGothic'),
        home: const Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ReportCard(result: result),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ReportCard),
      matchesGoldenFile('goldens/report_card.png'),
    );
  }, skip: !File(_fontPath).existsSync());
}
