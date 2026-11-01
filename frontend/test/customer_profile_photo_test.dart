import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/point_account.dart';
import 'package:beauty_project/service/customer/customer_profile_photo_service.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/mypage/mypage_screen.dart';
import 'package:beauty_project/view/customer/mypage/profile_edit_screen.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_profile_photo_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import 'package:beauty_project/vm/customer/point_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Customer extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'cus_1',
    loginId: 'hana',
    name: '고객',
    email: 'hana@example.com',
    address: '서울시',
    phone: '01012345678',
  );
}

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'photos persist across service instances and remain separated by customer',
    () async {
      final store = CustomerProfilePhotoService();
      await store.save('cus_1', _photo);
      await store.save('cus_2', Uint8List.fromList([1, 2, 3]));
      final reopened = CustomerProfilePhotoService();
      expect(await reopened.load('cus_1'), orderedEquals(_photo));
      expect(await reopened.load('cus_2'), orderedEquals([1, 2, 3]));
      await reopened.save('cus_1', null);
      expect(await reopened.load('cus_1'), isNull);
      expect(await reopened.load('cus_2'), orderedEquals([1, 2, 3]));
    },
  );

  test(
    'invalid or oversized selections do not overwrite the stored photo',
    () async {
      final store = CustomerProfilePhotoService();
      await store.save('cus_1', _photo);
      for (final bytes in [
        Uint8List(0),
        Uint8List(CustomerProfilePhotoService.maxBytes + 1),
      ]) {
        await expectLater(store.save('cus_1', bytes), throwsFormatException);
        expect(await store.load('cus_1'), orderedEquals(_photo));
      }
      await expectLater(store.save('', _photo), throwsFormatException);
    },
  );

  Future<void> pump(
    WidgetTester tester, {
    required Future<Uint8List?> Function() pick,
    bool saveFails = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = MockClient((request) async {
      expect(request.url.path, '/customer_update');
      expect(request.method, 'PUT');
      return http.Response(
        jsonEncode(saveFails ? {'detail': 'save failed'} : {'result': 'OK'}),
        saveFails ? 409 : 200,
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(client),
          customerProfilePhotoPickerProvider.overrideWithValue(pick),
          customerOrdersProvider.overrideWith((_) async => []),
          customerPointsProvider.overrideWith(
            (_) async => const CustomerPointAccount(balance: 0, history: []),
          ),
        ],
        child: MaterialApp(
          theme: SodamStyle.theme,
          home: const CustomerMyPageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mypage-edit-profile')));
    await tester.tap(find.byKey(const Key('mypage-edit-profile')));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('profile-save')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'gallery selection previews before save and updates the mypage after save',
    (tester) async {
      await pump(tester, pick: () async => _photo);
      await tester.tap(find.byKey(const Key('profile-photo-pick')));
      await tester.pumpAndSettle();
      expect(find.image(MemoryImage(_photo)), findsOneWidget);
      expect(await CustomerProfilePhotoService().load('cus_1'), isNull);
      await save(tester);
      expect(find.byType(CustomerProfileEditScreen), findsNothing);
      expect(find.image(MemoryImage(_photo)), findsOneWidget);
      expect(
        await CustomerProfilePhotoService().load('cus_1'),
        orderedEquals(_photo),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery cancellation and leaving without saving preserve the original photo',
    (tester) async {
      await pump(tester, pick: () async => null);
      await tester.tap(find.byKey(const Key('profile-photo-pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-photo-reset')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(await CustomerProfilePhotoService().load('cus_1'), isNull);

      await pump(tester, pick: () async => _photo);
      await tester.tap(find.byKey(const Key('profile-photo-pick')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(await CustomerProfilePhotoService().load('cus_1'), isNull);
      expect(find.image(MemoryImage(_photo)), findsNothing);
    },
  );

  testWidgets(
    'default photo reset is saved without changing other customer photos',
    (tester) async {
      await CustomerProfilePhotoService().save('cus_1', _photo);
      await CustomerProfilePhotoService().save('cus_2', _photo);
      await pump(tester, pick: () async => null);
      await tester.tap(find.byKey(const Key('profile-photo-reset')));
      await tester.pumpAndSettle();
      expect(find.image(MemoryImage(_photo)), findsNothing);
      await save(tester);
      expect(await CustomerProfilePhotoService().load('cus_1'), isNull);
      expect(
        await CustomerProfilePhotoService().load('cus_2'),
        orderedEquals(_photo),
      );
    },
  );

  testWidgets(
    'failed profile request keeps the selection editable without saving the photo',
    (tester) async {
      await pump(tester, pick: () async => _photo, saveFails: true);
      await tester.tap(find.byKey(const Key('profile-photo-pick')));
      await tester.pumpAndSettle();
      await save(tester);
      expect(find.byType(CustomerProfileEditScreen), findsOneWidget);
      expect(find.text('save failed'), findsOneWidget);
      expect(await CustomerProfilePhotoService().load('cus_1'), isNull);
    },
  );

  testWidgets(
    'gallery errors are displayed and duplicate selection is blocked while picking',
    (tester) async {
      final pending = Completer<Uint8List?>();
      var requests = 0;
      await pump(
        tester,
        pick: () {
          requests++;
          return pending.future;
        },
      );
      await tester.tap(find.byKey(const Key('profile-photo-pick')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('profile-photo-pick')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(requests, 1);
      expect(find.text('사진 선택 중…'), findsOneWidget);
      pending.completeError(const FormatException('invalid photo'));
      await tester.pumpAndSettle();
      expect(find.text('invalid photo'), findsOneWidget);
      expect(find.text('사진 변경'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
