
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/delivery/delivery.dart';
import '../../vm/delivery/delivery_notifier.dart';
import '../../vm/delivery/delivery_state.dart';

class DeliveryPage extends ConsumerStatefulWidget {
  const DeliveryPage({super.key});

  @override
  ConsumerState<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends ConsumerState<DeliveryPage> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      ref.read(deliveryProvider.notifier).fetchDeliveryList();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${date.year}-'
        '${twoDigits(date.month)}-'
        '${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'READY':
        return Colors.orange;
      case 'IN_TRANSIT':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryState = ref.watch(deliveryProvider);

    ref.listen<DeliveryState>(deliveryProvider, (previous, next) {
      final successChanged =
          previous?.successMessage != next.successMessage;

      final errorChanged =
          previous?.errorMessage != next.errorMessage;

      if (successChanged && next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
      }

      if (errorChanged && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('배송업체 배송 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed:
                deliveryState.isLoading || deliveryState.isProcessing
                ? null
                : () {
                    ref
                        .read(deliveryProvider.notifier)
                        .fetchDeliveryList();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummary(deliveryState),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 800) {
                    return Column(
                      children: [
                        Expanded(
                          child: _buildDeliveryList(deliveryState),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _buildDeliveryDetail(deliveryState),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildDeliveryList(deliveryState),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: _buildDeliveryDetail(deliveryState),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 배송 현황 요약
  Widget _buildSummary(DeliveryState state) {
    return Row(
      children: [
        _summaryCard(
          '전체',
          state.totalCount,
          Colors.grey,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          '배송 준비',
          state.readyCount,
          Colors.orange,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          '배송 중',
          state.inTransitCount,
          Colors.blue,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          '배송 완료',
          state.deliveredCount,
          Colors.green,
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    int count,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 4,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 배송 목록
  Widget _buildDeliveryList(DeliveryState state) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '배송 목록',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: state.selectedStatus,
                  items: const [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text('전체'),
                    ),
                    DropdownMenuItem(
                      value: 'READY',
                      child: Text('배송 준비'),
                    ),
                    DropdownMenuItem(
                      value: 'IN_TRANSIT',
                      child: Text('배송 중'),
                    ),
                    DropdownMenuItem(
                      value: 'DELIVERED',
                      child: Text('배송 완료'),
                    ),
                  ],
                  onChanged: state.isProcessing
                      ? null
                      : (value) {
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
          const Divider(height: 1),
          Expanded(
            child: _buildListContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(DeliveryState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final deliveries = state.filteredDeliveries;

    if (deliveries.isEmpty) {
      return const Center(
        child: Text('조회된 배송 내역이 없습니다.'),
      );
    }

    return ListView.builder(
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveries[index];

        final isSelected =
            state.selectedDeliveryId == delivery.deliveryId;

        return ListTile(
          selected: isSelected,
          selectedTileColor: Colors.blue.withValues(alpha: 0.08),
          title: Text(
            delivery.deliveryId,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('주문번호: ${delivery.orderId}'),
              Text('배송업체: ${delivery.carrierName}'),
              Text(
                delivery.statusText,
                style: TextStyle(
                  color: _statusColor(delivery.deliveryStatus),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          isThreeLine: true,
          onTap: state.isProcessing
              ? null
              : () {
                  ref
                      .read(deliveryProvider.notifier)
                      .selectDelivery(delivery.deliveryId);
                },
        );
      },
    );
  }

  // 배송 상세 정보
  Widget _buildDeliveryDetail(DeliveryState state) {
    final delivery = state.selectedDelivery;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: delivery == null
            ? const Center(
                child: Text('배송 목록에서 항목을 선택해 주세요.'),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '배송 상세 정보',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 28),
                    _detailRow('배송번호', delivery.deliveryId),
                    _detailRow('주문번호', delivery.orderId),
                    _detailRow(
                      '배송 순번',
                      '${delivery.deliverySeq}',
                    ),
                    _detailRow(
                      '배송업체',
                      delivery.carrierName,
                    ),
                    _detailRow(
                      '배송지',
                      delivery.shippingAddress,
                    ),
                    _detailRow(
                      '주문일',
                      _formatDate(delivery.orderedAt),
                    ),
                    _detailRow(
                      '배송 상태',
                      delivery.statusText,
                    ),
                    _detailRow(
                      '배송 시작일',
                      _formatDate(delivery.shippedAt),
                    ),
                    _detailRow(
                      '배송 완료일',
                      _formatDate(delivery.arrivedAt),
                    ),
                    const SizedBox(height: 24),
                    _buildActionButtons(state, delivery),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // 배송 시작 및 배송 완료 버튼
  Widget _buildActionButtons(
    DeliveryState state,
    Delivery delivery,
  ) {
    if (state.isProcessing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (delivery.deliveryStatus == 'DELIVERED') {
      return const Center(
        child: Text(
          '배송이 완료된 건입니다.',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.canStartDelivery
            ? () => _confirmStatusChange(
                title: '배송 시작',
                message: '선택한 배송을 시작하시겠습니까?',
                onConfirm: () {
                  return ref
                      .read(deliveryProvider.notifier)
                      .startDelivery();
                },
              )
            : state.canCompleteDelivery
            ? () => _confirmStatusChange(
                title: '배송 완료',
                message: '선택한 배송을 완료 처리하시겠습니까?',
                onConfirm: () {
                  return ref
                      .read(deliveryProvider.notifier)
                      .completeDelivery();
                },
              )
            : null,
        icon: Icon(
          delivery.deliveryStatus == 'READY'
              ? Icons.local_shipping_outlined
              : Icons.check_circle_outline,
        ),
        label: Text(
          delivery.deliveryStatus == 'READY'
              ? '배송 시작'
              : '배송 완료',
        ),
      ),
    );
  }

  // 상태 변경 확인 다이얼로그
  Future<void> _confirmStatusChange({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await onConfirm();
    }
  }
}
