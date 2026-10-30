import 'dart:convert';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// 결제 회귀 테스트의 재고 조회 응답. 변동·통신 실패는 재고 전용 테스트로 검증한다.
http.Client withCatalogFixture(
  http.Client delegate,
  List<HomeProduct> products, {
  int? pointsBalance,
}) => MockClient((request) async {
  if (pointsBalance != null &&
      request.method == 'GET' &&
      request.url.path.endsWith('/customer_points')) {
    return http.Response(
      jsonEncode({
        'customer_id': request.url.queryParameters['customer_id'],
        'balance': pointsBalance,
        'history': [],
      }),
      200,
    );
  }
  if (request.method == 'GET' &&
      request.url.path.endsWith('/customers_categories_search')) {
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'result': [
            for (final product in products)
              {
                'cosmetic_id': product.id,
                'cosmetic_name': product.name,
                'manufacturer_name': product.brand,
                'category_name': product.category,
                'volume_text': product.volume,
                'sale_price': product.price,
                'available_quantity': product.availableQuantity,
              },
          ],
        }),
      ),
      200,
    );
  }
  final copy = http.Request(request.method, request.url)
    ..headers.addAll(request.headers)
    ..bodyBytes = request.bodyBytes;
  return http.Response.fromStream(await delegate.send(copy));
});
