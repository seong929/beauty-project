import 'dart:convert';
import 'dart:typed_data';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/storage_image.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_storage_service.dart';
import 'package:beauty_project/view/customer/home/home_product_gallery.dart';
import 'package:beauty_project/view/customer/home/storage_product_image.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/product/product_widgets.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const bucket = 'beauty-skin-20e94.firebasestorage.app';
const images = [
  CustomerStorageImage(bucket: bucket, objectName: '소나무 진정 시카 토너.png'),
  CustomerStorageImage(bucket: bucket, objectName: '세라마이드 아토 로션.png'),
  CustomerStorageImage(bucket: bucket, objectName: '에스트라 아토베리어365 크림.png'),
];
http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status);

void main() {
  test(
    'storage URLs encode Korean names, spaces, plus signs and slashes once',
    () {
      const image = CustomerStorageImage(
        bucket: bucket,
        objectName: '사진/시카 크림+.png',
      );
      expect(image.downloadUri.host, 'firebasestorage.googleapis.com');
      expect(image.downloadUri.pathSegments.last, '사진/시카 크림+.png');
      expect(image.downloadUri.queryParameters, {'alt': 'media'});
      expect(image.downloadUri.toString(), contains('%2F'));
      expect(image.downloadUri.toString(), contains('%2B'));
      expect(image.title, '시카 크림+');
    },
  );

  test(
    'storage paginates, filters documents, deduplicates names and sends no backend credentials',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(request.url.host, 'firebasestorage.googleapis.com');
        expect(request.headers.containsKey('authorization'), isFalse);
        if (calls == 1) {
          expect(request.url.queryParameters['pageToken'], isNull);
          return jsonResponse({
            'items': [
              {'name': '토너.png'},
              {'name': '문서.pdf'},
            ],
            'nextPageToken': 'next +/=',
          });
        }
        expect(request.url.queryParameters['pageToken'], 'next +/=');
        return jsonResponse({
          'items': [
            {'name': '로션.png'},
            {'name': '토너.png'},
            {'name': 'cosmetics/sku_1/image'},
          ],
        });
      });
      addTearDown(client.close);
      final result = await CustomerStorageService(
        client: client,
        bucket: bucket,
      ).fetchImages();
      expect(result.map((image) => image.objectName), [
        'cosmetics/sku_1/image',
        '로션.png',
        '토너.png',
      ]);
      expect(calls, 2);
    },
  );

  test(
    'empty storage succeeds while permissions, malformed rows and repeated page tokens fail',
    () async {
      for (final (data, status, fail) in [
        ({}, 200, false),
        ({'error': 'denied'}, 403, true),
        (
          {
            'items': [null],
          },
          200,
          true,
        ),
        ({'items': [], 'nextPageToken': 'same'}, 200, true),
      ]) {
        final client = MockClient((_) async => jsonResponse(data, status));
        final future = CustomerStorageService(
          client: client,
          bucket: bucket,
        ).fetchImages();
        if (fail) {
          await expectLater(future, throwsA(isA<StorageImageException>()));
        } else {
          expect(await future, isEmpty);
        }
        client.close();
      }
    },
  );

  test(
    'matches exact and SKU images before representative types and leaves unrelated products unmapped',
    () {
      CustomerProductImage? find(
        String name, {
        String id = 'sku_1',
        List<CustomerStorageImage> source = images,
      }) => findCustomerProductImage(source, productId: id, productName: name);
      expect(find('소나무진정시카토너')!.isRepresentative, isFalse);
      expect(find('수분 진정 토너')!.image, images[0]);
      expect(find('수분 진정 토너')!.isRepresentative, isTrue);
      expect(find('리페어 바디로션')!.image, images[1]);
      expect(find('보습 크림')!.image, images[2]);
      expect(find('더마 선크림'), isNull);
      expect(find('허브 샴푸'), isNull);
      expect(find('데일리 틴트'), isNull);
      expect(find('자동품의 테스트 - 재고 0'), isNull);
      expect(find('수분 진정 토너', source: []), isNull);
      const skuImage = CustomerStorageImage(
        bucket: bucket,
        objectName: 'cosmetics/sku_1/image',
      );
      expect(find('보습 크림', source: [...images, skuImage])!.image, skuImage);
      expect(
        find('보습 크림', source: [...images, skuImage])!.isRepresentative,
        isFalse,
      );
    },
  );

  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
  );

  testWidgets(
    'gallery displays ten remote images, all thirty in full view and opens zoom',
    (tester) async {
      final gallery = [
        for (var i = 0; i < 30; i++)
          CustomerStorageImage(bucket: bucket, objectName: 'image_$i.png'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerStorageImagesProvider.overrideWith((ref) async => gallery),
            customerStorageImageLoaderProvider.overrideWithValue(
              (_) => MemoryImage(pixel),
            ),
          ],
          child: MaterialApp(
            theme: SodamStyle.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const HomeProductGallery(),
                    TextButton(
                      onPressed: () => showAllCustomerProductImages(context),
                      child: const Text('전체 보기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byKey(const Key('home-product-images')))
            .childrenDelegate
            .estimatedChildCount,
        19,
      );
      await tester.tap(find.byKey(const Key('uploaded-product-1')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('상품 이미지 1 / 30'), findsOneWidget);
      await tester.tap(find.byTooltip('이미지 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 보기'));
      await tester.pumpAndSettle();
      expect(find.text('상품 이미지 30개'), findsOneWidget);
      expect(
        tester
            .widget<GridView>(find.byKey(const Key('all-product-images')))
            .childrenDelegate
            .estimatedChildCount,
        30,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'storage failure offers retry and broken images preserve layout',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerStorageImagesProvider.overrideWith((ref) async {
              if (++calls == 1) throw const CustomerAuthException('이미지 조회 실패');
              return images;
            }),
            customerStorageImageLoaderProvider.overrideWithValue(
              (_) => MemoryImage(Uint8List.fromList([0])),
            ),
          ],
          child: MaterialApp(
            theme: SodamStyle.theme,
            home: const Scaffold(body: HomeProductGallery()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retry-storage-images')), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry-storage-images')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DB product uses remote representative image while preserving real price and ID',
    (tester) async {
      const product = HomeProduct(
        id: 'mfr_seed_aurora_cat_seed_skincare_1_1',
        name: '수분 진정 토너',
        category: '스킨케어',
        price: 15900,
        imageAsset: '',
        isDatabaseProduct: true,
      );
      final loaded = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerStorageImagesProvider.overrideWith((ref) async => images),
            customerStorageImageLoaderProvider.overrideWithValue((url) {
              loaded.add(url);
              return MemoryImage(pixel);
            }),
          ],
          child: MaterialApp(
            theme: SodamStyle.theme,
            home: const Scaffold(
              body: SizedBox(
                width: 100,
                child: ProductPhoto(product: product, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loaded, contains(images.first.downloadUri.toString()));
      expect(find.text('대표 이미지'), findsOneWidget);
      expect(product.price, 15900);
      expect(product.id, 'mfr_seed_aurora_cat_seed_skincare_1_1');
      expect(tester.takeException(), isNull);
    },
  );
}
