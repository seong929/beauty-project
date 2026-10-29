import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';

// 기존 화면 모양·수량 계산 테스트에만 사용하는 로컬 대역.
// 실제 API 저장은 customer_cart_persistence_test.dart에서 검증한다.
class PreviewCartPersistence extends CartPersistenceHandler {
  @override
  Future<bool> refresh() async => true;

  @override
  Future<bool> add(
    HomeProduct product,
    HomeProductOption option,
    int quantity,
  ) async {
    ref.read(cartHandlerProvider.notifier).add(product, option, quantity);
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    ref.read(cartHandlerProvider.notifier).remove(key);
    return true;
  }

  @override
  Future<bool> clearStoredCart() async {
    ref.read(cartHandlerProvider.notifier).clear();
    return true;
  }
}
