import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:video_player/video_player.dart';

import 'fullscreen_video_page.dart';
import 'pose_overlay.dart';
import 'pose_track.dart';

/// 분석한 영상 재생 + MoveNet 관절·각도 오버레이. 오른쪽 아래 버튼으로 전체 화면을 연다.
class VideoPreview extends ConsumerStatefulWidget {
  const VideoPreview({required this.path, super.key});

  final String path;

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<VideoPreview>
    with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  late PoseOverlayDriver _driver;
  bool _wasPlaying = false;
  bool _wasAtEdge = true;
  bool _hadError = false;

  /// 작은 화면에서는 하체·팔꿈치 각도만 붙여 숫자가 몰리지 않게 한다.
  static const _labels = {
    RiskJoint.leftKnee,
    RiskJoint.rightKnee,
    RiskJoint.leftHip,
    RiskJoint.rightHip,
    RiskJoint.leftElbow,
    RiskJoint.rightElbow,
  };

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 기록을 고르면 같은 State가 재사용되므로 플레이어를 새 영상으로 다시 연다.
    if (oldWidget.path != widget.path) _reopen();
  }

  void _open() {
    _wasPlaying = false;
    _wasAtEdge = true;
    _hadError = false;
    _controller = VideoPlayerController.file(File(widget.path))
      ..addListener(_onVideo);
    _controller.initialize().then(
      (_) => mounted ? setState(() {}) : null,
      // 실패는 value.hasError로 화면에 보여 준다.
      onError: (Object _) => mounted ? setState(() {}) : null,
    );
    _driver = PoseOverlayDriver(video: _controller, vsync: this);
  }

  void _close() {
    _driver.dispose();
    _controller
      ..removeListener(_onVideo)
      ..dispose();
  }

  void _reopen() {
    _close();
    _open();
    setState(() {});
  }

  void _onVideo() {
    // 재생 아이콘 표시 조건·오류 상태가 바뀔 때만 다시 그린다(위치 변화는 오버레이가 따로 그린다).
    final value = _controller.value;
    final atEdge =
        value.position == Duration.zero || value.position >= value.duration;
    if ((value.isPlaying, atEdge, value.hasError) !=
            (_wasPlaying, _wasAtEdge, _hadError) &&
        mounted) {
      setState(() {
        _wasPlaying = value.isPlaying;
        _wasAtEdge = atEdge;
        _hadError = value.hasError;
      });
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  Future<void> _openFullscreen() => Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          FullscreenVideoPage(video: _controller, track: _driver.track),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    _driver.track = ref.watch(poseTrackProvider(widget.path)).value;
    if (_controller.value.hasError) return _errorView();
    if (!_controller.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final value = _controller.value;
    final playing = value.isPlaying;
    // 시작 전·끝난 뒤에만 가운데 재생 아이콘을 띄운다. 중간에 멈춘 자세는 가리지 않는다.
    final showPlayIcon =
        !playing &&
        (value.position == Duration.zero || value.position >= value.duration);
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: playing ? '영상 일시정지' : '영상 재생',
            child: GestureDetector(
              onTap: () => playing ? _controller.pause() : _controller.play(),
              child: VideoPlayer(_controller),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: PoseOverlayPainter(
                _driver,
                labels: _labels,
                textStyle: DefaultTextStyle.of(context).style,
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: showPlayIcon ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Center(
                child: Icon(Icons.play_circle, size: 56, color: Colors.white70),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: OverlayIconButton(
              icon: Icons.fullscreen,
              label: '전체 화면으로 보기',
              onTap: _openFullscreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() => AspectRatio(
    aspectRatio: 16 / 9,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 32, color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            '영상을 재생할 수 없어요.',
            style: TextStyle(fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _reopen, child: const Text('다시 불러오기')),
        ],
      ),
    ),
  );
}

/// 영상 위에 떠 있는 반투명 원형 버튼.
class OverlayIconButton extends StatelessWidget {
  const OverlayIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}
