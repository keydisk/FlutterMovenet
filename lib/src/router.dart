import 'package:feature_camera/feature_camera.dart';
import 'package:feature_home/feature_home.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_video/feature_video.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  routes: [
    _route('/', const HomeScreen()),
    _route('/camera', const CameraScreen()),
    _route('/video', const VideoAnalysisScreen()),
    _route('/settings', const SettingsScreen()),
  ],
);

/// go_router는 `builder`만 주면 위에서 MaterialApp을 찾아 페이지 종류를 고르는데,
/// 지금 Flutter에서는 찾지 못해 전환 없는 NoTransitionPage로 떨어진다.
/// MaterialPage를 직접 만들어 테마의 pageTransitionsTheme(좌우 슬라이드)이 적용되게 한다.
GoRoute _route(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (_, state) => MaterialPage<void>(
    key: state.pageKey,
    name: state.name,
    arguments: state.extra,
    restorationId: state.pageKey.value,
    child: screen,
  ),
);
