import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_strings_mca_a3.dart';

class TripLegChips extends StatelessWidget {
  const TripLegChips({super.key, required this.onTap});

  final void Function(int legIndex) onTap;

  static const int _nameMax = 10;

  static String _short(String name) => name.length <= _nameMax ? name : '${name.substring(0, _nameMax).trimRight()}…';

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      if (p == null || !p.isMultiCity) return const SizedBox.shrink();
      return SizedBox(
        height: 44,
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.04, 0.96, 1],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: p.legCount,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final k = i + 1;
              final leg = p.legAt(k);
              if (leg == null) return const SizedBox.shrink();
              final label = '${_short(leg.cityName)} · ${TripStringsMcaA3.dayRange(p.legStart(k), p.legEnd(k))}';
              return Semantics(
                button: true,
                label: '${leg.cityName}, ${TripStringsMcaA3.dayRange(p.legStart(k), p.legEnd(k))}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(k),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: TripColors.accent.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.location, size: 13, color: TripColors.accentDark),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
