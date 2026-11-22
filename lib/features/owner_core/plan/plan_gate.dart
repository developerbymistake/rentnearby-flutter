import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../controllers/plan_controller.dart';
import '../../../models/my_plan_model.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../data/owner_error_types.dart';
import '../data/owner_result.dart';
import '../strings/owner_shared_strings.dart';
import 'plan_keys.dart';
import 'plan_limit_sheet.dart';

class GateRow {
  const GateRow({required this.label, required this.value, this.sub, this.highlight = false});

  final String label;
  final String value;
  final String? sub;
  final bool highlight;
}

class GateSpec {
  const GateSpec({
    required this.id,
    required this.title,
    required this.body,
    required this.taxi,
    this.art,
    this.rows = const [],
    this.tip,
  });

  final String id;
  final String title;
  final String body;
  final bool taxi;
  final String? art;
  final List<GateRow> rows;
  final String? tip;
}

abstract final class PlanGate {
  static const int stayMonthlyInr = 400;
  static const int taxiMonthlyInr = 150;

  static MyPlanModel? debugPlan;

  static MyPlanModel get _plan {
    final d = debugPlan;
    if (d != null) return d;
    return Get.isRegistered<PlanController>() ? Get.find<PlanController>().myPlan.value : const MyPlanModel();
  }

  // Callers that refuse locally must check this first: before the first /plans/me answer the
  // limits are the model defaults, not the owner's plan.
  static bool get loaded => debugPlan != null || (Get.isRegistered<PlanController>() && Get.find<PlanController>().loaded.value);

  static bool get paymentOn => _plan.paymentEnabled;

  static bool get canUpgrade => _plan.paymentEnabled && _plan.canUpgrade;

  static bool get trialAvailable => _plan.trialAvailable;

  static int limit(PlanKey key) => PlanKeys.valueOf(_plan.limits, key);

  static bool on(PlanKey key) => limit(key) > 0;

  static bool full(PlanKey key, int used) => used >= limit(key);

  static bool locks(PlanKey key, int used) => canUpgrade && full(key, used);

  static String _monthlyAmount(bool taxi) {
    if (debugPlan == null && Get.isRegistered<PlanController>()) {
      final c = Get.find<PlanController>();
      for (final p in c.plans) {
        if (p.isDefault) continue;
        final store = c.storePriceFor(p, 1);
        if (store != null && store.formatted.isNotEmpty) return store.formatted;
        final catalog = p.priceFor(1);
        if (catalog != null && catalog.priceInr > 0) return Money.exact(catalog.priceInr);
      }
    }
    return Money.exact(taxi ? taxiMonthlyInr : stayMonthlyInr);
  }

  static String priceLine({required bool taxi}) {
    final amount = _monthlyAmount(taxi);
    return '$amount${OwnerSharedStrings.perMonth}${trialAvailable ? OwnerSharedStrings.trialSuffix : ''}';
  }

  static Future<void> showLimit(BuildContext context, GateSpec spec) async {
    if (!canUpgrade) return;
    await PlanLimitSheet.show(context, spec);
  }

  static Future<bool> guard(BuildContext context, PlanKey key, int used, GateSpec Function() spec) async {
    if (!locks(key, used)) return true;
    await showLimit(context, spec());
    return false;
  }

  static GateSpec? fromRefusal(OwnerRefused<dynamic> r, GateSpec Function(String key, int limit) spec) {
    final info = OwnerRefusal.limit(r);
    if (info == null || !info.canUpgrade || !paymentOn) return null;
    return spec(info.key, info.limit);
  }

  static Future<bool> handleRefusal(BuildContext context, OwnerRefused<dynamic> r, GateSpec Function(String key, int limit) spec) async {
    final info = OwnerRefusal.limit(r);
    if (info == null) return false;
    final gate = fromRefusal(r, spec);
    if (gate != null) {
      await showLimit(context, gate);
    } else {
      final msg = r.message;
      if (msg != null && msg.isNotEmpty) AppToast.info(msg);
    }
    return true;
  }

  static void seePlus() => Get.toNamed(AppRoutes.plansBilling);
}
