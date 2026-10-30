@TestOn('browser')
library;

import 'dart:async';

import 'package:beauty_project/model/common/storage_image.dart';
import 'package:beauty_project/view/common/cosmetic_image.dart';
import 'package:beauty_project/view/common/storage_photo.dart';
import 'package:beauty_project/vm/common/storage_image_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 실제 공개 Firebase 파일의 CORS 문제를 검증하는 선택 실행 테스트.
// flutter test --platform chrome --dart-define=RUN_FIREBASE_WEB_TEST=true test/storage_photo_web_test.dart
void main() {
  testWidgets(
    'Firebase 사진을 HTML 이미지로 복구하고 관리자 목록에 표시한다',
    (tester) async {
      const image = StorageImage(
        bucket: 'beauty-skin-20e94.firebasestorage.app',
        objectName: '1025 독도 로션.png',
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = container.read(storageImageLoaderProvider)(
        image.downloadUri.toString(),
      );
      ImageInfo? decoded;
      await tester.runAsync(() async {
        final complete = Completer<ImageInfo>();
        final stream = provider.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (info, _) => complete.complete(info),
          onError: (Object error, StackTrace? stack) =>
              complete.completeError(error, stack),
        );
        stream.addListener(listener);
        try {
          decoded = await complete.future.timeout(const Duration(seconds: 30));
          await container.read(storageImagesProvider.future);
        } finally {
          stream.removeListener(listener);
        }
      });
      expect(decoded, isNotNull);
      expect(decoded!.sizeBytes, greaterThan(0));
      decoded?.dispose();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CosmeticImage(cosmeticIds: [], cosmeticName: '1025 독도 로션'),
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 100 && find.byType(HtmlElementView).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(find.byType(HtmlElementView), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !const bool.fromEnvironment('RUN_FIREBASE_WEB_TEST'),
  );
}
