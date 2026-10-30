import 'dart:convert';

import 'package:beauty_project/app/admin_app.dart';
import 'package:beauty_project/app/customer_app.dart';
import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/model/common/storage_image.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/service/auth/auth_service.dart';
import 'package:beauty_project/service/common/storage_service.dart';
import 'package:beauty_project/view/auth/login_page.dart';
import 'package:beauty_project/view/admin/admin_dashboard_page.dart';
import 'package:beauty_project/view/common/cosmetic_image.dart';
import 'package:beauty_project/view/customer/home/storage_product_image.dart';
import 'package:beauty_project/view/customer/login/customer_login_screen.dart';
import 'package:beauty_project/view/customer/product/product_widgets.dart';
import 'package:beauty_project/vm/admin/management_vm.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _AdminLogin extends AuthService {
  const _AdminLogin() : super(baseUrl: 'http://localhost');
  @override
  Future<EmployeeLogin> login({
    required String loginId,
    required String password,
  }) async => const EmployeeLogin(
    accessToken: 'test',
    tokenType: 'bearer',
    expiresIn: 3600,
    employeeId: 'admin',
    employeeRole: 'ADMIN',
  );
}

void main() {
  testWidgets(
    'customer entry remains customer-only with an active employee session',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) => const _AdminLogin()),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authProvider.notifier)
          .login(loginId: 'admin', password: 'password');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CustomerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomerLoginScreen), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(AdminDashboardPage), findsNothing);
      expect(find.text('로그인 유형 선택'), findsNothing);
    },
  );

  testWidgets(
    'admin entry logs in at the root and logs out to admin login only',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) => const _AdminLogin()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(CustomerLoginScreen), findsNothing);
      expect(find.text('배송업체 로그인'), findsNothing);
      await tester.enterText(find.byType(TextField).at(0), 'admin');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardPage), findsOneWidget);
      container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(CustomerLoginScreen), findsNothing);
      expect(find.text('로그인 유형 선택'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'shared list traverses admin upload folders and paginates each prefix',
    () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        final prefix = request.url.queryParameters['prefix'] ?? '';
        final next = request.url.queryParameters['pageToken'];
        paths.add('$prefix:${next ?? ''}');
        expect(request.headers.containsKey('authorization'), isFalse);
        final Object body = switch ((prefix, next)) {
          ('', null) => {
            'items': [
              {'name': '토너+.png'},
            ],
            'prefixes': ['cosmetics/'],
          },
          ('cosmetics/', null) => {
            'prefixes': ['cosmetics/sku/'],
          },
          ('cosmetics/sku/', null) => {
            'items': [
              {'name': 'cosmetics/sku/image'},
            ],
            'nextPageToken': 'next',
          },
          ('cosmetics/sku/', 'next') => {
            'items': [
              {'name': 'cosmetics/sku/extra.webp'},
            ],
          },
          _ => throw StateError('unexpected folder'),
        };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      });
      addTearDown(client.close);
      final service = StorageService(
        client: client,
        bucket: 'beauty-skin-20e94.firebasestorage.app',
      );
      final result = await service.fetchImages();
      expect(paths, [
        ':',
        'cosmetics/:',
        'cosmetics/sku/:',
        'cosmetics/sku/:next',
      ]);
      final match = findProductStorageImage(
        result,
        productId: 'sku',
        productName: '토너',
      );
      expect(match!.image.objectName, 'cosmetics/sku/image');
      expect(match.isRepresentative, isFalse);
      expect(match.image.downloadUri.queryParameters['v'], isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final refreshed = await service.fetchImages();
      expect(refreshed.first.downloadUri, isNot(result.first.downloadUri));
      expect(
        identical(storageImagesProvider, customerStorageImagesProvider),
        isTrue,
      );
      expect(
        identical(productStorageImageProvider, customerProductImageProvider),
        isTrue,
      );
    },
  );

  testWidgets(
    'customer and admin render the same public image and refresh after replacement',
    (tester) async {
      const bucket = 'beauty-skin-20e94.firebasestorage.app';
      var version = '1';
      final customerUrls = <String>[];
      final pixel = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
      );
      var privateReads = 0;
      final container = ProviderContainer(
        overrides: [
          storageImagesProvider.overrideWith(
            (ref) async => [
              StorageImage(
                bucket: bucket,
                objectName: 'cosmetics/sku/image',
                version: version,
              ),
            ],
          ),
          cosmeticImageProvider.overrideWith((ref, id) async {
            privateReads++;
            return null;
          }),
          customerStorageImageLoaderProvider.overrideWithValue((url) {
            customerUrls.add(url);
            return MemoryImage(pixel);
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: ProductPhoto(
                      product: HomeProduct(
                        id: 'sku',
                        name: '토너',
                        category: '스킨',
                        price: 15000,
                        imageAsset: '',
                        isDatabaseProduct: true,
                      ),
                    ),
                  ),
                  CosmeticImage(cosmeticIds: ['sku'], cosmeticName: '토너'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        identical(
          cosmeticImageLoaderProvider,
          customerStorageImageLoaderProvider,
        ),
        isTrue,
      );
      expect(find.byType(StoragePhoto), findsNWidgets(2));
      final initialPhotos = tester
          .widgetList<StoragePhoto>(find.byType(StoragePhoto))
          .toList();
      expect(
        initialPhotos.first.image.downloadUri,
        initialPhotos.last.image.downloadUri,
      );
      expect(Uri.parse(customerUrls.last).queryParameters['v'], '1');
      version = '2';
      container.invalidate(storageImagesProvider);
      await tester.pumpAndSettle();
      final refreshedPhotos = tester
          .widgetList<StoragePhoto>(find.byType(StoragePhoto))
          .toList();
      expect(
        refreshedPhotos.first.image.downloadUri,
        refreshedPhotos.last.image.downloadUri,
      );
      expect(Uri.parse(customerUrls.last).queryParameters['v'], '2');
      expect(privateReads, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
