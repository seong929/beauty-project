import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/cart_item.dart';
import 'package:beauty_project/model/customer/cosmetic.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_cart_service.dart';
import 'cart_handler.dart';
import 'customer_handler.dart';
import 'customer_providers.dart';
import 'product_handler.dart';

final customerCartServiceProvider = Provider<CustomerCartService>(
  (ref) => CustomerCartService(
    client: ref.watch(customerHttpClientProvider),
    baseUrl: ref.watch(customerApiBaseUrlProvider),
  ),
);

class CartPersistenceHandler extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  bool _current(String customerId) =>
      ref.mounted &&
      ref.read(customerHandlerProvider).value?.customerId == customerId;

  String _customerId() {
    final id = ref.read(customerHandlerProvider).value?.customerId;
    if (id == null || id.isEmpty) {
      throw const CustomerAuthException('로그인 후 장바구니를 이용해 주세요.');
    }
    return id;
  }

  Future<bool> refresh() => _run((id) => _load(id));

  Future<bool> add(
    HomeProduct product,
    HomeProductOption option,
    int quantity,
  ) => _run((id) async {
    if (!product.isDatabaseProduct ||
        product.id.isEmpty ||
        product.id.startsWith('preview_')) {
      throw const CustomerAuthException(
        '예시 상품은 DB에 저장할 수 없습니다. 실제 상품 목록에서 선택해 주세요.',
      );
    }
    if (quantity < 1 ||
        quantity > 99 ||
        !product.options.any(
          (size) => size.label == option.label && size.price == option.price,
        )) {
      throw const CustomerAuthException('상품의 용량과 수량을 다시 확인해 주세요.');
    }
    await ref.read(customerCartServiceProvider).add(id, product.id);
    if (_current(id)) {
      ref.read(cartHandlerProvider.notifier).add(product, option, quantity);
    }
  });

  Future<bool> remove(String key) => _run((id) async {
    final local = ref.read(cartHandlerProvider);
    final item = local.where((item) => item.key == key).firstOrNull;
    if (item == null) return;
    await ref.read(customerCartServiceProvider).remove(id, item.product.id);
    if (_current(id)) {
      ref
          .read(cartHandlerProvider.notifier)
          .replaceFromServer(
            ref
                .read(cartHandlerProvider)
                .where((line) => line.product.id != item.product.id)
                .toList(),
          );
    }
  });

  Future<bool> clearStoredCart() => _run((id) async {
    // 서버의 전체 목록을 기준으로 삭제하여 앱에서 아직 읽지 않은 상품도 지운다.
    final service = ref.read(customerCartServiceProvider);
    final rows = await service.fetch(id);
    for (final row in rows) {
      if (!_current(id)) return;
      final productId = row['cosmetic_id'] as String;
      await service.remove(id, productId);
      if (_current(id)) {
        ref
            .read(cartHandlerProvider.notifier)
            .replaceFromServer(
              ref
                  .read(cartHandlerProvider)
                  .where((line) => line.product.id != productId)
                  .toList(),
            );
      }
    }
    if (_current(id)) ref.read(cartHandlerProvider.notifier).clear();
  });

  Future<void> _load(String id) async {
    final rows = await ref.read(customerCartServiceProvider).fetch(id);
    if (!_current(id)) return;
    if (rows.isEmpty) {
      ref.read(cartHandlerProvider.notifier).clear();
      return;
    }
    var catalog = <Cosmetic>[];
    var missingCatalog = false;
    try {
      catalog = await ref.read(productHandlerProvider.future);
    } catch (_) {
      missingCatalog = true;
    }
    if (!_current(id)) return;
    final products = {
      for (final product in catalog)
        product.id: HomeProduct.fromCatalog(product),
    };
    final previous = {
      for (final item in ref.read(cartHandlerProvider)) item.product.id: item,
    };
    final items = [for (final row in rows) _restore(row, products, previous)];
    ref.read(cartHandlerProvider.notifier).replaceFromServer(items);
    if (missingCatalog) {
      throw const CustomerAuthException(
        '저장된 상품은 불러왔지만 판매 정보 조회에 실패했습니다. 다시 조회해 주세요.',
      );
    }
  }

  CustomerCartItem _restore(
    Map<String, dynamic> row,
    Map<String, HomeProduct> products,
    Map<String, CustomerCartItem> previous,
  ) {
    final id = row['cosmetic_id'] as String;
    final product = products[id] ?? HomeProduct.unavailableCartProduct(row);
    final old = previous[id];
    return CustomerCartItem(
      product: product,
      option: product.options.first,
      quantity: old?.quantity ?? 1,
      selected: product.hasKnownPrice && (old?.selected ?? true),
    );
  }

  Future<bool> _run(Future<void> Function(String) action) async {
    if (state.isLoading) return false;
    String? id;
    state = const AsyncLoading();
    try {
      id = _customerId();
      await action(id);
      if (!_current(id)) return false;
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (ref.mounted && (id == null || _current(id))) {
        state = AsyncError(error, stack);
      }
      return false;
    }
  }
}

final cartPersistenceProvider =
    AsyncNotifierProvider<CartPersistenceHandler, void>(
      CartPersistenceHandler.new,
    );
