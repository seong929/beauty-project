import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/api_config.dart';
import '../auth/api_client_provider.dart';

class Manufacturer {
  const Manufacturer(this.id, this.name, this.phone);
  final String id;
  final String name;
  final String? phone;
  factory Manufacturer.fromJson(Map<String, dynamic> json) => Manufacturer(
    json['manufacturer_id'] as String,
    json['manufacturer_name'] as String,
    json['phone'] as String?,
  );
}

final manufacturersProvider = FutureProvider.autoDispose<List<Manufacturer>>((
  ref,
) async {
  final response = await ref
      .watch(apiClientProvider)
      .get(Uri.parse('${ApiConfig.baseUrl}/admin/manufacturers'));
  if (response.statusCode != 200) {
    throw Exception('발주처 목록을 불러오지 못했습니다. (${response.statusCode})');
  }
  return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
      .map((item) => Manufacturer.fromJson(item as Map<String, dynamic>))
      .toList();
});

class ManufacturerActions extends Notifier<bool> {
  @override
  bool build() => false;
  Future<void> create(String name, String phone) async {
    if (state) return;
    state = true;
    try {
      final response = await ref
          .read(apiClientProvider)
          .post(
            Uri.parse('${ApiConfig.baseUrl}/admin/manufacturers'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'manufacturer_name': name.trim(),
              if (phone.trim().isNotEmpty) 'phone': phone.trim(),
            }),
          );
      if (response.statusCode != 201) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          body is Map && body['detail'] is String
              ? body['detail']
              : '발주처 등록에 실패했습니다.',
        );
      }
      ref.invalidate(manufacturersProvider);
    } finally {
      state = false;
    }
  }
}

final manufacturerActionsProvider = NotifierProvider<ManufacturerActions, bool>(
  ManufacturerActions.new,
);
