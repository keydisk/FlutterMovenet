import 'dart:io';

import 'package:flutter/material.dart';
import 'package:movenet_domain/movenet_domain.dart';

import 'report_card.dart';

/// iOS 앱 VideoAnalysisHistoryCardView와 같은 구성의 히스토리 카드.
/// 좌측 섬네일 + 우측 요약, 왼쪽으로 밀면 우측에 삭제 버튼이 드러난다.
class HistoryCard extends StatefulWidget {
  const HistoryCard({
    required this.record,
    required this.isSelected,
    required this.onSelect,
    required this.onDelete,
    required this.onShowReport,
    super.key,
  });

  final AnalysisRecord record;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onShowReport;

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  static const _deleteWidth = 74.0;
  double _offset = 0;

  bool get _isSwiped => _offset != 0;

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  _close();
                  widget.onDelete();
                },
                child: Container(
                  width: _deleteWidth,
                  color: const Color(0xFFFF453A),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        '삭제',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) => setState(
              () => _offset = (_offset + details.delta.dx).clamp(
                -_deleteWidth,
                0,
              ),
            ),
            onHorizontalDragEnd: (_) => setState(
              () => _offset = _offset < -_deleteWidth / 2 ? -_deleteWidth : 0,
            ),
            onTap: _isSwiped ? _close : widget.onSelect,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_offset, 0, 0),
              // Stack은 느슨한 제약을 주므로 카드가 폭 전체를 덮도록 고정한다(안 그러면 삭제 버튼이 항상 보인다).
              width: double.infinity,
              child: _card(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    final result = widget.record.result;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // 뒤에 숨긴 삭제 버튼이 비치지 않도록 불투명 색을 쓴다(iOS 카드 색과 같은 명도).
        color: widget.isSelected
            ? const Color(0xFF15375E)
            : const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isSelected
              ? const Color(0xFF0A84FF)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbnail(result.duration),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(widget.record.createdAt),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                _summary(result),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: widget.onShowReport,
                  child: const Text(
                    '최종 보고서',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A84FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(AnalysisResult result) {
    final metrics = result.runningMetrics;
    final candidate = result.candidates.firstOrNull;
    final accent = candidate != null
        ? const Color(0xFFAF52DE)
        : ReportCard.accentFor(result.exercise);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    candidate != null
                        ? Icons.help
                        : ReportCard.exerciseIcon(result.exercise),
                    size: 11,
                    color: accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    candidate?.label ?? result.exercise.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            if (candidate == null)
              if (result.exercise.isRepExercise)
                _text('${result.repetitions}회')
              else if (metrics?.cadence case final cadence?)
                _text('${cadence.round()} spm'),
            if (metrics?.kneeAngle case final knee?)
              _text('무릎 ${knee.round()}°'),
          ],
        ),
        if (result.risks.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ReportCard.warningColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 11,
                  color: ReportCard.warningColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '위험 각도 ${result.risks.length}건 감지',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: ReportCard.warningColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _thumbnail(Duration duration) => SizedBox(
    width: 84,
    height: 68,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: switch (widget.record.thumbnailPath) {
            final path? when File(path).existsSync() => Image.file(
              File(path),
              fit: BoxFit.cover,
            ),
            _ => Container(
              color: Colors.white.withValues(alpha: 0.12),
              child: Icon(
                Icons.videocam,
                size: 24,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          },
        ),
        if (duration > Duration.zero)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(duration),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  static Widget _text(String value) =>
      Text(value, style: const TextStyle(fontSize: 11, color: Colors.white70));

  static String _formatDuration(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  static String _formatDate(DateTime date) =>
      '${date.month}월 ${date.day}일 '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
