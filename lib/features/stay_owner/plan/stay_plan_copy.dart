import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_plans.dart';
import '../../../models/my_plan_model.dart';
import '../../../models/plan_model.dart';
import '../../../widgets/plan_words.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/plan/plan_card_state.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../strings/stay_quote_strings.dart';
import 'stay_plan_strings.dart';

class StayPlanCopy extends PlanRoleCopy {
  const StayPlanCopy();

  static const int weeklyMin = 10;

  @override
  String get featureKey => 'Stay';
  @override
  String get subtitle => StayPlanStrings.subtitle;
  @override
  ListingTone get homeTone => ListingTone.indigo;
  @override
  String get offLine => StayPlanStrings.offLine;
  @override
  String get onHoldBody => PlanWords.fixFirst;
  @override
  bool get showsWeek => true;
  @override
  String? get chooseLabel => StayPlanStrings.chooseWhatStays;
  @override
  void openChoose() => Get.toNamed(AppRoutes.stayPlanVisible);

  @override
  String heroSubtitle(PlanCardState s, MyPlanModel me) {
    switch (s) {
      case PlanCardState.paymentOff:
        return PlanWords.freeForNow;
      case PlanCardState.trial:
        final end = me.play?.trialEndsAt ?? me.play?.expiryAt ?? me.endsAt;
        return end == null ? PlanWords.billedByPlay : PlanWords.freeUntil(end);
      case PlanCardState.cancelled:
        return PlanWords.autoRenewOff;
      case PlanCardState.plus || PlanCardState.grace:
        return PlanWords.billedByPlay;
      case PlanCardState.onHold:
        return PlanWords.paymentOnHold;
      default:
        return PlanWords.noEndDate;
    }
  }

  @override
  List<PlanHeroLine> heroLines(PlanCardState s, MyPlanModel me, PlanValues v) {
    final l = me.limits;
    switch (s) {
      case PlanCardState.paymentOff:
      case PlanCardState.unknown:
        return const [];
      case PlanCardState.plus:
      case PlanCardState.grace:
      case PlanCardState.adminGrant:
        return [
          const PlanHeroLine(StayPlanStrings.firstInTripPlans),
          const PlanHeroLine(StayPlanStrings.featuredNearYou),
          PlanHeroLine(StayPlanStrings.photosRooms(l.photos, l.roomTypes)),
          PlanHeroLine(StayPlanStrings.jobPosts(l.jobsPosts)),
          PlanHeroLine(StayQuoteStrings.planPerk(l.quotationsPerMonth)),
        ];
      case PlanCardState.trial:
      case PlanCardState.cancelled:
        return [
          const PlanHeroLine(StayPlanStrings.firstInTripPlans),
          PlanHeroLine(StayPlanStrings.photosRoomsJobs(l.photos, l.roomTypes, l.jobsPosts)),
        ];
      case PlanCardState.onHold:
      case PlanCardState.ended:
        return [
          PlanHeroLine(StayPlanStrings.photosRoomsJobs(l.photos, l.roomTypes, l.jobsPosts)),
          const PlanHeroLine(StayPlanStrings.listedByDistance, on: false),
        ];
      case PlanCardState.free:
        return [
          PlanHeroLine(StayPlanStrings.photos(l.photos)),
          PlanHeroLine(StayPlanStrings.roomTypes(l.roomTypes)),
          PlanHeroLine(StayPlanStrings.jobPosts(l.jobsPosts)),
          const PlanHeroLine(StayPlanStrings.notFirst, on: false),
        ];
    }
  }

  @override
  PlanHeroMeter? heroMeter(PlanCardState s, MyPlanModel me, PlanValues v) {
    if (s != PlanCardState.free && s != PlanCardState.ended) return null;
    final used = me.usage.photos;
    final limit = me.limits.photos;
    if (used == null || limit <= 0) return null;
    final rooms = me.usage.roomTypes;
    final notes = s == PlanCardState.ended
        ? [StayPlanStrings.coverStays]
        : [if (rooms != null) StayPlanStrings.roomTypesMeter(rooms, me.limits.roomTypes)];
    return PlanHeroMeter(label: StayPlanStrings.photosLabel, value: PlanWords.of(used, limit), fraction: used / limit, notes: notes);
  }

  @override
  String? subNote(PlanCardState s, MyPlanModel me, PlanValues v) {
    final p = v.free(PlanKey.photos);
    final r = v.free(PlanKey.roomTypes);
    switch (s) {
      case PlanCardState.trial:
        return StayPlanStrings.openNow(me.limits.photos, me.limits.roomTypes);
      case PlanCardState.cancelled:
        return StayPlanStrings.keepAfter(p, r);
      case PlanCardState.onHold:
        return StayPlanStrings.keepUntil(p, r);
      case PlanCardState.ended:
        final h = me.hidden;
        return h.photos > 0 || h.roomTypes > 0 ? StayPlanStrings.hidden(h.photos, h.roomTypes) : null;
      default:
        return null;
    }
  }

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
    PlanCellData n(int x) => CompareCellData.text('$x');
    return [
      row(StayPlanStrings.rowFirst, ListingArt.compass, flag(v.freeFlag(PlanFeatureKeys.priority)), flag(v.plusFlag(PlanFeatureKeys.priority)), isNew: false),
      row(StayPlanStrings.rowFeatured, ListingArt.star, flag(v.freeFlag(PlanFeatureKeys.featured)), flag(v.plusFlag(PlanFeatureKeys.featured)), isNew: false),
      row(StayPlanStrings.rowPhotos, ListingArt.camera, n(v.free(PlanKey.photos)), n(v.plus(PlanKey.photos))),
      row(StayPlanStrings.rowRoomTypes, ListingArt.bed, n(v.free(PlanKey.roomTypes)), n(v.plus(PlanKey.roomTypes))),
      row(StayPlanStrings.rowJobs, ListingArt.briefcase, n(v.free(PlanKey.jobsPosts)), n(v.plus(PlanKey.jobsPosts)), isNew: false),
      row(StayPlanStrings.rowEnquiries, ListingArt.speechBalloon, flag(true), flag(true)),
      row(StayPlanStrings.rowUpcoming, ListingArt.calendar, CompareCellData.text(PlanWords.upcoming(v.free(PlanKey.upcomingDays))),
          CompareCellData.text(PlanWords.upcoming(v.plus(PlanKey.upcomingDays)))),
      row(StayPlanStrings.rowMonth, ListingArt.calendar, CompareCellData.text(PlanWords.monthView(v.free(PlanKey.monthsAhead))),
          CompareCellData.text(PlanWords.monthView(v.plus(PlanKey.monthsAhead)))),
      row(StayPlanStrings.rowBookings, ListingArt.memo, n(v.free(PlanKey.calendarEntries)), n(v.plus(PlanKey.calendarEntries))),
      row(StayPlanStrings.rowBlocked, ListingArt.locked, n(v.free(PlanKey.blockedRanges)), n(v.plus(PlanKey.blockedRanges))),
      row(StayPlanStrings.rowMoneyNotes, ListingArt.memo, flag(true), flag(true)),
      row(StayPlanStrings.rowReminder, ListingArt.alarmClock, flag(v.free(PlanKey.reminders) > 0), flag(v.plus(PlanKey.reminders) > 0)),
      row(StayPlanStrings.rowSummary, ListingArt.moneyBag, flag(v.free(PlanKey.monthSummary) > 0), flag(v.plus(PlanKey.monthSummary) > 0)),
      row(StayPlanStrings.rowSpecial, ListingArt.diyaLamp, n(v.free(PlanKey.specialPrices)), n(v.plus(PlanKey.specialPrices))),
      row(StayQuoteStrings.planRow, ListingArt.memo, n(v.free(PlanKey.quotationsPerMonth)), n(v.plus(PlanKey.quotationsPerMonth))),
    ];
  }

  @override
  String profileLine(MyPlanModel me) {
    final used = me.usage.photos;
    return used == null ? me.planName : StayPlanStrings.profileLine(me.planName, used, me.limits.photos);
  }

  @override
  List<(String, String)> weekCells(OwnerWeekly w) {
    final shown = w.shown;
    final enq = w.enquiries;
    if (shown == null || enq == null) return const [];
    return [('$shown', StayPlanStrings.timesShown), ('$enq', StayPlanStrings.enquiries)];
  }

  @override
  PlanHomeView homeCard(OwnerPlanCard? card, {String? city, PlanValues v = const PlanValues()}) {
    final s = card?.state ?? PlanCardState.unknown;
    final renew = card?.renewsOn ?? card?.endsAt;
    final end = card?.endsAt ?? card?.renewsOn;
    final w = card?.weekly;
    final c = city?.trim();
    final reach = c == null || c.isEmpty ? null : StayPlanStrings.firstForTrip(c);
    switch (s) {
      case PlanCardState.free:
        final shown = w?.shown;
        final real = shown != null && shown >= weeklyMin;
        return PlanHomeView(
          state: s,
          title: real ? StayPlanStrings.shownTimes(shown) : PlanWords.freePlan,
          pill: real ? PlanWords.freePlan : null,
          line: reach,
          action: card?.trialAvailable == true ? PlanHomeAction.tryFree : PlanHomeAction.seePlus,
        );
      case PlanCardState.trial:
        return PlanHomeView(
          state: s,
          title: end == null ? PlanWords.plus : PlanWords.freeUntil(end),
          pill: PlanWords.trial,
          line: StayPlanStrings.openNow(PlanCardLimits.plus(card, 'photos', PlanKey.photos), PlanCardLimits.plus(card, 'roomTypes', PlanKey.roomTypes)),
          action: PlanHomeAction.manage,
          art: ListingArt.star,
        );
      case PlanCardState.plus:
      case PlanCardState.adminGrant:
        final shown = w?.shown;
        final enq = w?.enquiries;
        final grant = s == PlanCardState.adminGrant;
        final date = renew == null || grant ? null : PlanWords.date(renew);
        String? line;
        if (enq != null && date != null) {
          line = StayPlanStrings.enquiriesRenews(enq, date);
        } else if (enq != null) {
          line = StayPlanStrings.enquiriesWeek(enq);
        } else if (date != null) {
          line = StayPlanStrings.renews(date);
        }
        return PlanHomeView(
          state: s,
          title: shown != null ? StayPlanStrings.shownTimes(shown) : PlanWords.plus,
          pill: shown != null ? PlanWords.plus : null,
          line: line,
          action: grant ? PlanHomeAction.none : PlanHomeAction.manage,
        );
      case PlanCardState.cancelled:
        return PlanHomeView(
          state: s,
          title: end == null ? PlanWords.plus : PlanWords.plusTill(end),
          pill: end == null ? null : PlanWords.plus,
          line: StayPlanStrings.keepAfter(v.free(PlanKey.photos), v.free(PlanKey.roomTypes)),
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
        final p = PlanCardLimits.hidden(card, 'photos');
        final r = PlanCardLimits.hidden(card, 'roomTypes');
        return PlanHomeView(
          state: s,
          title: PlanWords.subscriptionEnded,
          line: p > 0 || r > 0 ? StayPlanStrings.hidden(p, r) : null,
          action: PlanHomeAction.subscribeAgain,
          look: PlanHomeLook.ended,
        );
      case PlanCardState.paymentOff:
        return const PlanHomeView(
          state: PlanCardState.paymentOff,
          title: PlanWords.paidPlansComing,
          line: StayPlanStrings.offLine,
          look: PlanHomeLook.off,
          art: ListingArt.star,
        );
      case PlanCardState.unknown:
        return PlanHomeView(state: PlanCardState.unknown, title: PlanWords.freePlan, line: reach);
    }
  }
}
