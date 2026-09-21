import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_movenet/src/app.dart';
import 'package:flutter_movenet/src/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => <String, Object>{},
        );
    appRouter.go('/');
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('화면 이동과 뒤로가기가 슬라이드된다 (${platform.name})', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(const ProviderScope(child: MovenetApp()));
      await tester.pumpAndSettle();
      final homeTitle = find.text('AI 자세 분석');
      final start = tester.getTopLeft(homeTitle).dx;

      // 이동 도중에는 홈이 아직 보이며 왼쪽으로 밀려나는 중이다.
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(homeTitle).dx, lessThan(start));
      await tester.pumpAndSettle();
      expect(homeTitle, findsNothing);

      // 뒤로가기 도중에도 홈이 제자리로 돌아오는 중이다.
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(homeTitle).dx, lessThan(start));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(homeTitle).dx, start);

      debugDefaultTargetPlatformOverride = null;
    });
  }
}
