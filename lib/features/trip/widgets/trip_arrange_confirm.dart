import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_strings_v2_easy.dart';

class TripArrangeConfirm {
  const TripArrangeConfirm._();

  static String whatOf(TripEasyRowKey key) => switch (key.kind) {
        TripEasyRowKind.stay => TripStringsV2Easy.whatStay,
        TripEasyRowKind.taxi => TripStringsV2Easy.whatTaxi,
        _ => TripStringsV2Easy.whatTravel,
      };

  static Future<bool> show(BuildContext context, TripEasyRowKey key) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          TripStringsV2Easy.confirmTitle,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        content: Text(
          TripStringsV2Easy.confirmBody(whatOf(key)),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(TripStringsV2Easy.cancel,
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStringsV2Easy.yes,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  static Future<TripMarkResult?> mark(BuildContext context, TripEasyRowKey key) async {
    final c = TripPlanController.to;
    final res = await c.markOwn(key);
    if (res is! TripMarkNeedsWithdraw || !context.mounted) return res;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Text(
          TripStringsV2Easy.withdrawLine(res.open.length),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(TripStringsV2Easy.cancel,
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStringsV2Easy.withdraw,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    if (yes != true) return null;
    return c.markOwn(key, withdrawOpen: true);
  }
}
