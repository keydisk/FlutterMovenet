import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:video_player/video_player.dart';

import 'pose_overlay.dart';
import 'pose_track.dart';

/// 전체 화면 재생. 관절 각도 패널과 조작 버튼을 영상 위에 겹쳐 띄운다.
/// - 세로: 영상을 화면 가득 채우고, 패널은 인식된 사람 영역과 가장 덜 겹치는 모서리에 둔다.
/// - 가로: 영상은 왼쪽, 분석 패널은 오른쪽.
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

  /// 테스트에서 패널 위치를 찾는 키.
  static const panelKey = ValueKey('fullscreen-angle-panel');

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage>
    with SingleTickerProviderStateMixin {
  late final PoseOverlayDriver _driver;
  final _placer = PanelPlacer();
  final _panelMeasure = GlobalKey();
  double _panelHeight = _cornerPanelSize.height;
  double? _dragging;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _placeTimer;

  static const _speeds = [1.0, 0.5, 0.25];

  /// 세로 모드 겹침 패널 크기. 실제 높이는 그려진 뒤 잰 값을 쓴다.
  static const _cornerPanelSize = Size(128, 240);

  /// 아래쪽 조작 바 높이. 세로 패널은 이 위에 놓는다.
  static const _controlsHeight = 104.0;

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
    widget.video.addListener(_onVideo);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _placeTimer?.cancel();
    widget.video.removeListener(_onVideo);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 작은 미리보기에는 속도 표시가 없으므로 원래 속도로 돌려 놓는다.
    widget.video.setPlaybackSpeed(1);
    _driver.dispose();
    super.dispose();
  }

  bool _wasPlaying = false;

  void _onVideo() {
    final playing = widget.video.value.isPlaying;
    if (playing == _wasPlaying) return;
    _wasPlaying = playing;
    // 재생을 시작하면 잠시 뒤 조작 바를 숨기고, 멈추면 다시 보여 준다.
    playing ? _scheduleHide() : _showControls();
  }

  void _showControls() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = true);
    if (widget.video.value.isPlaying) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.video.value.isPlaying && _dragging == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onVideoTap() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final area = box.biggest;
          final wide = area.width > area.height;
          final aspect = widget.video.value.isInitialized
              ? widget.video.value.aspectRatio
              : 16 / 9;
          // 가로: 영상을 왼쪽에 붙이고 오른쪽에 분석 패널, 세로: 가운데 가득.
          final fitted = applyBoxFit(
            BoxFit.contain,
            Size(aspect, 1),
            area,
          ).destination;
          final videoRect = wide
              ? Offset(0, (area.height - fitted.height) / 2) & fitted
              : Alignment.center.inscribe(fitted, Offset.zero & area);
          final sidePanelWidth = (area.width * 0.3).clamp(220.0, 300.0);
          final controlsWidth = wide ? area.width - sidePanelWidth : area.width;
          return Stack(
            children: [
              Positioned.fromRect(rect: videoRect, child: _video()),
              if (wide)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: sidePanelWidth,
                  child: _AnglePanel(
                    key: FullscreenVideoPage.panelKey,
                    driver: _driver,
                    compact: false,
                  ),
                )
              else
                _cornerPanel(area, videoRect),
              Positioned(
                left: 0,
                bottom: 0,
                width: controlsWidth,
                height: _controlsHeight,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: _controls(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _video() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _onVideoTap,
    child: Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(widget.video),
        // Scaffold 아래 context에서 글꼴을 읽어야 앱 글꼴로 각도 라벨이 그려진다.
        Builder(
          builder: (context) => IgnorePointer(
            child: CustomPaint(
              painter: PoseOverlayPainter(
                _driver,
                labels: _videoLabels,
                textStyle: DefaultTextStyle.of(context).style,
                large: true,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// 세로 모드: 인식 박스를 가장 덜 가리는 모서리로 패널을 옮긴다(부드럽게 이동).
  Widget _cornerPanel(Size area, Rect videoRect) => ListenableBuilder(
    listenable: _driver,
    builder: (context, _) {
      final points = _driver.smoother?.points.values ?? const <Offset>[];
      final person = personBox([
        for (final p in points)
          Offset(p.dx * videoRect.width, p.dy * videoRect.height),
      ], videoRect.size)?.shift(videoRect.topLeft);
      // 패널 실제 높이는 그려진 뒤에만 알 수 있으므로 다음 프레임에 재서 반영한다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = _panelMeasure.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize || !mounted) return;
        if ((box.size.height - _panelHeight).abs() > 1) {
          setState(() => _panelHeight = box.size.height);
        }
      });
      final rect = _placer.place(
        person: person,
        area: area,
        panel: Size(_cornerPanelSize.width, _panelHeight),
        bottomInset: _controlsHeight,
      );
      if (_placer.waiting && _placeTimer == null) {
        _placeTimer = Timer(const Duration(milliseconds: 900), () {
          _placeTimer = null;
          if (mounted) setState(() {});
        });
      }
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        left: rect.left,
        top: rect.top,
        width: rect.width,
        child: KeyedSubtree(
          key: _panelMeasure,
          child: _AnglePanel(
            key: FullscreenVideoPage.panelKey,
            driver: _driver,
            compact: true,
          ),
        ),
      );
    },
  );

  void _togglePlay() =>
      widget.video.value.isPlaying ? widget.video.pause() : widget.video.play();

  /// 영상 아래쪽에 겹치는 조작 바(재생 중에는 3초 뒤 자동으로 숨김).
  Widget _controls() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black87],
      ),
    ),
    child: ListenableBuilder(
      listenable: _driver,
      builder: (context, _) {
        final value = widget.video.value;
        final total = value.duration.inMilliseconds.toDouble();
        final position =
            _dragging ??
            _driver.time.inMilliseconds.toDouble().clamp(0.0, total);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
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
                          _showControls();
                        },
                      ),
                    ),
                  ),
                  _time(value.duration),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 48),
                  const Spacer(),
                  _iconButton(Icons.skip_previous, '이전 분석 프레임', () {
                    _driver.step(-1);
                    _showControls();
                  }),
                  _iconButton(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                    value.isPlaying ? '일시정지' : '재생',
                    _togglePlay,
                    size: 32,
                  ),
                  _iconButton(Icons.skip_next, '다음 분석 프레임', () {
                    _driver.step(1);
                    _showControls();
                  }),
                  const SizedBox(width: 8),
                  _speedButton(value.playbackSpeed),
                  const Spacer(),
                  _iconButton(
                    Icons.fullscreen_exit,
                    '전체 화면 닫기',
                    () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
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
        onPressed: () {
          widget.video.setPlaybackSpeed(next);
          _showControls();
        },
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

/// 세로 모드 패널을 네 모서리 중 사람 영역과 가장 덜 겹치는 곳에 둔다.
/// 더 나은 자리가 0.8초 이상 계속 나을 때만 옮겨 패널이 들썩이지 않게 한다.
class PanelPlacer {
  static const _margin = 12.0;
  static const _hold = Duration(milliseconds: 800);

  Alignment _current = Alignment.topRight;
  Alignment? _pending;
  final _pendingFor = Stopwatch();
  bool _placed = false;

  /// 옮길 자리를 기다리는 중이면 true(일시정지 중에도 다시 계산하도록 알린다).
  bool get waiting => _pending != null;

  Rect place({
    required Rect? person,
    required Size area,
    required Size panel,
    required double bottomInset,
  }) {
    Rect rectOf(Alignment corner) =>
        Offset(
          corner.x < 0 ? _margin : area.width - panel.width - _margin,
          corner.y < 0 ? _margin : area.height - bottomInset - panel.height,
        ) &
        panel;

    double overlap(Alignment corner) {
      if (person == null) return 0;
      final hit = rectOf(corner).intersect(person);
      return hit.width <= 0 || hit.height <= 0 ? 0 : hit.width * hit.height;
    }

    if (person != null) {
      const corners = [
        Alignment.topRight,
        Alignment.topLeft,
        Alignment.bottomRight,
        Alignment.bottomLeft,
      ];
      final best = corners.reduce((a, b) => overlap(b) < overlap(a) ? b : a);
      // 처음 사람이 잡혔을 때는 기다리지 않고 바로 가장 좋은 자리에 둔다.
      if (!_placed) {
        _placed = true;
        _current = best;
      }
      // 겹침 차이가 패널 면적의 5% 미만이면 지금 자리를 유지한다.
      final worthMoving =
          overlap(_current) - overlap(best) > panel.width * panel.height * 0.05;
      if (!worthMoving || best == _current) {
        _pending = null;
      } else if (_pending != best) {
        _pending = best;
        _pendingFor
          ..reset()
          ..start();
      } else if (_pendingFor.elapsed >= _hold) {
        _current = best;
        _pending = null;
      }
    }
    return rectOf(_current);
  }

  /// 테스트용: 대기 시간 없이 바로 최선의 자리로 옮긴다.
  @visibleForTesting
  Rect placeNow({
    required Rect? person,
    required Size area,
    required Size panel,
    required double bottomInset,
  }) {
    place(person: person, area: area, panel: panel, bottomInset: bottomInset);
    if (_pending case final next?) _current = next;
    _pending = null;
    return place(
      person: person,
      area: area,
      panel: panel,
      bottomInset: bottomInset,
    );
  }
}

/// 관절 각도 설명 패널(영상 위에 반투명하게 겹친다). 숫자는 0.3초마다만 바뀌고, 경고는 2초간 유지해 읽을 시간을 준다.
class _AnglePanel extends StatelessWidget {
  const _AnglePanel({required this.driver, required this.compact, super.key});

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
    margin: compact ? EdgeInsets.zero : const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 8 : 16,
      vertical: compact ? 10 : 16,
    ),
    child: ListenableBuilder(
      listenable: driver,
      builder: (context, _) {
        final smoother = driver.smoother;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '관절 각도',
                style: TextStyle(
                  fontSize: compact ? 13 : 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              // 세로 겹침 패널은 사람을 가리지 않도록 설명을 줄여 폭을 좁힌다.
              if (!compact) ...[
                const SizedBox(height: 4),
                const Text(
                  '관절 안쪽 각도 · 180° = 완전히 폄',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
              SizedBox(height: compact ? 8 : 12),
              if (smoother == null)
                const Text(
                  '이 영상은 관절 데이터가 없어요.\n히스토리에서 다시 선택하면 재분석해 관절을 표시합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.4,
                  ),
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
                SizedBox(height: compact ? 8 : 12),
                _warning(smoother.warning),
                if (!compact) ...[const SizedBox(height: 16), _legend()],
              ],
            ],
          ),
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
        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                name,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontSize: compact ? 11 : 14,
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
              fontSize: compact ? 13 : 17,
              fontWeight: FontWeight.w700,
              color: degrees == null ? Colors.white38 : color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 3),
        // 0~180° 막대: 숫자를 읽지 않아도 굽힘 정도를 한눈에 본다.
        SizedBox(
          width: compact ? 30 : 48,
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
    height: compact ? 78 : 72,
    padding: EdgeInsets.all(compact ? 7 : 10),
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
              size: compact ? 14 : 16,
              color: status == null ? _good : PoseOverlayPainter.caution,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                status?.joint.label ?? '안정적인 각도',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: compact ? 10 : 11, color: Colors.white70),
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
