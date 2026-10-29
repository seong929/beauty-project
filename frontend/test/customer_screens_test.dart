import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beauty_project/main.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response responseJson(Object data, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(data)),
      status,
      headers: {'content-type': 'application/json'},
    );

// 요청 대기 상태 등 화면 검증에 필요한 인증 응답을 제어한다.
class ScreenLoginService extends CustomerAuthService {
  ScreenLoginService(this.result)
    : super(client: MockClient((_) async => responseJson({}, 500)));
  final Future<Customers> result;

  @override
  Future<Customers> login({
    required String loginId,
    required String password,
  }) => result;
}

const screenCustomer = Customers(
  customerId: 'cus_screen',
  loginId: 'sodam',
  name: '소담고객',
  email: 'sodam@example.com',
  address: '서울시',
  phone: '01012345678',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansKR')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    http.Client? client,
    CustomerAuthService? authService,
    Size size = const Size(390, 844),
    GlobalKey? captureKey,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final httpClient = client ?? MockClient((_) async => responseJson({}, 500));
    addTearDown(httpClient.close);
    if (authService != null) addTearDown(authService.client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerHttpClientProvider.overrideWithValue(httpClient),
          customerApiBaseUrlProvider.overrideWithValue(
            Uri.parse('http://localhost:8000/'),
          ),
          if (authService != null)
            customerAuthServiceProvider.overrideWithValue(authService),
        ],
        child: RepaintBoundary(key: captureKey, child: const MyApp()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fillSignup(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, 'sodam');
    for (final entry in {
      'signup-name': '소담고객',
      'signup-password': 'secret123!',
      'signup-confirmation': 'secret123!',
      'signup-address': '서울시 강남구',
      'signup-email': 'sodam@example.com',
      'signup-phone': '010-1234-5678',
    }.entries) {
      final field = find.byKey(Key(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'failed customer authentication shows the API error and stays on login',
    (tester) async {
      var calls = 0;
      await pumpApp(
        tester,
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/customer_login');
          expect(request.bodyFields, {
            'login_id': 'sodam',
            'password': 'secret123!',
          });
          return responseJson({'detail': '아이디 또는 비밀번호가 올바르지 않습니다.'}, 401);
        }),
      );
      expect(find.text('다시 만나 반가워요'), findsOneWidget);
      expect(
        find.text('나만의 뷰티 루틴을 소담과 함께 시작해 보세요.\n처음이신가요? 회원가입 후 로그인할 수 있습니다.'),
        findsOneWidget,
      );
      final button = find.descendant(
        of: find.byKey(const Key('login-submit')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.enterText(find.byKey(const Key('login-id')), 'sodam');
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'secret123!',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byKey(const Key('customer-home')), findsNothing);
      expect(find.text('아이디 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
    },
  );

  testWidgets('password visibility can still be toggled', (tester) async {
    await pumpApp(tester);
    final editable = find.descendant(
      of: find.byKey(const Key('login-password')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editable).obscureText, isTrue);
    await tapVisible(tester, find.text('보기'));
    expect(tester.widget<EditableText>(editable).obscureText, isFalse);
  });

  testWidgets('authenticated login opens home and logout clears the customer', (
    tester,
  ) async {
    await pumpApp(
      tester,
      client: MockClient((request) async {
        if (request.url.path == '/customer_login') {
          expect(request.method, 'POST');
          return responseJson({
            'result': 'OK',
            'customer': {
              ...screenCustomer.toJson(),
              'account_status': 'ACTIVE',
            },
          });
        }
        if (request.url.path == '/orders') return responseJson({'results': []});
        expect(request.url.path, '/customers_categories_search');
        return responseJson({'result': []});
      }),
    );
    await tester.enterText(find.byKey(const Key('login-id')), 'sodam');
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'secret123!',
    );
    await tapVisible(tester, find.byKey(const Key('login-submit')));

    expect(find.byKey(const Key('customer-home')), findsOneWidget);
    expect(find.byKey(const Key('home-hero')), findsOneWidget);
    expect(find.byKey(const Key('login-id')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('customer-home'))),
    );
    expect(
      container.read(customerHandlerProvider).value!.customerId,
      'cus_screen',
    );
    await tapVisible(tester, find.byKey(const Key('home-nav-3')));
    expect(find.byKey(const Key('customer-mypage')), findsOneWidget);
    expect(find.text('소담고객님'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('customer-logout')));
    expect(find.byKey(const Key('customer-home')), findsNothing);
    expect(find.byKey(const Key('login-id')), findsOneWidget);
    expect(container.read(customerHandlerProvider).value, isNull);
  });

  testWidgets(
    'pending authentication disables the login button until it finishes',
    (tester) async {
      final pending = Completer<Customers>();
      await pumpApp(tester, authService: ScreenLoginService(pending.future));
      await tester.enterText(find.byKey(const Key('login-id')), 'sodam');
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'secret123!',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
      final button = find.descendant(
        of: find.byKey(const Key('login-submit')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(screenCustomer);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customer-home')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('signup uses only the existing customer_upload API', (
    tester,
  ) async {
    Map<String, String>? submitted;
    await pumpApp(
      tester,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/customer_upload');
        submitted = request.bodyFields;
        return responseJson({
          'result': 'OK',
          'customer_id': submitted!['customer_id'],
        });
      }),
    );
    await tapVisible(tester, find.byKey(const Key('open-signup')));
    expect(find.text('중복 확인 · 준비 중'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('check-login-id')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('signup-birth-year')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('signup-gender')),
          )
          .onChanged,
      isNull,
    );
    await fillSignup(tester);
    await tapVisible(tester, find.byKey(const Key('signup-submit')));
    expect(submitted!['customer_id'], matches(RegExp(r'^cus_[0-9a-f]{32}$')));
    final fields = Map<String, String>.of(submitted!)..remove('customer_id');
    expect(fields, {
      'login_id': 'sodam',
      'password': 'secret123!',
      'customer_name': '소담고객',
      'address': '서울시 강남구',
      'email': 'sodam@example.com',
      'phone': '010-1234-5678',
    });
    expect(find.text('다시 만나 반가워요'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-id')))
          .controller!
          .text,
      'sodam',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-password')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate signup displays the existing API error', (
    tester,
  ) async {
    await pumpApp(
      tester,
      client: MockClient(
        (_) async =>
            responseJson({'detail': '중복된 고객 ID, 로그인 ID 또는 이메일입니다.'}, 409),
      ),
    );
    await tapVisible(tester, find.byKey(const Key('open-signup')));
    await fillSignup(tester);
    await tapVisible(tester, find.byKey(const Key('signup-submit')));
    expect(find.text('소담과 함께해요'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('auth-error'))).data,
      '중복된 고객 ID, 로그인 ID 또는 이메일입니다.',
    );
  });

  testWidgets('mismatched passwords prevent signup before requesting the API', (
    tester,
  ) async {
    var calls = 0;
    await pumpApp(
      tester,
      client: MockClient((_) async {
        calls++;
        return responseJson({}, 500);
      }),
    );
    await tapVisible(tester, find.byKey(const Key('open-signup')));
    await fillSignup(tester);
    await tester.enterText(
      find.byKey(const Key('signup-confirmation')),
      'different123',
    );
    await tapVisible(tester, find.byKey(const Key('signup-submit')));
    expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('both forms are scrollable on a small phone', (tester) async {
    await pumpApp(tester, size: const Size(320, 568));
    await tapVisible(tester, find.byKey(const Key('open-signup')));
    await tester.ensureVisible(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('로그인 화면으로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture the updated screens when preview output is set', (
    tester,
  ) async {
    final destination = Platform.environment['SODAM_PREVIEW_DIR'];
    if (destination == null) return;
    final key = GlobalKey();
    await pumpApp(tester, captureKey: key);
    Future<void> capture(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(destination).create(recursive: true);
        await File(
          '$destination/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.enterText(find.byKey(const Key('login-id')), 'sodam01');
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'demo1234!',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await capture('login');
    await tapVisible(tester, find.byKey(const Key('open-signup')));
    await tester.enterText(
      find.byKey(const Key('signup-password')),
      'demo1234!',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirmation')),
      'demo1234!',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await capture('signup');
    expect(tester.takeException(), isNull);
  });
}
