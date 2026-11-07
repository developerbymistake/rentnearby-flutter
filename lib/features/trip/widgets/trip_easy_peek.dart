import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_strings_v2_easy.dart';
import 'trip_easy_row.dart';

class TripEasyPeek extends StatelessWidget {
  const TripEasyPeek({super.key});

  static const List<(TripEasyRowKind, String)> _icons = [
    (TripEasyRowKind.gettingThere, TripStringsV2Easy.peekGettingThere),
    (TripEasyRowKind.stay, TripStringsV2Easy.stayShort),
    (TripEasyRowKind.taxi, TripStringsV2Easy.taxiShort),
    (TripEasyRowKind.comingBack, TripStringsV2Easy.peekBack),
  ];

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      if (c.plan.value == null || c.easyOpen.value) return const SizedBox.shrink();
      return Semantics(
        button: true,
        label: '${TripStringsV2Easy.title}. ${TripStringsV2Easy.peekLine}',
        child: GestureDetector(
          onTap: () => c.easyOpen.value = true,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: TripColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TripColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(TripStringsV2Easy.title,
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      const Text(TripStringsV2Easy.peekLine,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (k, label) in _icons)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(TripEasyRow.iconOf(k), size: 14, color: TripColors.accentDark),
                                  const SizedBox(width: 4),
                                  Text(label,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMedium)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMedium),
              ],
            ),
          ),
        ),
      );
    });
  }
}
