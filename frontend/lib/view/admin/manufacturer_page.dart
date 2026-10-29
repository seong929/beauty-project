import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vm/admin/manufacturer_vm.dart';

class ManufacturerPage extends ConsumerStatefulWidget {
  const ManufacturerPage({super.key});
  @override
  ConsumerState<ManufacturerPage> createState() => _ManufacturerPageState();
}

class _ManufacturerPageState extends ConsumerState<ManufacturerPage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발주처 이름을 입력해 주세요.')));
      return;
    }
    try {
      await ref
          .read(manufacturerActionsProvider.notifier)
          .create(name.text, phone.text);
      if (!mounted) return;
      name.clear();
      phone.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발주처를 등록했습니다.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(manufacturersProvider);
    final busy = ref.watch(manufacturerActionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('발주처 관리'),
        actions: [
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
            controller: name,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: '발주처 이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: '연락처 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : _register,
            child: const Text('발주처 등록'),
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
                for (final item in items)
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
