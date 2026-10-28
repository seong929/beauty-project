import '../../model/staff/staff_order.dart';
import 'staff_inventory_service.dart';

/// 주문 도메인의 HTTP 응답 파싱만 담당합니다.
/// 토큰/쿠키/기본 URL/HTTP Client는 기존 StaffInventoryService에서 공유합니다.
class StaffOrderService {
  const StaffOrderService(this._authorizedClient);
  final StaffInventoryService _authorizedClient;

  Future<StaffOrderPage> getOrders({
    required int page,
    int count = 20,
    bool asc = false,
    List<StaffOrderStatus>? statuses,
    String? customerId,
  }) async {
    final query = <String, dynamic>{
      'page': '$page',
      'count': '$count',
      'asc': '$asc',
      if (statuses != null && statuses.isNotEmpty)
        'statuses': statuses.map((s) => s.name).toList(),
      if (customerId != null && customerId.trim().isNotEmpty)
        'customer_id': customerId.trim(),
    };
    final result = asOrderJson(
      await _authorizedClient.getAuthorizedJson('/staff/order/available', query),
    );
    final rows = result['orders'];
    if (rows is! List) {
      throw const FormatException('주문 목록 응답에 orders 배열이 없습니다.');
    }
    return StaffOrderPage(
      orders: rows.map((row) => StaffOrder.fromJson(asOrderJson(row))).toList(),
      page: page,
      pageSize: count,
    );
  }

  Future<StaffOrder> getOrderDetail(String orderId) async {
    final result = await _authorizedClient.getAuthorizedJson(
      '/staff/orders/${Uri.encodeComponent(orderId)}',
    );
    return StaffOrder.fromJson(asOrderJson(result));
  }

  Future<List<StaffOrderItem>> getOrderItems(String orderId) async {
    final result = await _authorizedClient.getAuthorizedJson(
      '/staff/orders/${Uri.encodeComponent(orderId)}/items',
    );
    if (result is! List) {
      throw const FormatException('주문 상품 API 응답은 배열이어야 합니다.');
    }
    return result.map((row) => StaffOrderItem.fromJson(asOrderJson(row))).toList();
  }
}
