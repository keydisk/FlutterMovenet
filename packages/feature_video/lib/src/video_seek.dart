import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movenet_domain/movenet_domain.dart';

/// 리포트에서 고른 순간(위험 각도 등)으로 영상을 옮겨 달라는 요청.
/// [result]로 어느 분석 결과의 요청인지 구분해, 지금 보이는 영상의 결과일 때만 따른다.
class VideoSeekRequest {
  const VideoSeekRequest(this.result, this.position);

  final AnalysisResult result;
  final Duration position;
}

class VideoSeekRequests extends Notifier<VideoSeekRequest?> {
  @override
  VideoSeekRequest? build() => null;

  /// 같은 위치를 다시 눌러도 매번 새 요청으로 알린다.
  void request(AnalysisResult result, Duration position) =>
      state = VideoSeekRequest(result, position);
}

final videoSeekProvider =
    NotifierProvider<VideoSeekRequests, VideoSeekRequest?>(
      VideoSeekRequests.new,
    );
