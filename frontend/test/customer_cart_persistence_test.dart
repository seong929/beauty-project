import 'dart:async';
import 'dart:convert';

import 'package:beauty_project/model/customer/cosmetic.dart';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/product/product_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/storage_catalog.dart';

const customerId = 'cus_stored';
const productId = 'mfr_1_cat_skin_1_1';
const product = Cosmetic(
  id: productId,
  name: '저장 테스트 로션',
  brand: '실제 제조사',
  category: '스킨케어',
  volume: '150ml',
  price: 18000,
  availableQuantity: 10,
);

class StoredCustomer extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: customerId,
    loginId: 'stored',
    name: '저장고객',
    email: 'stored@example.com',
    address: '서울시',
    phone: '01012345678',
  );
}

class StoredCatalog extends ProductHandler {
  @override
  Future<List<Cosmetic>> build() async => [product];
}

class UnavailableCatalog extends ProductHandler {
  @override
  Future<List<Cosmetic>> build() async =>
      throw const CustomerAuthException('판매 정보 조회 실패');
}

http.Response response(Object data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> storedRow(String id) => {
  'customer_id': customerId,
  'cosmetic_id': id,
  'cosmetic_name': '저장 테스트 로션',
  'manufacturer_name': '실제 제조사',
  'category_name': '스킨케어',
  'normal_quantity': 10,
  'near_expiry_quantity': 0,
};

class CartServer {
  final ids = <String>{};
  int writes = 0;
  bool failAdd = false;
  bool failDelete = false;
  bool conflictWithoutRow = false;

  Future<http.Response> handle(http.Request request) async {
    if (request.method == 'GET') {
      expect(request.url.path, '/incart_select');
      expect(request.url.queryParameters, {'customer_id': customerId});
      return response({'result': ids.map(storedRow).toList()});
    }
    expect(request.bodyFields.keys.toSet(), {'customer_id', 'cosmetic_id'});
    expect(request.bodyFields['customer_id'], customerId);
    final id = request.bodyFields['cosmetic_id']!;
    if (request.method == 'POST') {
      expect(request.url.path, '/incart_upload');
      writes++;
      if (failAdd) return response({}, 500);
      if (conflictWithoutRow || !ids.add(id)) {
        return response({'detail': '중복 또는 잘못된 참조'}, 409);
      }
      return response({'result': 'OK'});
    }
    expect(request.method, 'DELETE');
    expect(request.url.path, '/incart_delete');
    if (failDelete) return response({}, 500);
    ids.remove(id);
    return response({'result': 'OK', 'deleted_count': 1});
  }
}

ProviderContainer containerWith(
  Future<http.Response> Function(http.Request) handle, {
  bool catalogAvailable = true,
}) {
  final client = MockClient(handle);
  final container = ProviderContainer(
    overrides: [
      customerHandlerProvider.overrideWith(StoredCustomer.new),
      customerHttpClientProvider.overrideWithValue(client),
      customerApiBaseUrlProvider.overrideWithValue(
        Uri.parse('http://localhost:8000/'),
      ),
      productHandlerProvider.overrideWith(
        catalogAvailable ? StoredCatalog.new : UnavailableCatalog.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(client.close);
  return container;
}

void main() {
  test(
    'stores the real IDs and restores the row after replacing all app state',
    () async {
      final server = CartServer();
      final first = containerWith(server.handle);
      final realProduct = HomeProduct.fromCatalog(product);
      expect(
        await first
            .read(cartPersistenceProvider.notifier)
            .add(realProduct, realProduct.options.first, 3),
        isTrue,
      );
      expect(server.ids, {productId});
      expect(first.read(cartHandlerProvider).single.quantity, 3);
      first.dispose();

      final second = containerWith(server.handle);
      expect(
        await second.read(cartPersistenceProvider.notifier).refresh(),
        isTrue,
      );
      final restored = second.read(cartHandlerProvider).single;
      expect(restored.product.id, productId);
      expect(restored.option.label, '150ml');
      expect(restored.option.price, 18000);
      // 기존 API/테이블에는 수량 저장 필드가 없어 새 세션은 1개로 시작한다.
      expect(restored.quantity, 1);
    },
  );

  test(
    'does not show a successful local add if the server fails or a preview ID is supplied',
    () async {
      final server = CartServer()..failAdd = true;
      final container = containerWith(server.handle);
      final sync = container.read(cartPersistenceProvider.notifier);
      final realProduct = HomeProduct.fromCatalog(product);
      expect(
        await sync.add(realProduct, realProduct.options.first, 1),
        isFalse,
      );
      expect(container.read(cartHandlerProvider), isEmpty);
      expect(container.read(cartPersistenceProvider).hasError, isTrue);
      final calls = server.writes;
      expect(
        await sync.add(
          homePreviewProducts.first,
          homePreviewProducts.first.options.first,
          1,
        ),
        isFalse,
      );
      expect(server.writes, calls);
    },
  );

  test(
    'handles duplicate adds only when the server confirms the row exists',
    () async {
      final server = CartServer()..ids.add(productId);
      final container = containerWith(server.handle);
      final sync = container.read(cartPersistenceProvider.notifier);
      final realProduct = HomeProduct.fromCatalog(product);
      expect(await sync.add(realProduct, realProduct.options.first, 1), isTrue);
      expect(await sync.add(realProduct, realProduct.options.first, 2), isTrue);
      expect(server.ids, hasLength(1));
      expect(container.read(cartHandlerProvider).single.quantity, 3);
      server.ids.clear();
      server.conflictWithoutRow = true;
      expect(
        await sync.add(realProduct, realProduct.options.first, 1),
        isFalse,
      );
      expect(container.read(cartHandlerProvider).single.quantity, 3);
    },
  );

  test(
    'delete keeps local state on error and removes both server and local rows on success',
    () async {
      final server = CartServer()..ids.add(productId);
      final container = containerWith(server.handle);
      final sync = container.read(cartPersistenceProvider.notifier);
      await sync.refresh();
      final key = container.read(cartHandlerProvider).single.key;
      server.failDelete = true;
      expect(await sync.remove(key), isFalse);
      expect(container.read(cartHandlerProvider), hasLength(1));
      expect(server.ids, {productId});
      server.failDelete = false;
      expect(await sync.remove(key), isTrue);
      expect(container.read(cartHandlerProvider), isEmpty);
      expect(server.ids, isEmpty);
    },
  );

  test(
    'clear reads the server list and deletes rows not yet loaded by the app',
    () async {
      final server = CartServer()
        ..ids.addAll([productId, 'mfr_2_cat_body_1_1']);
      final container = containerWith(server.handle);
      expect(
        await container
            .read(cartPersistenceProvider.notifier)
            .clearStoredCart(),
        isTrue,
      );
      expect(server.ids, isEmpty);
    },
  );

  test(
    'duplicate taps and late responses after logout do not change a new session',
    () async {
      final pending = Completer<http.Response>();
      var requests = 0;
      final container = containerWith((_) {
        requests++;
        return pending.future;
      });
      final sync = container.read(cartPersistenceProvider.notifier);
      final realProduct = HomeProduct.fromCatalog(product);
      final first = sync.add(realProduct, realProduct.options.first, 1);
      expect(
        await sync.add(realProduct, realProduct.options.first, 1),
        isFalse,
      );
      container.read(customerHandlerProvider.notifier).logout();
      pending.complete(response({'result': 'OK'}));
      expect(await first, isFalse);
      expect(container.read(cartHandlerProvider), isEmpty);
      expect(requests, 1);
    },
  );

  test(
    'restores unavailable products without inventing a zero-price purchase',
    () async {
      final server = CartServer()..ids.add(productId);
      final container = containerWith(server.handle, catalogAvailable: false);
      expect(
        await container.read(cartPersistenceProvider.notifier).refresh(),
        isFalse,
      );
      expect(container.read(cartHandlerProvider).single.product.id, productId);
      expect(
        container.read(cartHandlerProvider).single.product.hasKnownPrice,
        isFalse,
      );
      expect(container.read(selectedCartItemsProvider), isEmpty);
    },
  );

  testWidgets('real catalog card saves through HTTP and cart page reloads it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = CartServer();
    final client = MockClient(server.handle);
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...storageCatalogOverrides([HomeProduct.fromCatalog(product)]),
          customerHandlerProvider.overrideWith(StoredCustomer.new),
          productHandlerProvider.overrideWith(StoredCatalog.new),
          customerHttpClientProvider.overrideWithValue(client),
          customerApiBaseUrlProvider.overrideWithValue(
            Uri.parse('http://localhost:8000/'),
          ),
        ],
        child: MaterialApp(
          theme: SodamStyle.theme,
          home: const CustomerProductListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1개의 상품'), findsOneWidget);
    expect(find.text('150ml'), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-product-$productId:150ml')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-product-to-cart')));
    await tester.pumpAndSettle();
    expect(server.ids, {productId});
    expect(find.text('장바구니에 담았어요.'), findsOneWidget);
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-cart-screen')), findsOneWidget);
    expect(find.text('합계 18,000원'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
