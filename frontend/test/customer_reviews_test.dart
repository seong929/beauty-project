import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/review.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_review_service.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/mypage/mypage_screen.dart';
import 'package:beauty_project/view/customer/product/product_detail.dart';
import 'package:beauty_project/view/customer/review/customer_review_list_screen.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/checkout_steps.dart';

class _Customer extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'cus_1',
    loginId: 'sodam',
    name: '소담고객',
    email: 'sodam@example.com',
    phone: '01012345678',
    address: '서울시',
  );
}

final _products = [
  for (var i = 1; i <= 2; i++)
    HomeProduct(
      id: 'sku_$i',
      name: i == 1 ? '수분 진정 세럼' : '보습 크림',
      brand: '소담',
      category: '스킨케어',
      price: 28000,
      imageAsset: homePreviewProducts[i - 1].imageAsset,
      volume: '50ml',
      isDatabaseProduct: true,
      availableQuantity: 10,
      catalogOptions: const [HomeProductOption(label: '50ml', price: 28000)],
    ),
];

http.Response _json(Object data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

class _ReviewServer {
  final requests = <http.Request>[];
  final eligible = <String>{'sku_1'};
  final rows = <Map<String, dynamic>>[
    {
      'review_id': 'rev_1',
      'customer_id': 'cus_other',
      'customer_name': '다른구매자',
      'cosmetic_id': 'sku_1',
      'cosmetic_name': '수분 진정 세럼',
      'review_content': '촉촉하고 만족스러워요.',
      'rating': 5,
      'reviewed_at': '2026-10-28T13:30:00',
    },
  ];
  String? failMethod;
  int get writes => requests.where((request) => request.method != 'GET').length;
  Map<String, dynamic> addMine() {
    final row = {
      ...rows.first,
      'review_id': 'rev_2',
      'customer_id': 'cus_1',
      'customer_name': '소담고객',
      'review_content': '기존 리뷰 내용',
      'rating': 3,
    };
    rows.add(row);
    return row;
  }

  late final client = MockClient((request) async {
    requests.add(request);
    switch (request.url.path) {
      case '/reviews_select':
        return _json({
          'result': rows
              .where(
                (row) =>
                    (request.url.queryParameters['customer_id'] == null ||
                        row['customer_id'] ==
                            request.url.queryParameters['customer_id']) &&
                    (request.url.queryParameters['cosmetic_id'] == null ||
                        row['cosmetic_id'] ==
                            request.url.queryParameters['cosmetic_id']),
              )
              .toList(),
        });
      case '/reviews_eligibility':
        expect(request.url.queryParameters['customer_id'], 'cus_1');
        return _json({
          'result': [
            for (final id in eligible) {'cosmetic_id': id},
          ],
        });
      case '/reviews_upload':
      case '/reviews_update':
      case '/reviews_delete':
        if (request.method == failMethod) {
          return _json({'detail': '리뷰 요청이 거절되었습니다.'}, 409);
        }
        final form = request.bodyFields;
        expect(form['customer_id'], 'cus_1');
        if (request.method == 'POST') {
          expect(form.keys.toSet(), {
            'customer_id',
            'cosmetic_id',
            'review_content',
            'rating',
          });
          if (!eligible.contains(form['cosmetic_id'])) {
            return _json({'detail': '배송 완료된 구매 상품만 리뷰를 작성할 수 있습니다.'}, 403);
          }
          if (rows.any(
            (row) =>
                row['customer_id'] == 'cus_1' &&
                row['cosmetic_id'] == form['cosmetic_id'],
          )) {
            return _json({'detail': '이미 리뷰가 있습니다.'}, 409);
          }
          final row = {
            'review_id': 'rev_10',
            'customer_id': 'cus_1',
            'customer_name': '소담고객',
            'cosmetic_id': form['cosmetic_id'],
            'cosmetic_name': '수분 진정 세럼',
            'review_content': form['review_content'],
            'rating': int.parse(form['rating']!),
            'reviewed_at': '2026-10-29T14:00:00',
          };
          rows.add(row);
          return _json({'result': 'OK', ...row});
        }
        final row = rows
            .where((row) => row['review_id'] == form['review_id'])
            .firstOrNull;
        if (row == null) return _json({'detail': '리뷰가 없습니다.'}, 404);
        if (row['customer_id'] != form['customer_id']) {
          return _json({'detail': '작성자만 변경할 수 있습니다.'}, 403);
        }
        if (request.method == 'PUT') {
          row['review_content'] = form['review_content'];
          row['rating'] = int.parse(form['rating']!);
        } else {
          rows.remove(row);
        }
        return _json({
          'result': 'OK',
          'review_id': row['review_id'],
          'customer_id': row['customer_id'],
          'cosmetic_id': row['cosmetic_id'],
          if (request.method == 'DELETE') 'deleted_count': 1,
        });
      case '/orders':
        return _json({
          'results': [
            for (var i = 1; i <= 2; i++)
              {
                'order_id': 'ord_1',
                'order_item_id': 'ord_1_$i',
                'customer_id': 'cus_1',
                'order_status': 'SHIPPED',
                'shipping_address': '서울시',
                'order_date': '2026-10-25T10:00:00',
                'cosmetic_id': 'sku_$i',
                'product_name': _products[i - 1].name,
                'quantity': 1,
                'unit_price': 28000,
                'order_total_amount': 56000,
                'sale_option': 'NORMAL',
                'delivery_id': 'dlv_$i',
              },
          ],
        });
      default:
        return _json({'result': []});
    }
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    _ReviewServer server, {
    Widget? home,
    Size size = const Size(390, 844),
    GlobalKey? capture,
  }) async {
    home ??= CustomerProductDetailScreen(product: _products.first);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(server.client),
          homeCatalogProductsProvider.overrideWithValue(AsyncData(_products)),
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SodamStyle.theme,
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(home.runtimeType)),
    );
  }

  Future<void> rateAndWrite(
    WidgetTester tester,
    int rating,
    String content,
  ) async {
    await tapCheckoutControl(tester, 'review-rating-$rating');
    await tester.enterText(find.byKey(const Key('review-content')), content);
    await tester.pumpAndSettle();
  }

  test(
    'statistics use all ratings and distinguish an empty list from a zero rating',
    () {
      final server = _ReviewServer();
      final reviews = [
        for (final score in [5, 4, 1])
          CustomerReview.fromJson({...server.rows.first, 'rating': score}),
      ];
      final stats = ReviewStatistics(reviews);
      expect(stats.count, 3);
      expect(stats.averageLabel, '3.3');
      expect(stats.counts[5], 1);
      expect(stats.counts[3], 0);
      expect(ReviewStatistics([]).averageLabel, '—');
    },
  );

  test(
    'invalid rating and another product response cannot enter the displayed statistics',
    () async {
      final row = _ReviewServer().rows.first;
      expect(
        () => CustomerReview.fromJson({...row, 'rating': 6}),
        throwsFormatException,
      );
      final service = CustomerReviewService(
        baseUrl: Uri.parse('http://test/'),
        client: MockClient(
          (_) async => _json({
            'result': [row],
          }),
        ),
      );
      await expectLater(
        service.fetch(productId: 'different_product'),
        throwsA(isA<CustomerAuthException>()),
      );
      await expectLater(
        service.fetch(customerId: 'cus_1'),
        throwsA(isA<CustomerAuthException>()),
      );
    },
  );

  test(
    'client rejects blank text and out-of-range ratings without sending a mutation',
    () async {
      final server = _ReviewServer();
      final service = CustomerReviewService(
        client: server.client,
        baseUrl: Uri.parse('http://test/'),
      );
      for (final score in [0, 6]) {
        await expectLater(
          service.save(
            customerId: 'cus_1',
            productId: 'sku_1',
            content: '리뷰',
            rating: score,
          ),
          throwsException,
        );
      }
      await expectLater(
        service.save(
          customerId: 'cus_1',
          productId: 'sku_1',
          content: ' ',
          rating: 5,
        ),
        throwsException,
      );
      expect(server.writes, 0);
    },
  );

  test(
    'pending mutation is submitted once and a late result cannot update logout state',
    () async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final container = ProviderContainer(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(
            MockClient((_) {
              writes++;
              return pending.future;
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      final handler = container.read(reviewMutationProvider.notifier);
      final first = handler.save(productId: 'sku_1', content: '좋아요', rating: 5);
      await Future<void>.delayed(Duration.zero);
      expect(
        await handler.save(productId: 'sku_1', content: '좋아요', rating: 5),
        isFalse,
      );
      expect(writes, 1);
      container.read(customerHandlerProvider.notifier).logout();
      pending.complete(
        _json({
          'result': 'OK',
          'review_id': 'rev_9',
          'customer_id': 'cus_1',
          'cosmetic_id': 'sku_1',
        }),
      );
      expect(await first, isFalse);
    },
  );

  test('another authors review cannot be mutated by the view model', () async {
    final server = _ReviewServer();
    final foreign = CustomerReview.fromJson(server.rows.first);
    final container = ProviderContainer(
      overrides: [
        customerHandlerProvider.overrideWith(_Customer.new),
        customerHttpClientProvider.overrideWithValue(server.client),
      ],
    );
    addTearDown(container.dispose);
    final handler = container.read(reviewMutationProvider.notifier);
    expect(
      await handler.save(
        productId: 'sku_1',
        content: '수정',
        rating: 3,
        review: foreign,
      ),
      isFalse,
    );
    expect(await handler.delete(foreign), isFalse);
    expect(server.writes, 0);
  });

  testWidgets(
    'detail removes tabs and create, edit, delete refresh the real average and counts',
    (tester) async {
      final server = _ReviewServer();
      await pump(tester, server);
      expect(find.byType(ChoiceChip), findsNothing);
      for (final tab in ['상세', '추천', '리뷰', '배송']) {
        expect(find.widgetWithText(ChoiceChip, tab), findsNothing);
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('review-average'))).data,
        '5.0',
      );
      await tapCheckoutControl(tester, 'product-write-review');
      expect(find.byKey(const Key('customer-review-editor')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('review-save')))
            .onPressed,
        isNull,
      );
      await rateAndWrite(tester, 4, '가볍고 촉촉해서 만족합니다.');
      await tapCheckoutControl(tester, 'review-save');
      expect(server.writes, 1);
      expect(server.rows, hasLength(2));
      expect(
        tester.widget<Text>(find.byKey(const Key('review-average'))).data,
        '4.5',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('review-score-count-4'))).data,
        '1',
      );
      expect(find.byKey(const Key('review-delete-rev_1')), findsNothing);
      await tapCheckoutControl(tester, 'review-edit-rev_10');
      expect(find.text('가볍고 촉촉해서 만족합니다.'), findsOneWidget);
      await rateAndWrite(tester, 2, '사용 후기를 수정합니다.');
      await tapCheckoutControl(tester, 'review-save');
      expect(
        tester.widget<Text>(find.byKey(const Key('review-average'))).data,
        '3.5',
      );
      await tapCheckoutControl(tester, 'review-delete-rev_10');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(server.rows, hasLength(2));
      await tapCheckoutControl(tester, 'review-delete-rev_10');
      await tapCheckoutControl(tester, 'confirm-review-delete');
      expect(server.rows, hasLength(1));
      expect(server.writes, 3);
      expect(
        tester.widget<Text>(find.byKey(const Key('review-average'))).data,
        '5.0',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delivery-incomplete product cannot open the review editor', (
    tester,
  ) async {
    final server = _ReviewServer();
    await pump(
      tester,
      server,
      home: CustomerProductDetailScreen(product: _products.last),
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('product-write-review')))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('review-average'))).data,
      '—',
    );
    expect(server.writes, 0);
  });

  testWidgets(
    'my review page exposes only delivered products even during split delivery',
    (tester) async {
      final server = _ReviewServer();
      await pump(tester, server, home: const CustomerMyPageScreen());
      await tapCheckoutControl(tester, 'mypage-reviews');
      expect(find.byKey(const Key('customer-review-list')), findsOneWidget);
      await tapCheckoutControl(tester, 'review-tab-writable');
      expect(
        find.byKey(const Key('write-purchased-review-sku_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('write-purchased-review-sku_2')),
        findsNothing,
      );
      await tapCheckoutControl(tester, 'write-purchased-review-sku_1');
      expect(find.byKey(const Key('customer-review-editor')), findsOneWidget);
      expect(server.writes, 0);
    },
  );

  testWidgets(
    'my existing review opens for editing and a rejected save preserves the previous rating',
    (tester) async {
      final server = _ReviewServer()
        ..addMine()
        ..failMethod = 'PUT';
      await pump(tester, server, home: const CustomerReviewListScreen());
      await tapCheckoutControl(tester, 'review-edit-rev_2');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('review-selected-rating')))
            .data,
        '3점',
      );
      await rateAndWrite(tester, 1, '새 내용');
      await tapCheckoutControl(tester, 'review-save');
      expect(find.byKey(const Key('customer-review-editor')), findsOneWidget);
      expect(find.text('새 내용'), findsOneWidget);
      expect(server.rows.last['rating'], 3);
      expect(find.byKey(const Key('review-save-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review summary and editor fit a narrow phone', (tester) async {
    final server = _ReviewServer();
    await pump(tester, server, size: const Size(320, 568));
    await tapCheckoutControl(tester, 'product-write-review');
    await rateAndWrite(tester, 5, '별점과 리뷰 입력');
    expect(tester.takeException(), isNull);
    expect(server.writes, 0);
  });

  testWidgets('capture product reviews and review editor when requested', (
    tester,
  ) async {
    final directory = Platform.environment['SODAM_PREVIEW_DIR'];
    if (directory == null) return;
    final server = _ReviewServer()..addMine();
    final key = GlobalKey();
    await pump(tester, server, capture: key);
    Future<void> capture(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File(
          '$directory/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await tapCheckoutControl(tester, 'product-rating-link');
    await capture('product_reviews');
    await tapCheckoutControl(tester, 'review-edit-rev_2');
    await capture('review_editor');
  });
}
