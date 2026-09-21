import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movenet_domain/movenet_domain.dart';

import 'history_card.dart';
import 'report_card.dart';
import 'video_analysis_controller.dart';
import 'video_analysis_state.dart';
import 'video_preview.dart';

/// iOS 앱 VideoAnalysisView와 같은 구성.
/// 영상 선택 전에는 배너 + 히스토리, 선택 후에는 재생 화면 + 리포트·히스토리.
class VideoAnalysisScreen extends ConsumerWidget {
  const VideoAnalysisScreen({super.key});

  static const _accent = Color(0xFF0A84FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(videoAnalysisControllerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: analysis.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _accent)),
        error: (error, _) => _errorView(context, ref, error),
        data: (value) => PopScope(
          // 영상 화면에서 시스템 뒤로가기(Android 뒤로 버튼 등)는 화면을 닫지 않고 목록으로 돌아간다.
          canPop: value.selectedPath == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              ref
                  .read(videoAnalysisControllerProvider.notifier)
                  .clearSelection();
            }
          },
          child: SafeArea(
            child: Stack(
              children: [
                _pageSwitcher(
                  isVideo: value.selectedPath != null,
                  page: value.selectedPath == null
                      ? _emptyState(context, ref, value)
                      : _videoState(context, ref, value),
                ),
                _topBar(context, ref, value),
                if (value.isAnalyzing) _progressOverlay(value.progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MARK: 목록 ↔ 영상 전환

  static const _videoPageKey = ValueKey('video');

  /// 목록 → 영상은 오른쪽에서 밀려 들어오고(push), 뒤로 가면 오른쪽으로 빠진다(pop).
  /// 목록은 그 아래에서 살짝 왼쪽으로 밀리며 어두워져 iOS 내비게이션과 같은 느낌을 준다.
  Widget _pageSwitcher({required bool isVideo, required Widget page}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // 영상 페이지는 들어올 때도 나갈 때도 목록 위에 그려야 슬라이드가 보인다.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          ...previous.where((child) => child.key != _videoPageKey),
          ?current,
          ...previous.where((child) => child.key == _videoPageKey),
        ],
      ),
      transitionBuilder: (child, animation) => child.key == _videoPageKey
          ? SlideTransition(
              position: Tween(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            )
          : SlideTransition(
              position: Tween(
                begin: const Offset(-0.3, 0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: Tween(begin: 0.4, end: 1.0).animate(animation),
                child: child,
              ),
            ),
      child: KeyedSubtree(
        key: isVideo ? _videoPageKey : const ValueKey('list'),
        // 불투명 배경이 있어야 위에 겹친 페이지가 아래 페이지를 가린다.
        child: ColoredBox(color: Colors.black, child: page),
      ),
    );
  }

  // MARK: 영상 선택 전

  Widget _emptyState(
    BuildContext context,
    WidgetRef ref,
    VideoAnalysisState value,
  ) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 64, 16, 40),
    children: [
      _addVideoBanner(ref),
      const SizedBox(height: 20),
      _historySection(context, ref, value, showAddButton: false),
    ],
  );

  Widget _addVideoBanner(WidgetRef ref) => GestureDetector(
    onTap: () =>
        ref.read(videoAnalysisControllerProvider.notifier).chooseAndAnalyze(),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.video_call, size: 26, color: _accent),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '앨범에서 새 영상 분석',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '걷기/러닝 영상 선택 시 실시간 포즈 및 위험 각도 분석',
                  maxLines: 2,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        ],
      ),
    ),
  );

  // MARK: 영상 선택 후

  Widget _videoState(
    BuildContext context,
    WidgetRef ref,
    VideoAnalysisState value,
  ) {
    // 가로 화면은 영상(왼쪽)과 리포트·히스토리(오른쪽)로 나눈다. 세로 화면은 위아래로 나눈다.
    // 회전해도 위젯 구조를 같게 유지해야 VideoPreview 상태(재생 위치 등)가 초기화되지 않는다.
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Flex(
      direction: landscape ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: landscape ? 3 : 42,
          child: Padding(
            // 가로에서는 상단 바가 영상 위에 겹치도록 두어 세로 공간을 아낀다.
            padding: EdgeInsets.only(top: landscape ? 0 : 56),
            child: ColoredBox(
              color: Colors.black,
              child: Center(child: VideoPreview(path: value.selectedPath!)),
            ),
          ),
        ),
        Expanded(
          flex: landscape ? 2 : 58,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, landscape ? 64 : 16, 16, 16),
            children: [
              if (value.latest case final record?)
                ReportCard(result: record.result)
              else
                _waitingView(),
              const SizedBox(height: 14),
              _historySection(context, ref, value, showAddButton: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _waitingView() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Column(
      children: [
        Icon(Icons.directions_run, size: 36, color: Colors.grey),
        SizedBox(height: 12),
        Text(
          '보행 및 러닝 폼 실시간 분석',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '영상을 재생하면 실시간으로 걷기/러닝을 자동 구분하여 자세와 각도 코칭 및 위험 각도 스냅샷을 제공합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    ),
  );

  // MARK: 히스토리

  Widget _historySection(
    BuildContext context,
    WidgetRef ref,
    VideoAnalysisState value, {
    required bool showAddButton,
  }) {
    final controller = ref.read(videoAnalysisControllerProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              const Text(
                '분석 히스토리',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (value.history.isNotEmpty)
                Text(
                  '${value.history.length}개 기록',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (value.history.isEmpty)
            _emptyHistory()
          else
            for (final record in value.history) ...[
              HistoryCard(
                record: record,
                isSelected: record.id == value.latest?.id,
                onSelect: () => controller.selectRecord(record),
                onDelete: () => controller.deleteRecord(record),
                onShowReport: () => _showReport(context, record),
              ),
              const SizedBox(height: 10),
            ],
          if (showAddButton) ...[
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent.withValues(alpha: 0.85),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: controller.chooseAndAnalyze,
                icon: const Icon(Icons.add_circle, size: 18),
                label: const Text('앨범에서 새 영상 분석 추가'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyHistory() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.history_toggle_off, size: 36, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            '저장된 분석 히스토리가 없습니다',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "상단의 '앨범에서 새 영상 분석'을 눌러\n첫 번째 동영상 분석을 시작해보세요.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  void _showReport(BuildContext context, AnalysisRecord record) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1C1C1E),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: switch (record.thumbnailPath) {
                        final path? when File(path).existsSync() => Image.file(
                          File(path),
                          fit: BoxFit.cover,
                        ),
                        _ => ColoredBox(
                          color: Colors.white.withValues(alpha: 0.08),
                          child: const Icon(
                            Icons.videocam,
                            size: 24,
                            color: Colors.white70,
                          ),
                        ),
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDate(record.createdAt)} · '
                          '${_formatDuration(record.result.duration)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ReportCard(result: record.result),
            ],
          ),
        ),
      );

  // MARK: 상단 바 · 오버레이

  Widget _topBar(
    BuildContext context,
    WidgetRef ref,
    VideoAnalysisState value,
  ) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        _circleButton(
          icon: Icons.chevron_left,
          onTap: () => value.selectedPath == null
              ? Navigator.of(context).maybePop()
              : ref
                    .read(videoAnalysisControllerProvider.notifier)
                    .clearSelection(),
        ),
        const Spacer(),
        if (value.selectedPath != null)
          GestureDetector(
            onTap: ref
                .read(videoAnalysisControllerProvider.notifier)
                .chooseAndAnalyze,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '영상 변경',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      );

  Widget _progressOverlay(double progress) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.7),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF242428),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                value: progress,
                color: _accent,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '분석 준비 중… (${(progress * 100).round()}%)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '영상 전체를 미리 분석하고 있어요.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _errorView(BuildContext context, WidgetRef ref, Object error) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: Color(0xFFFF453A),
              ),
              const SizedBox(height: 12),
              Text(
                '분석하지 못했습니다: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.invalidate(videoAnalysisControllerProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );

  static String _formatDate(DateTime date) =>
      '${date.month}월 ${date.day}일 '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  static String _formatDuration(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
