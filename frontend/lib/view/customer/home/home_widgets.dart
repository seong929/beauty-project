import 'package:flutter/material.dart';

import '../login/customer_auth_widgets.dart';

const homeSage = Color(0xFFEEFAFB);
const homeMuted = Color(0xFF8B9096);

// 배너의 장식용 하나 병 일러스트. 상품 사진으로 사용하지 않는다.
class SodamBottle extends StatelessWidget {
  const SodamBottle({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 104,
      height: 166,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 1,
            child: Container(
              width: 86,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: SodamStyle.green.withValues(alpha: .18),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 39,
              height: 33,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 27,
            child: Container(
              width: 51,
              height: 17,
              decoration: BoxDecoration(
                color: const Color(0xFF85D8DF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: 39,
            bottom: 7,
            child: Container(
              width: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFB5E9ED),
                    Color(0xFFF5FDFE),
                    Color(0xFF92DBE1),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF85D8DF).withValues(alpha: .5),
                ),
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 63,
                  color: Colors.white,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '하나',
                        style: TextStyle(fontSize: 15, color: SodamStyle.green),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'SOFT & CALM',
                        style: TextStyle(
                          fontSize: 4,
                          letterSpacing: 1,
                          color: homeMuted,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'DAILY ESSENCE',
                        style: TextStyle(
                          fontSize: 4,
                          letterSpacing: .6,
                          color: homeMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class HomeHero extends StatelessWidget {
  const HomeHero({super.key});
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('home-hero'),
    height: MediaQuery.textScalerOf(context).scale(160),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        colors: [Color(0xFFEEFAFB), Color(0xFFD6F4F6)],
      ),
    ),
    child: Stack(
      children: [
        const Positioned(
          right: 10,
          bottom: -12,
          child: ExcludeSemantics(
            child: SizedBox(
              width: 100,
              height: 145,
              child: FittedBox(child: SodamBottle()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FractionallySizedBox(
            widthFactor: .7,
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
                  style: TextStyle(fontSize: 10, color: SodamStyle.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
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
