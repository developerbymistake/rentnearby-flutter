import '../../../design/design.dart';
import '../../../design/extra/ext_plans.dart';
import '../../../models/my_plan_model.dart';
import '../../../models/plan_model.dart';
import '../../../widgets/plan_words.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/plan/plan_card_state.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../taxi_driver_deps.dart';
import 'taxi_plan_strings.dart';

class TaxiPlanCopy extends PlanRoleCopy {
  const TaxiPlanCopy();

  static const int weeklyMin = 10;

  @override
  String get featureKey => 'Taxi';
  @override
  String get subtitle => TaxiPlanStrings.subtitle;
  @override
  ListingTone get homeTone => ListingTone.coral;
  @override
  String get offLine => TaxiPlanStrings.offLine;
  @override
  String get onHoldBody => PlanWords.fixToContinue;
  @override
  bool get showsWeek => true;
  @override
  String? get chooseLabel => TaxiPlanStrings.chooseYourRoute;
  @override
  void openChoose() => TaxiDriverDeps.openChooseRoute();

  @override
  String heroSubtitle(PlanCardState s, MyPlanModel me) => switch (s) {
        PlanCardState.paymentOff => PlanWords.freeForNow,
        PlanCardState.trial || PlanCardState.plus || PlanCardState.cancelled || PlanCardState.grace => PlanWords.billedByPlay,
        _ => PlanWords.noEndDate,
      };

  @override
  List<PlanHeroLine> heroLines(PlanCardState s, MyPlanModel me, PlanValues v) {
    final l = me.limits;
    if (s == PlanCardState.paymentOff) {
      return [PlanHeroLine(TaxiPlanStrings.upToRoutesRing(l.routes)), const PlanHeroLine(TaxiPlanStrings.requestsBookingsRating)];
    }
    if (PlanCardStates.plusValues(s)) {
      return [
        PlanHeroLine(TaxiPlanStrings.upToRoutes(l.routes)),
        PlanHeroLine(TaxiPlanStrings.turnAsOften(l.ringWeight)),
        const PlanHeroLine(TaxiPlanStrings.featuredInLists),
      ];
    }
    return [PlanHeroLine(TaxiPlanStrings.routesCount(l.routes)), const PlanHeroLine(TaxiPlanStrings.normalTurn, on: false)];
  }

  @override
  PlanHeroMeter? heroMeter(PlanCardState s, MyPlanModel me, PlanValues v) {
    final used = me.usage.routes;
    final limit = me.limits.routes;
    if (used == null || limit <= 0) return null;
    final note = switch (s) {
      PlanCardState.free => TaxiPlanStrings.freeMeterNote(limit, v.plus(PlanKey.routes)),
      PlanCardState.ended => TaxiPlanStrings.lastRouteStays,
      PlanCardState.trial || PlanCardState.plus || PlanCardState.adminGrant => null,
      _ => '',
    };
    if (note == '') return null;
    return PlanHeroMeter(
      label: TaxiPlanStrings.routes,
      value: PlanWords.of(used, limit),
      fraction: used / limit,
      notes: [?note],
    );
  }

  @override
  String? subNote(PlanCardState s, MyPlanModel me, PlanValues v) {
    final free = v.free(PlanKey.routes);
    return switch (s) {
      PlanCardState.cancelled => TaxiPlanStrings.keepAfter(free),
      PlanCardState.onHold => TaxiPlanStrings.keepUntil(free),
      PlanCardState.ended => me.hidden.routes > 0 || me.pausedByPlanCount > 0 ? TaxiPlanStrings.extraHidden : null,
      _ => null,
    };
  }

  static PlanCellData _n(int n) => CompareCellData.text('$n');

  @override
  List<PlanRowData> compareRows(PlanValues v) {
    PlanRowData row(String label, String art, PlanCellData free, PlanCellData plus, {bool isNew = true}) => PlanRowData(
          label: label,
          art: art,
          tag: isNew ? PlanWords.newTag : null,
          cells: [free, plus],
          semantics: PlanWords.row(label, CompareCellData.spoken(free), CompareCellData.spoken(plus)),
        );
    PlanCellData flag(bool on) => PlanCellData('', on ? PlanCellKind.yes : PlanCellKind.no);
    return [
      row(TaxiPlanStrings.rowRoutes, ListingArt.worldMap, _n(v.free(PlanKey.routes)), _n(v.plus(PlanKey.routes))),
      row(TaxiPlanStrings.rowTurn, ListingArt.bell, CompareCellData.text(PlanWords.turn(v.free(PlanKey.ringWeight))),
          CompareCellData.text(PlanWords.turn(v.plus(PlanKey.ringWeight)))),
      row(TaxiPlanStrings.rowFeatured, ListingArt.star, flag(v.freeFlag(PlanFeatureKeys.featured)), flag(v.plusFlag(PlanFeatureKeys.featured)), isNew: false),
      row(TaxiPlanStrings.rowRequests, ListingArt.calendar, flag(true), flag(true)),
      row(TaxiPlanStrings.rowUpcoming, ListingArt.calendar, CompareCellData.text(PlanWords.upcoming(v.free(PlanKey.upcomingDays))),
          CompareCellData.text(PlanWords.upcoming(v.plus(PlanKey.upcomingDays)))),
      row(TaxiPlanStrings.rowMonth, ListingArt.calendar, CompareCellData.text(PlanWords.monthView(v.free(PlanKey.monthsAhead))),
          CompareCellData.text(PlanWords.monthView(v.plus(PlanKey.monthsAhead)))),
      row(TaxiPlanStrings.rowTrips, ListingArt.memo, _n(v.free(PlanKey.calendarEntries)), _n(v.plus(PlanKey.calendarEntries))),
      row(TaxiPlanStrings.rowReminder, ListingArt.alarmClock, flag(v.free(PlanKey.reminders) > 0), flag(v.plus(PlanKey.reminders) > 0)),
      row(TaxiPlanStrings.rowSummary, ListingArt.moneyBag, flag(v.free(PlanKey.monthSummary) > 0), flag(v.plus(PlanKey.monthSummary) > 0)),
      row(TaxiPlanStrings.rowMoneyNotes, ListingArt.memo, flag(true), flag(true)),
    ];
  }

  @override
  String profileLine(MyPlanModel me) {
    final used = me.usage.routes;
    return used == null ? me.planName : TaxiPlanStrings.profileLine(me.planName, used, me.limits.routes);
  }

  @override
  List<(String, String)> weekCells(OwnerWeekly w) {
    final on = w.requestsOnRoutes;
    final acc = w.accepted;
    if (on == null || acc == null) return const [];
    final weight = PlanGate.limit(PlanKey.ringWeight);
    return [
      ('$on', TaxiPlanStrings.weekRequests),
      ('$acc', TaxiPlanStrings.weekAccepted),
      if (weight > 1) (TaxiPlanStrings.turnValue(weight), TaxiPlanStrings.weekTurn),
    ];
  }

  static String? plusLine({int? accepted, String? renewDate, required int routes, int? ringWeight, required bool hasNumbers}) {
    if (hasNumbers && accepted != null) return renewDate != null ? TaxiPlanStrings.acceptedRenews(accepted, renewDate) : TaxiPlanStrings.accepted(accepted);
    final parts = <String>[
      if (renewDate != null) TaxiPlanStrings.renews(renewDate),
      TaxiPlanStrings.routesOpenNow(routes),
      if ((ringWeight ?? 1) > 1) '${TaxiPlanStrings.turnAsOften(ringWeight!)}.',
    ];
    return parts.join(' ');
  }

  @override
  PlanHomeView homeCard(OwnerPlanCard? card, {String? city, PlanValues v = const PlanValues()}) {
    final s = card?.state ?? PlanCardState.unknown;
    final renew = card?.renewsOn ?? card?.endsAt;
    final end = card?.endsAt ?? card?.renewsOn;
    final w = card?.weekly;
    final routes = PlanCardLimits.plus(card, 'routes', PlanKey.routes);
    switch (s) {
      case PlanCardState.free:
        final n = w?.requestsNoRoute;
        return PlanHomeView(
          state: s,
          title: PlanWords.freePlan,
          line: n != null && n >= weeklyMin ? TaxiPlanStrings.noRouteRequests(n) : TaxiPlanStrings.moreRoutes,
          action: card?.trialAvailable == true ? PlanHomeAction.tryFree : PlanHomeAction.seePlus,
        );
      case PlanCardState.trial:
        return PlanHomeView(
          state: s,
          title: end == null ? PlanWords.plus : PlanWords.freeUntil(end),
          pill: PlanWords.trial,
          line: TaxiPlanStrings.routesOpenNow(routes),
          action: PlanHomeAction.manage,
          art: ListingArt.star,
        );
      case PlanCardState.plus:
      case PlanCardState.adminGrant:
        final on = w?.requestsOnRoutes;
        final acc = w?.accepted;
        final grant = s == PlanCardState.adminGrant;
        final date = renew == null || grant ? null : PlanWords.date(renew);
        final line = plusLine(accepted: acc, renewDate: date, routes: routes, ringWeight: card?.ringWeight, hasNumbers: on != null);
        return PlanHomeView(
          state: s,
          title: on != null ? TaxiPlanStrings.requestsOnRoutes(on) : PlanWords.yourPlan,
          pill: PlanWords.plus,
          line: line,
          action: grant ? PlanHomeAction.none : PlanHomeAction.manage,
        );
      case PlanCardState.cancelled:
        return PlanHomeView(
          state: s,
          title: end == null ? PlanWords.plus : PlanWords.plusTill(end),
          pill: end == null ? null : PlanWords.plus,
          line: TaxiPlanStrings.keepAfter(v.free(PlanKey.routes)),
          action: PlanHomeAction.manage,
          art: ListingArt.calendar,
        );
      case PlanCardState.grace:
        return const PlanHomeView(
          state: PlanCardState.grace,
          title: PlanWords.paymentIssue,
          pill: PlanWords.plus,
          line: PlanWords.plusKeepsWorking,
          action: PlanHomeAction.fix,
          look: PlanHomeLook.warn,
          art: ListingArt.warning,
        );
      case PlanCardState.onHold:
        final carry = card?.isPaid == true && end != null;
        return PlanHomeView(
          state: s,
          title: carry ? PlanWords.plusTill(end) : PlanWords.paymentOnHold,
          line: PlanWords.fixFirst,
          action: PlanHomeAction.fix,
          look: PlanHomeLook.warn,
          art: ListingArt.warning,
        );
      case PlanCardState.ended:
        return PlanHomeView(
          state: PlanCardState.ended,
          title: PlanWords.subscriptionEnded,
          line: PlanCardLimits.hidden(card, 'routes') > 0 ? TaxiPlanStrings.extraHidden : null,
          action: PlanHomeAction.subscribeAgain,
          look: PlanHomeLook.ended,
        );
      case PlanCardState.paymentOff:
        return const PlanHomeView(
          state: PlanCardState.paymentOff,
          title: PlanWords.paidPlansComing,
          line: TaxiPlanStrings.offLine,
          look: PlanHomeLook.off,
          art: ListingArt.star,
        );
      case PlanCardState.unknown:
        return const PlanHomeView(state: PlanCardState.unknown, title: PlanWords.freePlan, line: TaxiPlanStrings.moreRoutes);
    }
  }
}
