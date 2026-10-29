import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/admin/approval.dart';

class ApprovalService {
  final String baseUrl;

  const ApprovalService({
    required this.baseUrl,
  });

  // 1. 품의 목록 조회
  Future<List<Approval>> getApprovalList() async {
    final url = Uri.parse('$baseUrl/admin/approvals');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        '품의 목록 조회 실패: ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList =
        jsonDecode(utf8.decode(response.bodyBytes));

    return jsonList
        .map(
          (json) => Approval.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // 2. 품의 승인 및 반려
  Future<void> decideApproval({
    required String approvalId,
    required String employeeId,
    required String decisionStatus,
    required String accessToken,
  }) async {
    if (decisionStatus != 'APPROVED' &&
        decisionStatus != 'REJECTED') {
      throw ArgumentError(
        'decisionStatus는 APPROVED 또는 REJECTED여야 합니다.',
      );
    }

    final url = Uri.parse(
      '$baseUrl/admin/approvals/'
      '${Uri.encodeComponent(approvalId)}/decision',
    );

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'employee_id': employeeId,
        'decision_status': decisionStatus,
      }),
    );

    if (response.statusCode == 401) {
      throw Exception(
        '직원 인증에 실패했습니다. 다시 로그인해 주세요.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        '해당 품의를 승인하거나 반려할 권한이 없습니다.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        '품의 승인·반려 실패: ${response.statusCode} '
        '${utf8.decode(response.bodyBytes)}',
      );
    }
  }
}