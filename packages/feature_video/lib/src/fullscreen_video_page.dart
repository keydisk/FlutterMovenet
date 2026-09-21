import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:video_player/video_player.dart';

import 'pose_overlay.dart';
import 'pose_track.dart';
import 'video_preview.dart';

/// 전체 화면 재생. 영상 옆(측면)에 각도 설명 패널을 따로 두어 인식 박스·관절을 가리지 않는다.
/// 빠른 동작을 따라가기 쉽게 느린 재생(0.5x/0.25x)과 분석 프레임 단위 이동을 제공한다.
class FullscreenVideoPage extends StatefulWidget {
  const FullscreenVideoPage({
    required this.video,
    required this.track,
    super.key,
  });

  /// 작은 미리보기와 같은 플레이어를 이어서 쓴다(재생 위치 유지).
  final VideoPlayerController video;
  final PoseTrack? track;

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage>
    with SingleTickerProviderStateMixin {
  late final PoseOverlayDriver _driver;
  double? _dragging;

  static const _speeds = [1.0, 0.5, 0.25];

  /// 어깨 각도는 머리 주변을 복잡하게 만들어 패널에만 보여 준다.
  static final _videoLabels = {
    for (final joint in RiskJoint.values)
      if (joint != RiskJoint.leftShoulder && joint != RiskJoint.rightShoulder)
        joint,
  };

  @override
  void initState() {
    super.initState();
    _driver = PoseOverlayDriver(video: widget.video, vsync: this)
      ..track = widget.track;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 작은 미리보기에는 속도 표시가 없으므로 원래 속도로 돌려 놓는다.
    widget.video.setPlaybackSpeed(1);
    _driver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight;
          final panelWidth = wide
              ? (box.maxWidth * 0.3).clamp(220.0, 300.0)
              : (box.maxWidth * 0.36).clamp(124.0, 150.0);
          return Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _stage()),
                    _controls(),
                  ],
                ),
              ),
              SizedBox(
                width: panelWidth,
                child: _AnglePanel(driver: _driver, compact: !wide),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _stage() => ValueListenableBuilder(
    valueListenable: widget.video,
    builder: (context, value, _) => Center(
      child: AspectRatio(
        aspectRatio: value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: VideoPlayer(widget.video),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: PoseOverlayPainter(
                  _driver,
                  labels: _videoLabels,
                  textStyle: DefaultTextStyle.of(context).style,
                  large: true,
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: OverlayIconButton(
                icon: Icons.fullscreen_exit,
                label: '전체 화면 닫기',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _togglePlay() =>
      widget.video.value.isPlaying ? widget.video.pause() : widget.video.play();

  /// 영상 아래 컨트롤(영상 위에 겹치지 않는다).
  Widget _controls() => ListenableBuilder(
    listenable: _driver,
    builder: (context, _) {
      final value = widget.video.value;
      final total = value.duration.inMilliseconds.toDouble();
      final position =
          _dragging ?? _driver.time.inMilliseconds.toDouble().clamp(0.0, total);
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _time(Duration(milliseconds: position.round())),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: total <= 0 ? 0 : position,
                      max: total <= 0 ? 1 : total,
                      activeColor: const Color(0xFF0A84FF),
                      inactiveColor: Colors.white24,
                      onChanged: (v) => setState(() => _dragging = v),
                      onChangeEnd: (v) async {
                        await widget.video.seekTo(
                          Duration(milliseconds: v.round()),
                        );
                        if (mounted) setState(() => _dragging = null);
                      },
                    ),
                  ),
                ),
                _time(value.duration),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconButton(
                  Icons.skip_previous,
                  '이전 분석 프레임',
                  () => _driver.step(-1),
                ),
                _iconButton(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  value.isPlaying ? '일시정지' : '재생',
                  _togglePlay,
                  size: 32,
                ),
                _iconButton(
                  Icons.skip_next,
                  '다음 분석 프레임',
                  () => _driver.step(1),
                ),
                const SizedBox(width: 8),
                _speedButton(value.playbackSpeed),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _time(Duration d) => Text(
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}',
    style: const TextStyle(
      fontSize: 11,
      color: Colors.white70,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );

  Widget _iconButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    double size = 26,
  }) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon, size: size, color: Colors.white),
  );

  /// 1x → 0.5x → 0.25x 순환. 빠른 동작을 천천히 따라볼 수 있다.
  Widget _speedButton(double speed) {
    final index = _speeds.indexWhere((s) => (s - speed).abs() < 0.01);
    final next = _speeds[(index + 1) % _speeds.length];
    final label = speed == 1 ? '1x' : '${speed}x';
    return Semantics(
      button: true,
      label: '재생 속도 $label, 눌러서 ${next}x로 변경',
      child: OutlinedButton(
        onPressed: () => widget.video.setPlaybackSpeed(next),
        style: OutlinedButton.styleFrom(
          foregroundColor: speed < 1 ? const Color(0xFF0A84FF) : Colors.white,
          side: BorderSide(
            color: speed < 1 ? const Color(0xFF0A84FF) : Colors.white38,
          ),
          minimumSize: const Size(52, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

/// 영상 옆 관절 각도 설명. 숫자는 0.3초마다만 바뀌고, 경고는 2초간 유지해 읽을 시간을 준다.
class _AnglePanel extends StatelessWidget {
  const _AnglePanel({required this.driver, required this.compact});

  final PoseOverlayDriver driver;
  final bool compact;

  static const _rows = [
    ('무릎', RiskJoint.leftKnee, RiskJoint.rightKnee),
    ('고관절', RiskJoint.leftHip, RiskJoint.rightHip),
    ('팔꿈치', RiskJoint.leftElbow, RiskJoint.rightElbow),
    ('어깨', RiskJoint.leftShoulder, RiskJoint.rightShoulder),
  ];

  static const _good = Color(0xFF30D158);

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF111114),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 10 : 16,
      vertical: compact ? 12 : 16,
    ),
    child: ListenableBuilder(
      listenable: driver,
      builder: (context, _) {
        final smoother = driver.smoother;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Text(
              '관절 각도',
              style: TextStyle(
                fontSize: compact ? 15 : 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              compact ? '180° = 완전히 폄' : '관절 안쪽 각도 · 180° = 완전히 폄',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            SizedBox(height: compact ? 12 : 16),
            if (smoother == null)
              const Text(
                '이 영상은 관절 데이터가 없어요.\n히스토리에서 다시 선택하면 재분석해 관절을 표시합니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              )
            else ...[
              _header(),
              for (final (name, left, right) in _rows)
                _row(name, smoother.angles[left], smoother.angles[right], [
                  left,
                  right,
                ]),
              if (smoother.points.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '이 구간은 사람이 인식되지 않았어요.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              SizedBox(height: compact ? 12 : 16),
              _warning(smoother.warning),
              if (!compact) ...[const SizedBox(height: 16), _legend()],
            ],
          ],
        );
      },
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const Expanded(flex: 5, child: SizedBox()),
        for (final side in const ['왼쪽', '오른쪽'])
          Expanded(
            flex: 4,
            child: Text(
              compact ? side.substring(0, 1) : side,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
      ],
    ),
  );

  Widget _row(String name, int? left, int? right, List<RiskJoint> joints) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 5 : 7),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  color: Colors.white70,
                ),
              ),
            ),
            for (final (joint, degrees) in [
              (joints[0], left),
              (joints[1], right),
            ])
              Expanded(flex: 4, child: _value(joint, degrees)),
          ],
        ),
      );

  Widget _value(RiskJoint joint, int? degrees) {
    final caution =
        degrees != null &&
        JointStatus.of(joint, degrees.toDouble()).level == StatusLevel.caution;
    final color = caution ? PoseOverlayPainter.caution : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            degrees == null ? '—' : '$degrees°',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: compact ? 14 : 17,
              fontWeight: FontWeight.w700,
              color: degrees == null ? Colors.white38 : color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 3),
        // 0~180° 막대: 숫자를 읽지 않아도 굽힘 정도를 한눈에 본다.
        SizedBox(
          width: compact ? 34 : 48,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: degrees == null ? 0 : (degrees / 180).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              color: caution
                  ? PoseOverlayPainter.caution
                  : PoseOverlayPainter.bone,
            ),
          ),
        ),
      ],
    );
  }

  /// 높이를 고정해 경고가 생기고 사라져도 패널이 들썩이지 않게 한다.
  Widget _warning(JointStatus? status) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    height: compact ? 116 : 84,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: status == null
          ? _good.withValues(alpha: 0.12)
          : PoseOverlayPainter.caution.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: status == null
            ? _good.withValues(alpha: 0.35)
            : PoseOverlayPainter.caution.withValues(alpha: 0.6),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              status == null ? Icons.check_circle : Icons.warning_amber_rounded,
              size: 16,
              color: status == null ? _good : PoseOverlayPainter.caution,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                status?.joint.label ?? '안정적인 각도',
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          status?.message ?? '위험 범위를 벗어난 관절이 없어요.',
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _legend() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LegendItem(PoseOverlayPainter.dot, '정상 범위 관절'),
      SizedBox(height: 6),
      _LegendItem(PoseOverlayPainter.caution, '주의 각도(무릎·팔꿈치 과신전, 과도한 굴곡)'),
      SizedBox(height: 10),
      Text(
        '빠른 동작은 0.5x·0.25x 또는 프레임 이동 버튼으로 천천히 확인하세요.',
        style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
      ),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: CircleAvatar(radius: 4, backgroundColor: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ),
    ],
  );
}
