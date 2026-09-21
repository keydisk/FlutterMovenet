import 'package:flutter_test/flutter_test.dart';
import 'package:movenet_data/movenet_data.dart';

void main() {
  const oldRoot =
      '/var/mobile/Containers/Data/Application/'
      '11111111-2222-3333-4444-555555555555/';
  const newRoot =
      '/var/mobile/Containers/Data/Application/'
      'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE/';

  test('앱 재설치로 컨테이너가 바뀌면 영상·섬네일·스냅샷 경로를 새 컨테이너로 옮긴다', () {
    final json = AnalysisStorage.rebasePaths(
      {
        'videoPath': '${oldRoot}Documents/analysis-videos/1.mp4',
        'thumbnailPath': '${oldRoot}Library/Application Support/movenet-t.jpg',
        'risks': [
          {'imagePath': '${oldRoot}Library/Application Support/movenet-r.jpg'},
        ],
      },
      newRoot,
      exists: (_) => false,
    );
    expect(json['videoPath'], '${newRoot}Documents/analysis-videos/1.mp4');
    expect(
      json['thumbnailPath'],
      '${newRoot}Library/Application Support/movenet-t.jpg',
    );
    expect(
      ((json['risks']! as List).first as Map)['imagePath'],
      '${newRoot}Library/Application Support/movenet-r.jpg',
    );
  });

  test('파일이 그대로 있거나 iOS 컨테이너 경로가 아니면 건드리지 않는다', () {
    const android =
        '/data/user/0/com.example/app_flutter/analysis-videos/1.mp4';
    final json = AnalysisStorage.rebasePaths(
      {'videoPath': android, 'thumbnailPath': '${oldRoot}Documents/t.jpg'},
      newRoot,
      exists: (path) => path.startsWith(oldRoot),
    );
    expect(json['videoPath'], android);
    expect(json['thumbnailPath'], '${oldRoot}Documents/t.jpg');
  });
}
