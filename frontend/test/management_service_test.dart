import 'dart:convert';

import 'package:beauty_project/service/admin/management_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('반품 회수 상태 변경은 실제 API 경로와 요청 내용을 사용한다', () async {
    final service = ManagementService(
      MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/admin/returns/return-1/pickup-status');
        expect(jsonDecode(request.body), {
          'employee_id': 'admin-1',
          'pickup_status': 'COLLECTED',
        });
        return http.Response('{}', 200);
      }),
    );
    await service.returnAction('return-1', 'pickup-status', 'PATCH', {
      'employee_id': 'admin-1',
      'pickup_status': 'COLLECTED',
    });
  });

  test('서버가 반품 상태 충돌을 거절하면 상세 오류를 전달한다', () async {
    final service = ManagementService(
      MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': '이미 처리된 반품입니다.'}),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await expectLater(
      service.returnAction('return-1', 'decision', 'PATCH', {}),
      throwsA(predicate((error) => error.toString().contains('이미 처리된 반품입니다.'))),
    );
  });
}
