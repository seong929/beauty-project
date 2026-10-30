import 'dart:convert';

import 'package:beauty_project/model/common/storage_image.dart';
import 'package:beauty_project/view/common/cosmetic_image.dart';
import 'package:beauty_project/view/common/storage_photo.dart';
import 'package:beauty_project/vm/admin/management_vm.dart';
import 'package:beauty_project/vm/common/storage_image_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
  );
  const named = StorageImage(bucket: 'test', objectName: '토너.png');
  const canonical = StorageImage(
    bucket: 'test',
    objectName: 'cosmetics/second/image',
  );

  for (final ids in [
    <String>[],
    ['first', 'second'],
  ]) {
    testWidgets('공개 사진 조회: 옵션 ID $ids', (tester) async {
      final privateReads = <String>[];
      final loaded = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageImagesProvider.overrideWith(
              (ref) async => [named, canonical],
            ),
            cosmeticImageProvider.overrideWith((ref, id) async {
              privateReads.add(id);
              return null;
            }),
            cosmeticImageLoaderProvider.overrideWithValue((url) {
              loaded.add(url);
              return MemoryImage(pixel);
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CosmeticImage(cosmeticIds: ids, cosmeticName: '토너'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        loaded,
        contains((ids.isEmpty ? named : canonical).downloadUri.toString()),
      );
      expect(find.byType(StoragePhoto), findsOneWidget);
      expect(privateReads, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('목록 로딩 실패 후 새로고침하면 사진을 다시 표시한다', (tester) async {
    var failed = true;
    final container = ProviderContainer(
      overrides: [
        storageImagesProvider.overrideWith((ref) async {
          if (failed) throw Exception('offline');
          return [named];
        }),
        cosmeticImageLoaderProvider.overrideWithValue(
          (url) => MemoryImage(pixel),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: CosmeticImage(cosmeticIds: [], cosmeticName: '토너'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    failed = false;
    container.invalidate(storageImagesProvider);
    await tester.pumpAndSettle();
    expect(find.byType(StoragePhoto), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
