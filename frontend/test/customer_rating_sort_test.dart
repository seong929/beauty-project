import 'dart:convert';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/review.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_review_service.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/product/product_list.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> row(String id, int rating, int number) => {
  'review_id': 'rev_$number',
  'customer_id': 'customer_$number',
  'cosmetic_id': id,
  'review_content': 'review',
  'rating': rating,
};
http.Response response(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status);

final products = [
  for (final (i, name) in [
    'No reviews',
    'Rated four',
    'Rated five',
    'More reviews',
  ].indexed)
    HomeProduct(
      id: 'sku_$i',
      name: name,
      brand: 'Sodam',
      category: 'Care',
      price: 10000 + i * 1000,
      imageAsset: '',
      isDatabaseProduct: true,
      volume: '50ml',
      availableQuantity: 10,
      catalogOptions: [
        HomeProductOption(label: '50ml', price: 10000 + i * 1000),
      ],
    ),
];

void main() {
  test(
    'rating sort uses actual averages, breaks ties by count, and places unrated last',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/reviews_select');
        expect(request.url.queryParameters, isEmpty);
        return response({
          'result': [
            row('sku_1', 3, 1),
            row('sku_1', 5, 2),
            row('sku_2', 5, 3),
            row('sku_3', 5, 4),
            row('sku_3', 5, 5),
          ],
        });
      });
      final container = ProviderContainer(
        overrides: [
          homeCatalogProductsProvider.overrideWithValue(AsyncData(products)),
          customerHttpClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final subscription = container.listen(
        catalogProductRatingsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      container
          .read(productFilterProvider.notifier)
          .apply(inStockOnly: false, sort: ProductSort.ratingHigh);
      await container.read(catalogProductRatingsProvider.future);
      expect(
        container.read(homeProductVariantsProvider).map((p) => p.product.id),
        ['sku_3', 'sku_2', 'sku_1', 'sku_0'],
      );
      expect(container.read(homeProductsProvider).map((p) => p.id), [
        'sku_3',
        'sku_2',
        'sku_1',
        'sku_0',
      ]);
      expect(calls, 1);
      container.read(productFilterProvider.notifier).search('Rated');
      expect(
        container.read(homeProductVariantsProvider).map((p) => p.product.id),
        ['sku_2', 'sku_1'],
      );
      expect(calls, 1);
    },
  );

  test(
    'every capacity uses the base product rating and ties preserve catalog order',
    () {
      final variants = [
        for (final product in homePreviewProducts.take(3))
          for (final option in product.options)
            HomeProductVariant(product: product, option: option),
      ];
      final rating = ReviewStatistics([
        CustomerReview.fromJson(row('preview_2', 5, 1)),
      ]);
      final result = filterProducts(
        variants,
        const ProductFilter(sort: ProductSort.ratingHigh),
        ratings: {'preview_2': rating},
      );
      expect(
        result.take(4).map((p) => p.product.id),
        everyElement('preview_2'),
      );
      expect(result.take(4).map((p) => p.volume), [
        '30ml',
        '50ml',
        '100ml',
        '200ml',
      ]);
      expect(result.skip(4).first.product.id, 'preview_1');
    },
  );

  test(
    'invalid rating rows fail rather than silently inventing a score',
    () async {
      final client = MockClient(
        (_) async => response({
          'result': [row('sku_1', 6, 1)],
        }),
      );
      addTearDown(client.close);
      await expectLater(
        CustomerReviewService(
          client: client,
          baseUrl: Uri.parse('http://localhost/'),
        ).fetchProductRatings(),
        throwsA(isA<CustomerAuthException>()),
      );
    },
  );

  testWidgets(
    'search exposes rating sorting, retries failures, and updates after review changes',
    (tester) async {
      var fail = true;
      var calls = 0;
      var topProduct = 'sku_2';
      final client = MockClient((_) async {
        calls++;
        return fail
            ? response({'detail': 'offline'}, 503)
            : response({
                'result': [row(topProduct, 5, 1)],
              });
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeCatalogProductsProvider.overrideWithValue(AsyncData(products)),
            customerHttpClientProvider.overrideWithValue(client),
          ],
          child: MaterialApp(
            theme: SodamStyle.theme,
            home: const CustomerProductListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerProductListScreen)),
      );
      await tester.tap(find.byKey(const Key('product-search-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('정렬 : 별점 높은 순').last);
      await tester.pumpAndSettle();
      expect(find.text('별점을 불러오지 못했어요.'), findsOneWidget);
      expect(find.byKey(const Key('search-product-sku_2:50ml')), findsNothing);
      fail = false;
      await tester.tap(find.text('별점 다시 조회'));
      await tester.pumpAndSettle();
      expect(
        container.read(homeProductVariantsProvider).first.product.id,
        'sku_2',
      );
      expect(find.byKey(const Key('card-rating-sku_2:50ml')), findsOneWidget);
      topProduct = 'sku_1';
      container.invalidate(catalogProductRatingsProvider);
      await tester.pumpAndSettle();
      expect(
        container.read(homeProductVariantsProvider).first.product.id,
        'sku_1',
      );
      expect(calls, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
