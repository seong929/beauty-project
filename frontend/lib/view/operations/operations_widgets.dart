import 'package:flutter/material.dart';
import 'operations_theme.dart';

class OperationsDetails extends StatelessWidget {
  const OperationsDetails({super.key, required this.fields});
  final Map<String, String> fields;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.maxWidth < 560
          ? bounds.maxWidth
          : (bounds.maxWidth - 24) / 2;
      return Wrap(
        spacing: 24,
        runSpacing: 18,
        children: [
          for (final entry in fields.entries)
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SelectableText(entry.value),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class OperationsStatus extends StatelessWidget {
  const OperationsStatus(this.label, {super.key, this.color = operationsGreen});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}

class OperationsEmpty extends StatelessWidget {
  const OperationsEmpty({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.icon = Icons.inbox_outlined,
  });
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: operationsMuted),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 조회'),
            ),
          ],
        ],
      ),
    ),
  );
}

class OperationsMetric extends StatelessWidget {
  const OperationsMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.detail,
  });
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? detail;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Icon(icon, color: operationsGreen, size: 22),
              ],
            ),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Desktop keeps both panels visible. Phone uses a full-height selected panel.
class OperationsMasterDetail extends StatelessWidget {
  const OperationsMasterDetail({
    super.key,
    required this.list,
    required this.detail,
    required this.hasSelection,
    required this.onBack,
  });
  final Widget list, detail;
  final bool hasSelection;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth >= 760) {
        return Row(
          children: [
            Expanded(flex: 4, child: list),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: detail),
          ],
        );
      }
      if (!hasSelection) return list;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('목록으로'),
            ),
          ),
          Expanded(child: detail),
        ],
      );
    },
  );
}
