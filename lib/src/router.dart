import 'package:feature_camera/feature_camera.dart';
import 'package:feature_home/feature_home.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_video/feature_video.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/camera', builder: (_, _) => const CameraScreen()),
    GoRoute(path: '/video', builder: (_, _) => const VideoAnalysisScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);
