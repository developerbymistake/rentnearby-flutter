import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
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
        backgroundColor: FitnessAppTheme.white,
        shape: const RoundedRectangleBorder(borderRadius: TripLook.softRadius),
        title: const Text(
          TripStringsV2Easy.confirmTitle,
          style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 16, fontWeight: FontWeight.w700, color: TripLook.textDark),
        ),
        content: Text(
          TripStringsV2Easy.confirmBody(whatOf(key)),
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: TripLook.textMedium, height: 1.4),
        ),
        actions: [
          TextLink(label: TripStringsV2Easy.cancel, onTap: () => Navigator.pop(ctx, false), tone: KitTone.trip),
          TextLink(label: TripStringsV2Easy.yes, onTap: () => Navigator.pop(ctx, true), tone: KitTone.trip),
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
        backgroundColor: FitnessAppTheme.white,
        shape: const RoundedRectangleBorder(borderRadius: TripLook.softRadius),
        content: Text(
          TripStringsV2Easy.withdrawLine(res.open.length),
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, color: TripLook.textDark, height: 1.4),
        ),
        actions: [
          TextLink(label: TripStringsV2Easy.cancel, onTap: () => Navigator.pop(ctx, false), tone: KitTone.trip),
          TextLink(label: TripStringsV2Easy.withdraw, onTap: () => Navigator.pop(ctx, true), tone: KitTone.trip),
        ],
      ),
    );
    if (yes != true) return null;
    return c.markOwn(key, withdrawOpen: true);
  }
}
