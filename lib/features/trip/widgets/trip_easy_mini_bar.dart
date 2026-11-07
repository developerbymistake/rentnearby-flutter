import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_easy_rules.dart';

class TripEasyMiniBar extends StatelessWidget {
  const TripEasyMiniBar({super.key});

  static String whatOf(TripEasyRowKind k) => switch (k) {
        TripEasyRowKind.stay => TripStringsV2Easy.stayShort,
        TripEasyRowKind.taxi => TripStringsV2Easy.taxiShort,
        _ => TripStringsV2Easy.waysShort,
      };

  static String lineOf(TripEasyRowInfo r) => TripStringsV2Easy.miniBar(
        whatOf(r.kind),
        r.state == TripRowState.offer ? TripStringsV2Easy.offerWaiting : TripStringsV2Easy.waitingForReply,
      );

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final row = c.plan.value == null ? null : c.easyInProgress;
      if (row == null) return const SizedBox.shrink();
      return Material(
        color: Colors.white,
        elevation: 6,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => TripNavigation.openRepliesForRow(row.key),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lineOf(row),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
                TextButton(
                  onPressed: () => TripNavigation.openRepliesForRow(row.key),
                  child: const Text(TripStringsV2Easy.view,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
