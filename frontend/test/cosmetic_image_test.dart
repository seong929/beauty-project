import 'dart:convert';
import 'dart:typed_data';

import 'package:beauty_project/view/common/cosmetic_image.dart';
import 'package:beauty_project/vm/admin/management_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('없는 이미지와 깨진 이미지를 건너뛰고 첫 성공 옵션을 표시한다', (tester) async {
    final queried = <String>[];
    final loaded = <String>[];
    final pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cosmeticImageProvider.overrideWith((ref, id) async {
            queried.add(id);
            return id == 'missing' ? null : id;
          }),
          cosmeticImageLoaderProvider.overrideWithValue((url) {
            loaded.add(url);
            return MemoryImage(
              url == 'broken' ? Uint8List.fromList([0]) : pixel,
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CosmeticImage(
              cosmeticIds: ['missing', 'broken', 'valid', 'unused'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(queried, ['missing', 'broken', 'valid']);
    expect(loaded, contains('valid'));
    expect(find.byKey(const ValueKey('valid')), findsOneWidget);
  });
}
