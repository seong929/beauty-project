// Admin-only presentation. Shared STAFF/CUSTOMER views and business providers stay unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/admin/delivery.dart';
import '../../../vm/admin/delivery_notifier.dart';
import '../../operations/operations_widgets.dart';

class OperationsDeliveryPage extends ConsumerStatefulWidget {
  const OperationsDeliveryPage({super.key});

  @override
  ConsumerState<OperationsDeliveryPage> createState() =>
      _OperationsDeliveryPageState();
}

class _OperationsDeliveryPageState
    extends ConsumerState<OperationsDeliveryPage> {
  bool _showDetail = false;
  @override
  void initState() {
    super.initState();

    // 화면 진입 시 배송 목록 조회
    Future.microtask(() {
      if (mounted) {
        ref.read(deliveryProvider.notifier).fetchDeliveryList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deliveryState = ref.watch(deliveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('배송 현황 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: deliveryState.isLoading
                ? null
                : () {
                    ref.read(deliveryProvider.notifier).fetchDeliveryList();
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // 배송 현황 건수
          _buildSummary(),

          const Divider(height: 1),

          // 배송 목록 및 상세 정보
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OperationsMasterDetail(
                list: Card(child: _buildDeliveryList()),
                detail: Card(child: _buildDeliveryDetail()),
                hasSelection:
                    _showDetail && deliveryState.selectedDelivery != null,
                onBack: () => setState(() => _showDetail = false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 배송 현황 요약
  Widget _buildSummary() {
    final deliveryState = ref.watch(deliveryProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _summaryCard('전체', deliveryState.totalCount, Colors.blueGrey),
          _summaryCard('배송 준비', deliveryState.readyCount, Colors.orange),
          _summaryCard('배송 중', deliveryState.inTransitCount, Colors.blue),
          _summaryCard('배송 완료', deliveryState.deliveredCount, Colors.green),
        ],
      ),
    );
  }

  // 요약 카드
  Widget _summaryCard(String title, int count, Color color) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$count건',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 배송 목록
  Widget _buildDeliveryList() {
    final deliveryState = ref.watch(deliveryProvider);
    final deliveries = deliveryState.filteredDeliveries;

    return Column(
      children: [
        // 목록 제목 및 필터
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '배송 목록',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: deliveryState.selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('전체')),
                  DropdownMenuItem(value: 'READY', child: Text('배송 준비')),
                  DropdownMenuItem(value: 'IN_TRANSIT', child: Text('배송 중')),
                  DropdownMenuItem(value: 'DELIVERED', child: Text('배송 완료')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(deliveryProvider.notifier)
                        .changeStatusFilter(value);
                  }
                },
              ),
            ],
          ),
        ),

        if (deliveryState.isLoading) const LinearProgressIndicator(),

        if (deliveryState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              deliveryState.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),

        Expanded(
          child: deliveryState.isLoading && deliveryState.deliveries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : deliveries.isEmpty
              ? const Center(child: Text('배송 내역이 없습니다.'))
              : ListView.builder(
                  itemCount: deliveries.length,
                  itemBuilder: (context, index) {
                    final delivery = deliveries[index];

                    final isSelected =
                        deliveryState.selectedDeliveryId == delivery.deliveryId;

                    return ListTile(
                      selected: isSelected,
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(delivery.deliveryId),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('주문번호: ${delivery.orderId}'),
                          Text(delivery.carrierName),
                        ],
                      ),
                      trailing: _statusChip(delivery),
                      onTap: () {
                        ref
                            .read(deliveryProvider.notifier)
                            .selectDelivery(delivery.deliveryId);
                        setState(() => _showDetail = true);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 배송 상태 표시
  Widget _statusChip(Delivery delivery) {
    Color color;

    switch (delivery.deliveryStatus) {
      case 'READY':
        color = Colors.orange;
        break;
      case 'IN_TRANSIT':
        color = Colors.blue;
        break;
      case 'DELIVERED':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        delivery.statusText,
        style: TextStyle(color: color, fontSize: 12),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }

  // 배송 상세 정보
  Widget _buildDeliveryDetail() {
    final deliveryState = ref.watch(deliveryProvider);
    final delivery = deliveryState.selectedDelivery;

    if (delivery == null) {
      return const Center(child: Text('배송 내역을 선택해 주세요.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '배송 상세 정보',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          _detailRow('배송번호', delivery.deliveryId),

          _detailRow('주문번호', delivery.orderId),

          _detailRow('배송 차수', '${delivery.deliverySeq}차'),

          _detailRow('배송업체', delivery.carrierName),

          _detailRow('배송지', delivery.shippingAddress),

          _detailRow('주문일', _formatDateTime(delivery.orderedAt)),

          _detailRow('배송 상태', delivery.statusText),

          _detailRow('배송 시작일', delivery.shippedAtText),

          _detailRow('배송 완료일', delivery.arrivedAtText),
        ],
      ),
    );
  }

  // 상세 정보 행
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // 날짜 및 시간 표시
  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }
}
