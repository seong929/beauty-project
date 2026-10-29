
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/admin/approval.dart';
import '../../vm/admin/approval_notifier.dart';
import '../../vm/auth/auth_notifier.dart';
import '../auth/login_page.dart';

import 'purchase_order_page.dart';
import 'staff_purchase_order_page.dart';
import 'outbound_page.dart';
import 'delivery_page.dart';

class ApprovalPage extends ConsumerStatefulWidget {
  const ApprovalPage({super.key});

  @override
  ConsumerState<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends ConsumerState<ApprovalPage> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (mounted) {
        ref.read(approvalProvider.notifier).getApprovalList();
      }
    });
  }

  // 발주 관리 화면 이동
  void _openPurchaseOrderPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PurchaseOrderPage(),
      ),
    );
  }

  // 입고 관리 화면 이동
  void _openInboundPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const StaffPurchaseOrderPage(),
      ),
    );
  }

  // 출고 관리 화면 이동
  void _openOutboundPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OutboundPage(),
      ),
    );
  }

    // 배송 현황 화면 이동
  void _openDeliveryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeliveryPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final approvalState = ref.watch(approvalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('본사 관리자'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // 왼쪽 메뉴
          Container(
            width: 180,
            color: Colors.grey.shade100,
            child: Column(
              children: [
                const SizedBox(height: 24),

                // 품의 관리 메뉴
                const ListTile(
                  leading: Icon(Icons.fact_check),
                  title: Text('품의 관리'),
                  selected: true,
                ),

                // 발주 관리 메뉴
                ListTile(
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                  ),
                  title: const Text('발주 관리'),
                  onTap: _openPurchaseOrderPage,
                ),

                // 입고 관리 메뉴
                ListTile(
                  leading: const Icon(
                    Icons.move_to_inbox_outlined,
                  ),
                  title: const Text('입고 관리'),
                  onTap: _openInboundPage,
                ),

                // 출고 관리 메뉴
                ListTile(
                  leading: const Icon(
                    Icons.local_shipping_outlined,
                  ),
                  title: const Text('출고 관리'),
                  onTap: _openOutboundPage,
                ),

                // 배송 현황 메뉴
                ListTile(
                  leading: const Icon(
                    Icons.local_shipping,
                  ),
                  title: const Text('배송 현황'),
                  onTap: _openDeliveryPage,
                ),
              ],
            ),
          ),

          // 품의 목록
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        '품의 목록',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: approvalState.isLoading
                            ? null
                            : () {
                                ref
                                    .read(approvalProvider.notifier)
                                    .getApprovalList();
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildApprovalList(),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // 품의 상세
          Expanded(
            flex: 3,
            child: _buildApprovalDetail(),
          ),
        ],
      ),
    );
  }

  // 품의 목록
  Widget _buildApprovalList() {
    final approvalState = ref.watch(approvalProvider);

    if (approvalState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (approvalState.errorMessage != null) {
      return Center(
        child: Text(approvalState.errorMessage!),
      );
    }

    if (approvalState.approvals.isEmpty) {
      return const Center(
        child: Text('품의 요청이 없습니다.'),
      );
    }

    return ListView.builder(
      itemCount: approvalState.approvals.length,
      itemBuilder: (context, index) {
        final approval = approvalState.approvals[index];

        final isSelected =
            approvalState.selectedApproval?.approvalId ==
            approval.approvalId;

        return ListTile(
          selected: isSelected,
          title: Text(approval.cosmeticName),
          subtitle: Text(
            '요청 수량: ${approval.requestedQuantity}개',
          ),
          trailing: Text(
            approval.decisionStatus ??
                approval.approvalStatus ??
                '대기',
          ),
          onTap: () {
            ref
                .read(approvalProvider.notifier)
                .selectApproval(approval);
          },
        );
      },
    );
  }

  // 품의 상세
  Widget _buildApprovalDetail() {
    final approvalState = ref.watch(approvalProvider);
    final authState = ref.watch(authProvider);

    final approval = approvalState.selectedApproval;

    if (approval == null) {
      return const Center(
        child: Text('품의 요청을 선택해주세요.'),
      );
    }

    // 현재 로그인한 관리자 ID
    final loggedInEmployeeId =
        authState.employee?.employeeId;

    // 결재 가능한 품의인지 확인
    final canDecide =
        authState.isAdmin &&
        loggedInEmployeeId != null &&
        approval.employeeId == loggedInEmployeeId &&
        approval.approvalStatus == 'REQUESTED' &&
        approval.decisionStatus == 'PENDING' &&
        !approvalState.isProcessing;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '품의 상세 정보',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          _detailRow('품의 ID', approval.approvalId),
          _detailRow('상품 ID', approval.cosmeticId),
          _detailRow('상품명', approval.cosmeticName),
          _detailRow(
            '품의 차수',
            '${approval.approvalSeq}',
          ),
          _detailRow(
            '목표 재고',
            '${approval.targetStockSnapshot}개',
          ),
          _detailRow(
            '현재 재고',
            '${approval.currentStockSnapshot}개',
          ),
          _detailRow(
            '요청 수량',
            '${approval.requestedQuantity}개',
          ),
          _detailRow(
            '요청일',
            approval.requestedOn.toString().split(' ')[0],
          ),
          _detailRow(
            '품의 내용',
            approval.approvalContent,
          ),
          _detailRow(
            '결재 상태',
            approval.decisionStatus ??
                approval.approvalStatus ??
                '대기',
          ),

          const Spacer(),

          // 승인 / 반려 버튼
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: canDecide
                      ? () => _decideApproval(
                            approval,
                            'APPROVED',
                          )
                      : null,
                  child: const Text('승인'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: canDecide
                      ? () => _decideApproval(
                            approval,
                            'REJECTED',
                          )
                      : null,
                  child: const Text('반려'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
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

  Future<void> _decideApproval(
    Approval approval,
    String decisionStatus,
  ) async {
    final authState = ref.read(authProvider);

    final employeeId = authState.employee?.employeeId;

    if (!authState.isAdmin || employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('관리자 로그인 정보가 없습니다.'),
        ),
      );
      return;
    }

    final success = await ref
        .read(approvalProvider.notifier)
        .decideApproval(
          approvalId: approval.approvalId,
          employeeId: employeeId,
          decisionStatus: decisionStatus,
        );

    if (!mounted) return;

    final approvalState = ref.read(approvalProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '품의 처리가 완료되었습니다.'
              : approvalState.errorMessage ??
                  '품의 처리에 실패했습니다.',
        ),
      ),
    );
  }
}
