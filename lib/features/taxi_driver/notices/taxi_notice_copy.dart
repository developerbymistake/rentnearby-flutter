import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../controllers/plan_controller.dart';
import '../../../design/design.dart';
import '../../../models/my_plan_model.dart';
import '../../../models/plan_model.dart';
import '../../buddy/notices/models/notice_models.dart';
import '../../buddy/notices/notice_copy.dart';
import '../../owner_core/json/owner_json.dart';
import '../../owner_core/plan/plan_card_state.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/session/owner_notice_registry.dart';
import '../strings/taxi_work_strings.dart';

/// Stored notice kinds of the taxi shell (o_tx_21, o_tx_49, o_tx_45 C). Row text is built from ids and the plan, never stored text.
abstract final class TaxiNoticeKinds {
  static const festival = 'FestivalReminder';
  static const planLimits = 'PlanLimitsChanged';
  static const plansStarting = 'PlansStarting';
  static const all = [festival, planLimits, plansStarting];
}

abstract final class TaxiNoticeCopy {
  static MyPlanModel? debugPlan;
  static List<PlanModel>? debugCatalog;

  static List<PlanModel> get _catalog =>
      debugCatalog ?? (Get.isRegistered<PlanController>() ? Get.find<PlanController>().plans.toList() : const <PlanModel>[]);

  static int freeRoutes(List<PlanModel> catalog) => PlanValues.fromCatalog(catalog).free(PlanKey.routes);

  static int trialDays(List<PlanModel> catalog) {
    for (final p in catalog) {
      if (!p.isDefault && p.trialDays > 0) return p.trialDays;
    }
    return 0;
  }

  static MyPlanModel get _plan =>
      debugPlan ?? (Get.isRegistered<PlanController>() ? Get.find<PlanController>().myPlan.value : const MyPlanModel());

  static void register() {
    for (final k in TaxiNoticeKinds.all) {
      OwnerNoticeRegistry.register(k, of);
    }
  }

  static String? _text(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static DateTime? _day(String? v) {
    if (v == null || v.length < 10) return null;
    final d = DateTime.tryParse(v.substring(0, 10));
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static NoticeView? of(Notice n) {
    switch (n.kind) {
      case TaxiNoticeKinds.festival:
        final name = _text(n.refTitle);
        final from = _day(OwnerJson.strOrNull(n.args['dateFrom']));
        if (name == null || from == null) return null;
        return NoticeView(
          title: TaxiWorkStrings.festivalTitle(name, TaxiWorkStrings.day(from)),
          body: TaxiWorkStrings.festivalBody,
          tag: TaxiWorkStrings.tagFestival,
          art: ListingArt.diyaLamp,
          tone: NoticeTone.rose,
          route: AppRoutes.myTaxi,
          args: const {'section': 'routes'},
        );
      case TaxiNoticeKinds.planLimits:
        final routes = _plan.hidden.routes;
        if (routes <= 0) return null;
        return NoticeView(
          title: TaxiWorkStrings.plansStartedTitle,
          body: TaxiWorkStrings.routesHidden(routes),
          tag: TaxiWorkStrings.tagPlan,
          art: ListingArt.crown,
          tone: NoticeTone.rose,
          route: AppRoutes.taxiPlanVisible,
          args: const {},
        );
      case TaxiNoticeKinds.plansStarting:
        final plan = _plan;
        final on = plan.paymentStartsOn;
        if (on == null) return null;
        return NoticeView(
          title: TaxiWorkStrings.plansStartTitle(TaxiWorkStrings.day(on)),
          body: TaxiWorkStrings.freeKeeps(freeRoutes(_catalog), trialDays: plan.trialAvailable ? trialDays(_catalog) : 0),
          tag: TaxiWorkStrings.tagPlan,
          art: ListingArt.crown,
          tone: NoticeTone.rose,
          route: AppRoutes.plansBilling,
          args: const {},
        );
    }
    return null;
  }
}
