
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vm/admin/staff_purchase_order_notifier.dart';
import '../../vm/admin/inbound_notifier.dart';

class InboundPage extends ConsumerStatefulWidget {
  const InboundPage({super.key});

  @override
  ConsumerState<InboundPage> createState() => _InboundPageState();
}

class _InboundPageState extends ConsumerState<InboundPage> {
  final _formKey = GlobalKey<FormState>();

  final _purchaseOrderIdController = TextEditingController();
  final _inboundQuantityController = TextEditingController();

  DateTime _inboundOn = DateTime.now();
  DateTime? _expiresOn;


  @override
  void initState() {
    super.initState();

    final selectedOrder = ref.read(
      staffPurchaseOrderProvider,
    ).selectedPurchaseOrder;

    if (selectedOrder != null) {
      _purchaseOrderIdController.text =
          selectedOrder.purchaseOrderId;
    }
  }

  @override
  void dispose() {
    _purchaseOrderIdController.dispose();
    _inboundQuantityController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Future<void> _selectInboundDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _inboundOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _inboundOn = selectedDate;

      if (_expiresOn != null &&
          _expiresOn!.isBefore(_inboundOn)) {
        _expiresOn = null;
      }
    });
  }

  Future<void> _selectExpiryDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _expiresOn ?? _inboundOn,
      firstDate: _inboundOn,
      lastDate: DateTime(2100),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _expiresOn = selectedDate;
    });
  }

  Future<void> _registerInbound() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = int.tryParse(
      _inboundQuantityController.text.trim(),
    );

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('올바른 입고 수량을 입력해 주세요.'),
        ),
      );
      return;
    }

    final success = await ref
        .read(inboundProvider.notifier)
        .createInbound(
          purchaseOrderId:
              _purchaseOrderIdController.text.trim(),
          inboundQuantity: quantity,
          inboundOn: _inboundOn,
          expiresOn: _expiresOn,
        );

    if (!mounted) {
      return;
    }

    final inboundState = ref.read(inboundProvider);

    if (success) {
      // 발주 목록 최신 데이터 조회
      await ref
          .read(staffPurchaseOrderProvider.notifier)
          .getPurchaseOrderList();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('입고 등록이 완료되었습니다.'),
        ),
      );

      _inboundQuantityController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            inboundState.errorMessage ??
                '입고 등록에 실패했습니다.',
          ),
        ),
      );
    }
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
    VoidCallback? onClear,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date == null
                  ? '선택하지 않음'
                  : _formatDate(date),
            ),
          ),
          if (onClear != null && date != null)
            IconButton(
              tooltip: '날짜 초기화',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          IconButton(
            tooltip: '날짜 선택',
            onPressed: onPressed,
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = ref.watch(
      inboundProvider.select(
        (state) => state.inboundResult,
      ),
    );

    if (result == null) {
      return const SizedBox.shrink();
    }

    String statusText;

    switch (result.purchaseStatus) {
      case 'RECEIVED':
        statusText = '입고 완료';
        break;
      case 'PARTIALLY_RECEIVED':
        statusText = '부분 입고';
        break;
      default:
        statusText = result.purchaseStatus;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '입고 처리 결과',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildResultRow(
              '입고 ID',
              result.inboundId,
            ),
            _buildResultRow(
              '재고 ID',
              result.inventoryId,
            ),
            _buildResultRow(
              '입고 차수',
              '${result.inboundSeq}차',
            ),
            _buildResultRow(
              '이번 입고 수량',
              '${result.inboundQuantity}개',
            ),
            _buildResultRow(
              '누적 입고 수량',
              '${result.totalReceivedQuantity}개',
            ),
            _buildResultRow(
              '남은 입고 수량',
              '${result.remainingQuantity}개',
            ),
            _buildResultRow(
              '발주 상태',
              statusText,
            ),
            const SizedBox(height: 12),
            Text(
              result.message,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboundState = ref.watch(inboundProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('입고 관리'),
        backgroundColor: Colors.blueGrey.shade50,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 900,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '발주 상품 입고 등록',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '발주 정보를 확인하고 실제 입고된 '
                    '상품 수량을 등록해 주세요.',
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _purchaseOrderIdController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: '발주 ID',
                      hintText: '발주 목록에서 선택해 주세요.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt_long),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '발주 목록에서 발주를 선택해 주세요.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller:
                        _inboundQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '입고 수량',
                      hintText: '실제 입고된 수량',
                      suffixText: '개',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final quantity = int.tryParse(
                        value?.trim() ?? '',
                      );

                      if (quantity == null ||
                          quantity <= 0) {
                        return '1개 이상의 입고 수량을 입력해 주세요.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildDateField(
                    label: '입고일',
                    date: _inboundOn,
                    onPressed: _selectInboundDate,
                  ),

                  const SizedBox(height: 16),

                  _buildDateField(
                    label: '사용기한 (선택)',
                    date: _expiresOn,
                    onPressed: _selectExpiryDate,
                    onClear: () {
                      setState(() {
                        _expiresOn = null;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: inboundState.isProcessing
                          ? null
                          : _registerInbound,
                      icon: inboundState.isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                            ),
                      label: Text(
                        inboundState.isProcessing
                            ? '입고 처리 중...'
                            : '입고 등록',
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildResultCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
