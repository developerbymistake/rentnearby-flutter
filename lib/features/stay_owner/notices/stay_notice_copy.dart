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
import '../enquiries_tab/stay_work_format.dart';
import '../strings/stay_notice_strings.dart';

abstract final class StayNoticeKinds {
  static const editApproved = 'StayEditApproved';
  static const editRejected = 'StayEditRejected';
  static const festival = 'FestivalReminder';
  static const planLimits = 'PlanLimitsChanged';
  static const plansStarting = 'PlansStarting';
  static const all = [editApproved, editRejected, festival, planLimits, plansStarting];
}

abstract final class StayNoticeCopy {
  static MyPlanModel? debugPlan;
  static List<PlanModel>? debugCatalog;

  static List<PlanModel> get _catalog =>
      debugCatalog ?? (Get.isRegistered<PlanController>() ? Get.find<PlanController>().plans.toList() : const <PlanModel>[]);

  static int get _trialDays {
    for (final p in _catalog) {
      if (!p.isDefault && p.trialDays > 0) return p.trialDays;
    }
    return 0;
  }

  static MyPlanModel get _plan =>
      debugPlan ?? (Get.isRegistered<PlanController>() ? Get.find<PlanController>().myPlan.value : const MyPlanModel());

  static void register() {
    for (final k in StayNoticeKinds.all) {
      OwnerNoticeRegistry.register(k, of);
    }
  }

  static String? _text(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static NoticeView? of(Notice n) {
    switch (n.kind) {
      case StayNoticeKinds.editApproved:
        final name = _text(n.refTitle);
        return NoticeView(
          title: StayNoticeStrings.changeLive,
          body: name == null ? StayNoticeStrings.detailsUpdated : StayNoticeStrings.nameUpdated(name),
          tag: StayNoticeStrings.tagStay,
          art: ListingArt.camping,
          tone: NoticeTone.teal,
          route: AppRoutes.myStays,
          args: const {},
        );
      case StayNoticeKinds.editRejected:
        return NoticeView(
          title: StayNoticeStrings.changeNotApproved,
          body: _text(n.refTitle) ?? '',
          tag: StayNoticeStrings.tagStay,
          art: ListingArt.camping,
          tone: NoticeTone.rose,
          route: AppRoutes.myStays,
          args: const {},
        );
      case StayNoticeKinds.festival:
        final name = _text(n.refTitle);
        if (name == null) return null;
        final fromText = OwnerJson.strOrNull(n.args['dateFrom']);
        final toText = OwnerJson.strOrNull(n.args['dateTo']);
        final from = _day(fromText);
        return NoticeView(
          title: from == null ? StayNoticeStrings.festivalWeek(name) : StayNoticeStrings.festivalStarts(name, StayWorkFormat.dayMonth(from)),
          body: StayNoticeStrings.setYourPrice,
          tag: StayNoticeStrings.tagPrice,
          art: ListingArt.diyaLamp,
          tone: NoticeTone.indigo,
          route: AppRoutes.staySpecialPrices,
          args: {'festivalId': ?_text(n.refId), 'dateFrom': ?fromText, 'dateTo': ?toText},
        );
      case StayNoticeKinds.planLimits:
        final hidden = _plan.hidden;
        if (hidden.photos <= 0 && hidden.roomTypes <= 0) {
          if (hidden.specialPrices <= 0) {
            if (_plan.pausedByPlanCount <= 0) return null;
            return NoticeView(
              title: StayNoticeStrings.jobsInactiveTitle,
              body: StayNoticeStrings.jobsInactive,
              tag: StayNoticeStrings.tagPlan,
              art: ListingArt.briefcase,
              tone: NoticeTone.indigo,
              route: AppRoutes.myJobs,
              args: const {},
            );
          }
          return NoticeView(
            title: StayNoticeStrings.specialPricesPausedTitle,
            body: StayNoticeStrings.specialPricesPaused(hidden.specialPrices),
            tag: StayNoticeStrings.tagPlan,
            art: ListingArt.diyaLamp,
            tone: NoticeTone.indigo,
            route: AppRoutes.staySpecialPrices,
            args: const {},
          );
        }
        return NoticeView(
          title: StayNoticeStrings.plansStarted,
          body: StayNoticeStrings.hiddenOnFree(hidden.photos, hidden.roomTypes),
          tag: StayNoticeStrings.tagPlan,
          art: ListingArt.crown,
          tone: NoticeTone.indigo,
          route: AppRoutes.stayPlanVisible,
          args: const {},
        );
      case StayNoticeKinds.plansStarting:
        final plan = _plan;
        final on = plan.paymentStartsOn;
        if (on == null) return null;
        return NoticeView(
          title: StayNoticeStrings.plansStartOn(StayWorkFormat.dayMonth(on)),
          body: _freeKeeps(plan),
          tag: StayNoticeStrings.tagPlan,
          art: ListingArt.crown,
          tone: NoticeTone.indigo,
          route: AppRoutes.plansBilling,
          args: const {},
        );
    }
    return null;
  }

  static String _freeKeeps(MyPlanModel plan) {
    final values = PlanValues.fromCatalog(_catalog);
    return StayNoticeStrings.freeKeeps(values.free(PlanKey.photos), values.free(PlanKey.roomTypes), plan.trialAvailable ? _trialDays : 0);
  }

  static DateTime? _day(String? v) {
    if (v == null || v.length < 10) return null;
    final d = DateTime.tryParse(v.substring(0, 10));
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }
}
