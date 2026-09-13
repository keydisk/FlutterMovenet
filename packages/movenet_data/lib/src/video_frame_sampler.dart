import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';

class VideoFrameSampler {
  Future<String?> frame(String videoPath, int timeMs) async {
    final bytes = await VideoThumbnailPlus.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 480,
      timeMs: timeMs,
      quality: 80,
    );
    if (bytes == null) return null;
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/movenet-frame-$timeMs-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
