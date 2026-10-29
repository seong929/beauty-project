import 'package:flutter/material.dart';
import 'package:beauty_project/model/customer/cart_item.dart';
import 'package:beauty_project/vm/customer/checkout_flow_handler.dart';
import '../product/product_widgets.dart';

abstract final class CheckoutStyle {
  static const accent = Color(0xFF36C4CF);
  static const ink = Color(0xFF202428);
  static const muted = Color(0xFF90959B);
  static const border = Color(0xFFEBEDF0);
  static const field = Color(0xFFF5F6F8);
  static const selected = Color(0xFFEEFAFB);

  static ThemeData theme(ThemeData base) => base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
    ),
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      centerTitle: true,
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
        fontFamily: base.textTheme.bodyMedium?.fontFamily,
        color: ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: TextStyle(
          fontFamily: base.textTheme.bodyMedium?.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : Colors.white,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );
}

class CheckoutSection extends StatelessWidget {
  const CheckoutSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}

class CheckoutAmountRow extends StatelessWidget {
  const CheckoutAmountRow(
    this.label,
    this.value, {
    super.key,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: CheckoutStyle.muted),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              color: highlight ? CheckoutStyle.accent : CheckoutStyle.ink,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class CheckoutProductSummary extends StatelessWidget {
  const CheckoutProductSummary({super.key, required this.item});
  final CustomerCartItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: ProductPhoto(product: item.product, height: 86),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.brand,
                style: const TextStyle(
                  fontSize: 11,
                  color: CheckoutStyle.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.product.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${item.option.label} · 수량 ${item.quantity}개',
                style: const TextStyle(
                  fontSize: 11,
                  color: CheckoutStyle.muted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                productPrice(item.totalPrice),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CheckoutMethodChoices extends StatelessWidget {
  const CheckoutMethodChoices({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });
  final CheckoutPaymentMethod? selected;
  final ValueChanged<CheckoutPaymentMethod> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => RadioGroup<CheckoutPaymentMethod>(
    groupValue: selected,
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
    child: Column(
      children: [
        for (final method in CheckoutPaymentMethod.values)
          if (!compact || method.selectable)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RadioListTile<CheckoutPaymentMethod>(
                key: Key('checkout-method-${method.name}'),
                value: method,
                enabled: method.selectable,
                selected: selected == method,
                selectedTileColor: CheckoutStyle.selected,
                activeColor: const Color(0xFFFF4363),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFFFF4363)
                      : CheckoutStyle.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: EdgeInsets.zero,
                visualDensity: const VisualDensity(vertical: -1),
                title: Text(
                  method.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: method.selectable
                        ? CheckoutStyle.ink
                        : CheckoutStyle.muted,
                  ),
                ),
                secondary: method.selectable
                    ? null
                    : const Text(
                        '준비 중',
                        style: TextStyle(
                          fontSize: 11,
                          color: CheckoutStyle.muted,
                        ),
                      ),
              ),
            ),
      ],
    ),
  );
}

class CheckoutAgreementRow extends StatelessWidget {
  const CheckoutAgreementRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.onDetails,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? description;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 36,
        height: 40,
        child: Checkbox(
          value: value,
          onChanged: (next) => onChanged(next ?? false),
        ),
      ),
      Expanded(
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CheckoutStyle.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      if (onDetails != null)
        IconButton(
          onPressed: onDetails,
          tooltip: '$label 내용 보기',
          icon: const Icon(
            Icons.chevron_right,
            size: 18,
            color: CheckoutStyle.muted,
          ),
        ),
    ],
  );
}
