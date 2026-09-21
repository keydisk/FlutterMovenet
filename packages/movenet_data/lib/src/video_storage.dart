import 'dart:io';

import 'package:path_provider/path_provider.dart';

class VideoStorage {
  Future<String> persist(String sourcePath) async {
    final directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/analysis-videos',
    );
    await directory.create(recursive: true);
    final dot = sourcePath.lastIndexOf('.');
    final extension = dot < 0 ? '.mp4' : sourcePath.substring(dot);
    final destination =
        '${directory.path}/${DateTime.now().microsecondsSinceEpoch}$extension';
    return (await File(sourcePath).copy(destination)).path;
  }

  /// persist로 복사해 둔 영상 파일을 지운다.
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
