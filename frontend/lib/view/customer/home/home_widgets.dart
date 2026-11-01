// 기능: 홈 배너·Firebase 상품 사진·카테고리 버튼.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import 'storage_product_image.dart';

import '../login/customer_auth_widgets.dart';

const homeSage = Color(0xFFEEFAFB);
const homeMuted = Color(0xFF8B9096);

/// Firebase에 등록된 상품 사진을 배너의 이미지로 사용한다.
class HomeHero extends ConsumerWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(customerStorageImagesProvider).value?.firstOrNull;
    return Container(
      key: const Key('home-hero'),
      height: MediaQuery.textScalerOf(context).scale(160),
      padding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFFEEFAFB), Color(0xFFD6F4F6)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'HANA SKIN',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: SodamStyle.muted,
                  ),
                ),
                const SizedBox(height: 10),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '매일의 피부,\n새롭게 발견해요',
                    style: TextStyle(
                      fontSize: 23,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '나에게 맞는 아름다움을 만나는 곳',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: SodamStyle.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: SizedBox(
              key: const Key('home-hero-product-image'),
              child: image == null
                  ? const Icon(Icons.image_outlined, color: SodamStyle.muted)
                  : CustomerStoragePhoto(image: image, label: '하나 추천 상품 이미지'),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeCategoryButton extends StatelessWidget {
  const HomeCategoryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: selected ? 2 : 1,
                color: selected ? SodamStyle.ink : SodamStyle.border,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? SodamStyle.ink : homeMuted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? SodamStyle.ink : homeMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
