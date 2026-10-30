// Admin-only presentation. Shared STAFF/CUSTOMER views and business providers stay unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../vm/admin/manufacturer_vm.dart';

class OperationsManufacturerPage extends ConsumerStatefulWidget {
  const OperationsManufacturerPage({super.key});
  @override
  ConsumerState<OperationsManufacturerPage> createState() =>
      _OperationsManufacturerPageState();
}

class _OperationsManufacturerPageState
    extends ConsumerState<OperationsManufacturerPage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<bool> _register() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발주처 이름을 입력해 주세요.')));
      return false;
    }
    try {
      await ref
          .read(manufacturerActionsProvider.notifier)
          .create(name.text, phone.text);
      if (!mounted) return false;
      name.clear();
      phone.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발주처를 등록했습니다.')));
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _openRegistration() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final busy = ref.watch(manufacturerActionsProvider);
          return AlertDialog(
            title: const Text('발주처 등록'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      enabled: !busy,
                      maxLength: 150,
                      decoration: const InputDecoration(labelText: '발주처 이름'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phone,
                      enabled: !busy,
                      maxLength: 30,
                      decoration: const InputDecoration(labelText: '연락처 (선택)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final saved = await _register();
                        if (saved && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                child: Text(busy ? '등록 중…' : '등록'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(manufacturersProvider);
    final busy = ref.watch(manufacturerActionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('발주처 관리'),
        actions: [
          TextButton.icon(
            onPressed: busy ? null : _openRegistration,
            icon: const Icon(Icons.add),
            label: const Text('발주처 등록'),
          ),
          IconButton(
            onPressed: () => ref.invalidate(manufacturersProvider),
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: '조회된 발주처 내 검색',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 24),
          Text('등록된 발주처', style: Theme.of(context).textTheme.titleLarge),
          list.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('조회 실패: $error'),
            data: (items) => Column(
              children: [
                if (items.isEmpty)
                  const ListTile(title: Text('등록된 발주처가 없습니다.')),
                for (final item in items.where(
                  (item) =>
                      item.name.toLowerCase().contains(_query) ||
                      (item.phone ?? '').contains(_query),
                ))
                  ListTile(
                    title: Text(item.name),
                    subtitle: Text(item.phone ?? '연락처 미등록'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
