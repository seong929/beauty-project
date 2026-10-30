// Admin-only presentation. Shared STAFF/CUSTOMER views and business providers stay unchanged.
import 'package:flutter/material.dart';

enum ManagementListMode { grouped, individual }

class OperationsListControls extends StatelessWidget {
  const OperationsListControls({
    super.key,
    required this.mode,
    required this.status,
    required this.statuses,
    required this.onModeChanged,
    required this.onStatusChanged,
  });

  final ManagementListMode mode;
  final String status;
  final Map<String, String> statuses;
  final ValueChanged<ManagementListMode> onModeChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      children: [
        DropdownButtonFormField<ManagementListMode>(
          initialValue: mode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '표시 방식',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: ManagementListMode.grouped,
              child: Text('상품별 묶음'),
            ),
            DropdownMenuItem(
              value: ManagementListMode.individual,
              child: Text('개별 목록'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onModeChanged(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: status,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '상태 필터',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final entry in statuses.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null) onStatusChanged(value);
          },
        ),
      ],
    ),
  );
}
