import 'package:flutter/foundation.dart' show listEquals;
import '../../../utils/money_format.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';
import 'trip_enquiry_rules.dart';
import 'trip_format.dart';
import 'trip_geo.dart';
import 'trip_money.dart';
import 'trip_stay_base.dart';
import 'trip_step_rules.dart';
import 'trip_travel_rules.dart';

export 'trip_travel_rules.dart' show TripCarLine, TripCarState, TripJourneyRole;

enum TripWizardStepKind {
  basics,
  gettingThere,
  places,
  taxi,
  stay,
  travel,
  comingBack;

  static TripWizardStepKind? parse(Object? wire) {
    for (final k in values) {
      if (k.name == wire) return k;
    }
    return null;
  }
}

enum TripStepState { todo, waiting, attention, done, own, skipped }

class TripStepKey {
  final TripWizardStepKind kind;
  final int? legIndex;
  final int? dayInLeg;

  const TripStepKey._(this.kind, [this.legIndex, this.dayInLeg]);

  static const TripStepKey basics = TripStepKey._(TripWizardStepKind.basics);
  static const TripStepKey gettingThere = TripStepKey._(TripWizardStepKind.gettingThere);
  static const TripStepKey comingBack = TripStepKey._(TripWizardStepKind.comingBack);

  const TripStepKey.places(int leg, int dayInLeg) : this._(TripWizardStepKind.places, leg, dayInLeg);
  const TripStepKey.taxi(int leg, int dayInLeg) : this._(TripWizardStepKind.taxi, leg, dayInLeg);
  const TripStepKey.stay(int leg, int dayInLeg) : this._(TripWizardStepKind.stay, leg, dayInLeg);
  const TripStepKey.travel(int leg) : this._(TripWizardStepKind.travel, leg);

  static TripStepKey ofRole(TripStepRole r) => r == TripStepRole.gettingThere ? gettingThere : comingBack;

  bool get isDayStep =>
      kind == TripWizardStepKind.places || kind == TripWizardStepKind.taxi || kind == TripWizardStepKind.stay;

  bool get isJourney =>
      kind == TripWizardStepKind.gettingThere || kind == TripWizardStepKind.comingBack || kind == TripWizardStepKind.travel;

  TripStepRole? get stepRole => switch (kind) {
        TripWizardStepKind.gettingThere => TripStepRole.gettingThere,
        TripWizardStepKind.comingBack => TripStepRole.comingBack,
        _ => null,
      };

  String get id => switch (kind) {
        TripWizardStepKind.basics || TripWizardStepKind.gettingThere || TripWizardStepKind.comingBack => kind.name,
        TripWizardStepKind.travel => '${kind.name}:$legIndex',
        _ => '${kind.name}:$legIndex:$dayInLeg',
      };

  static TripStepKey? parse(String? id) {
    if (id == null || id.isEmpty) return null;
    final parts = id.split(':');
    final kind = TripWizardStepKind.parse(parts.first);
    if (kind == null) return null;
    final nums = [for (final p in parts.skip(1)) int.tryParse(p)];
    if (nums.any((n) => n == null || n < 1)) return null;
    return switch (kind) {
      TripWizardStepKind.basics || TripWizardStepKind.gettingThere || TripWizardStepKind.comingBack =>
        nums.isEmpty ? TripStepKey._(kind) : null,
      TripWizardStepKind.travel => nums.length == 1 && nums[0]! >= 2 ? TripStepKey.travel(nums[0]!) : null,
      _ => nums.length == 2 ? TripStepKey._(kind, nums[0], nums[1]) : null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TripStepKey && other.kind == kind && other.legIndex == legIndex && other.dayInLeg == dayInLeg;

  @override
  int get hashCode => Object.hash(kind, legIndex, dayInLeg);

  @override
  String toString() => id;
}

class TripStepInfo {
  final TripStepKey key;
  final int? day;
  final int? legIndex;
  final TripStepState state;
  final String title;
  final String line;
  final String? note;
  final int? agreedRupees;
  final bool needsYou;
  final List<TripCarLine> cars;
  final String? enquiryId;

  const TripStepInfo({
    required this.key,
    this.day,
    this.legIndex,
    required this.state,
    required this.title,
    required this.line,
    this.note,
    this.agreedRupees,
    this.needsYou = false,
    this.cars = const [],
    this.enquiryId,
  });

  TripWizardStepKind get kind => key.kind;

  bool get counted => state == TripStepState.done || state == TripStepState.own || state == TripStepState.skipped;

  bool get decided => counted && kind != TripWizardStepKind.basics && kind != TripWizardStepKind.places;

  bool get waitingForReply => state == TripStepState.waiting && !needsYou;
}

bool _always(int _) => true;

class TripWizardInput {
  final TripPlan plan;
  final List<TripEnquiryModel> enquiries;
  final List<TripJourney> journeys;
  final Set<String> dismissedEnquiryIds;
  final DateTime today;
  final bool readOnly;
  final bool Function(int day) supplyKnown;
  final Set<int> notReadyLegs;
  final Map<int, String?> travelGaps;
  final int Function(int day)? dayMinutes;
  final bool Function(int day)? overLimit;
  final bool journeysKnown;
  final TripSteps? _steps;

  const TripWizardInput({
    required this.plan,
    TripSteps? steps,
    this.enquiries = const [],
    this.journeys = const [],
    this.dismissedEnquiryIds = const {},
    required this.today,
    this.readOnly = false,
    this.supplyKnown = _always,
    this.notReadyLegs = const {},
    this.travelGaps = const {},
    this.dayMinutes,
    this.overLimit,
    this.journeysKnown = true,
  }) : _steps = steps;

  TripSteps get steps => _steps ?? plan.steps;

  TripSettings get settings => plan.settings;

  int get dayCount => plan.days.length;

  bool isDismissed(String id) => dismissedEnquiryIds.contains(id) || plan.dismissedEnquiryIds.contains(id);
}

enum TripStartKind { arrival, stay, stayUnconfirmed, ownStay, noStay, notChosen, checkOut }

enum TripDriverUpdate { none, start, places }

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

class TripStartInfo {
  final String heading;
  final String line;
  final TripPoint? point;
  final TripStartKind kind;
  final String? changedNote;

  final String? routeNote;

  const TripStartInfo(
      {required this.heading, required this.line, this.point, required this.kind, this.changedNote, this.routeNote});

  TripStartInfo withChangedNote(String? note) =>
      TripStartInfo(heading: heading, line: line, point: point, kind: kind, changedNote: note, routeNote: routeNote);

  TripStartInfo withRoute({String? line, String? routeNote}) => TripStartInfo(
      heading: heading, line: line ?? this.line, point: point, kind: kind, changedNote: changedNote, routeNote: routeNote);
}

class TripWizardCopy {
  const TripWizardCopy._();

  static const String basics = 'Trip basics';
  static const String gettingThere = 'Getting there';
  static const String comingBack = 'Coming back';
  static String places(int day) => 'Day $day · Places';
  static String taxi(int day) => 'Day $day · Sightseeing taxi';
  static String stay(int day) => 'Day $day · Stay';
  static String travel(String from, String to) => from.isEmpty ? to : '$from → $to';

  static const String notSorted = 'Not sorted yet';
  static const String addDates = 'Add dates';
  static const String addPeople = 'Add people';
  static const String addStart = 'Add starting city';
  static const String addPlaces = 'Add places';
  static const String noPlaces = 'No places this day';
  static const String cityNotReady = 'City not ready yet';
  static const String overLimit = 'Over the day limit';
  static String placesLine(int n, String? time) => time == null ? '$n ${n == 1 ? 'place' : 'places'}' : '$n ${n == 1 ? 'place' : 'places'} · $time';

  static String twoPlansNight(int day) => 'Two plans for Night $day · keep one';
  static String twoPlansDay(int day) => 'Two plans for Day $day · keep one';
  static const String noStay = 'No stay tonight';
  static String ownStay(String name) => name.trim().isEmpty ? 'Own stay' : 'Own stay · ${name.trim()}';
  static String booked(String name, int? rupees) =>
      rupees == null || rupees <= 0 ? 'Booked · $name' : 'Booked · $name · ${Money.exact(rupees)}';
  static String sameAs(int night, String name) => 'Same as Night $night · $name';
  static const String advanceDue = 'Advance due';
  static const String newPrice = 'New price from host';
  static const String changeAsked = 'Change asked';
  static String askedHosts(int n) => 'Asked $n ${n == 1 ? 'host' : 'hosts'} · waiting';
  static String offer(int? rupees) => rupees == null ? 'Offer from host' : 'Offer · ${Money.exact(rupees)}';
  static String offers(int n) => '$n offers · see replies';
  static const String bookedByYouHost = 'Booked by you · host not confirmed';
  static String sameNotAsked(int night) => 'Same as Night $night · host not asked';
  static String notAsked(String name) => '$name · not asked';
  static String shortlisted(int n) => 'Shortlisted $n · not asked';
  static const String hostFull = 'Host is full';
  static const String noReply = 'No reply';
  static const String holdExpired = 'Hold expired';
  static const String hostNotMe = 'Host said not me';
  static const String hostCancelled = 'Host cancelled';
  static const String youCancelledStay = 'You cancelled · find a stay';
  static const String youDeclinedStay = 'You declined · find a stay';

  static const String noTaxi = 'No taxi this day';
  static String ownTaxi(String name) => name.trim().isEmpty ? 'Own taxi' : 'Own taxi · ${name.trim()}';
  static String taxiConfirmed(String name, int? rupees) =>
      rupees == null || rupees <= 0 ? 'Confirmed · $name' : 'Confirmed · $name · ${Money.exact(rupees)}/day';
  static String askedDrivers(int n) => 'Asked $n ${n == 1 ? 'driver' : 'drivers'} · waiting';
  static String fare(int? rupees) => rupees == null ? 'Fare from driver' : 'Fare ${Money.exact(rupees)}';
  static const String bookedByYouDriver = 'Booked by you · driver not confirmed';
  static String chosenNotAsked(String name) => name.isEmpty ? 'Chosen · not asked' : '$name · not asked';
  static const String driverBusy = 'Driver busy';
  static const String driverOff = 'Driver is off right now';
  static const String noBooking = 'No booking made';
  static const String driverNotMe = 'Driver said not me';
  static const String driverCancelled = 'Driver cancelled';
  static const String youCancelledTaxi = 'You cancelled · find a taxi';
  static const String journeyHint = 'Your journey car brings you in. Taxi for the rest of the day?';

  static String arrangeMyself(String? how) =>
      how == null || how.isEmpty ? 'I will arrange it myself' : 'I will arrange it myself · $how';
  static const String youArrange = 'You arrange it';
  static const String planSaved = 'Plan saved · not asked';
  static const String statusUnknown = 'Offline · status unknown';
  static String carsConfirmed(int n, int rupees) {
    final head = n == 1 ? 'Car confirmed' : '$n cars confirmed';
    return rupees > 0 ? '$head · ${Money.exact(rupees)}' : head;
  }

  static String askedOf(int asked, int cars) => 'Asked $asked of $cars';
  static String allFree(int cars) => cars == 1 ? 'Driver free · book it' : 'All free · book them';
  static String carMissing(int car) => 'Car $car has no driver';
  static String carNoReply(int car) => 'Car $car · no reply';
  static const String driverPaused = 'Driver paused';
  static const String dateMoved = 'Trip date moved · search again';
  static const String leaveMoved = 'Leave time changed · search again';
  static const String startMoved = 'Start changed · search again';
  static String reachHub(String hub) => 'Reach $hub yourself, then the cars';
  static String car(TripCarLine c) => switch (c.state) {
        TripCarState.own => 'Car ${c.car} your own',
        TripCarState.confirmed => 'Car ${c.car} confirmed',
        TripCarState.bookedByYou => 'Car ${c.car} booked by you, driver not confirmed',
        TripCarState.free => 'Car ${c.car} free',
        TripCarState.asked => 'Car ${c.car} waiting for driver',
        TripCarState.notAvailable => c.noReply ? 'Car ${c.car} · no reply' : 'Car ${c.car} has no driver',
        TripCarState.paused => 'Car ${c.car} driver paused',
        TripCarState.notAsked => 'Car ${c.car} not asked',
      };

  static String arriveIn(String city) => 'Arrive in $city';
  static String fromPlace(String from) => 'From $from';
  static String byHow(String how) => 'By $how';
  static const String planGettingThere = 'Plan Getting there';
  static const String planTheMove = 'Plan the move';
  static const String fromCityCentre = 'Route from the city centre';
  static const String confirmedShort = 'Confirmed';
  static String offerReplaces(String host, String old) => 'Offer from $host · replaces $old when confirmed';
  static String askedReplaces(int n, String old) => 'Asked $n ${n == 1 ? 'host' : 'hosts'} · replaces $old when confirmed';
  static String fareReplaces(String driver, String old) => 'Fare from $driver · replaces $old when booked';
  static String askedDriversReplace(int n, String old) =>
      'Asked $n ${n == 1 ? 'driver' : 'drivers'} · replaces $old when booked';
  static const String placesChangedTell = 'Places changed · tell the driver';
  static const String startChangedTell = 'Start changed · tell the driver';
  static String routeFrom(String? stay) => stay == null ? 'Route from your other stay' : 'Route from $stay';
  static String nightStay(int night, String time) => 'Night $night stay · leave about $time';
  static String notConfirmedYet(String name) => '$name · not confirmed yet';
  static const String ownStayNoPin = 'No map pin · route from the city centre';
  static const String ownStayPinned = 'Your own stay';
  static const String startNotSet = 'Start not set';
  static String choseNoStay(int night) => 'You chose No stay on Night $night · route from the city centre';
  static const String stayNotChosen = 'Stay not chosen yet';
  static String bookedElsewhere(String city) => city.isEmpty ? 'Booked elsewhere · dates changed' : 'Booked in $city · dates changed';
  static String checkOutMorning(String? date) => date == null ? 'Check-out morning' : 'Check-out $date morning';
  static String checkOut(String? date) => date == null ? 'Check-out' : 'Check-out $date';
  static String dayEvening(int day, String? date) => date == null ? 'Day $day evening' : 'Day $day evening · $date';
  static String startChanged(String name) => 'Start changed · $name cancelled';
}

class TripWizardRules {
  const TripWizardRules._();

  static const String defaultLeaveTime = '09:00';

  static int _newest(TripEnquiryModel a, TripEnquiryModel b) {
    final x = a.updatedAt ?? a.createdAt;
    final y = b.updatedAt ?? b.createdAt;
    if (x == null || y == null) return 0;
    return y.compareTo(x);
  }

  static List<int> legIndexes(TripPlan p) => p.legs.isEmpty ? const [1] : [for (final l in p.legs) l.index];

  static int dayInLegOf(TripPlan p, int day) {
    final leg = p.legIndexOf(day);
    var i = 0;
    for (final d in p.days) {
      if (d.leg != leg) continue;
      i++;
      if (d.day == day) return i;
    }
    return 1;
  }

  static int? dayOf(TripPlan p, int legIndex, int dayInLeg) {
    var i = 0;
    for (final d in p.days) {
      if (d.leg != legIndex) continue;
      i++;
      if (i == dayInLeg) return d.day;
    }
    return null;
  }

  static int? dayOfKey(TripPlan p, TripStepKey key) {
    if (!key.isDayStep || key.legIndex == null || key.dayInLeg == null) return null;
    return dayOf(p, key.legIndex!, key.dayInLeg!);
  }

  static bool _atHome(TripWizardInput i, TripEnquiryModel e, int day) {
    final home = TripEnquiryRules.homeLegIndex(e, i.plan);
    if (!i.plan.isMultiCity && home != WrongCityInfo.removedCityLeg) return true;
    return home == null || home == i.plan.legIndexOf(day);
  }

  static List<TripEnquiryModel> _nightRowsAll(TripWizardInput i, int day) {
    final date = i.settings.dateOf(day);
    return [
      for (final e in i.enquiries)
        if (!e.isTaxi && (date != null ? e.coversDate(date) : e.day == day)) e,
    ]..sort(_newest);
  }

  static List<TripEnquiryModel> _taxiRowsAll(TripWizardInput i, int day) {
    final date = i.settings.dateOf(day);
    return [
      for (final e in i.enquiries)
        if (e.isTaxi &&
            !e.isSegment &&
            e.context.journeyId == null &&
            (date != null && e.checkIn != null ? e.coversTaxiDate(date) : e.days.contains(day)))
          e,
    ]..sort(_newest);
  }

  static List<TripEnquiryModel> nightRows(TripWizardInput i, int day) =>
      [for (final e in _nightRowsAll(i, day)) if (_atHome(i, e, day)) e];

  static List<TripEnquiryModel> taxiRows(TripWizardInput i, int day) =>
      [for (final e in _taxiRowsAll(i, day)) if (_atHome(i, e, day)) e];

  static TripEnquiryModel? movedBooking(TripWizardInput i, int day, {required bool taxi}) =>
      (taxi ? _taxiRowsAll(i, day) : _nightRowsAll(i, day))
          .where((e) => e.isOpen && e.isBooked && !_atHome(i, e, day))
          .firstOrNull;

  static String _homeCity(TripWizardInput i, TripEnquiryModel e) {
    final k = TripEnquiryRules.homeLegIndex(e, i.plan);
    final name = k != null && k >= 1 ? i.plan.legAt(k)?.cityName : null;
    return name ?? e.context.city;
  }

  static List<TripEnquiryModel> journeyRows(TripWizardInput i, String journeyId) => [
        for (final e in i.enquiries)
          if (e.isTaxi && e.context.journeyId == journeyId) e,
      ];

  static List<TripStepInfo> steps(TripWizardInput i) {
    final p = i.plan;
    final out = <TripStepInfo>[basicsInfo(i), journeyInfo(i, TripStepKey.gettingThere)];
    for (final k in legIndexes(p)) {
      if (k >= 2) out.add(journeyInfo(i, TripStepKey.travel(k)));
      var n = 0;
      for (final d in p.days) {
        if (d.leg != k) continue;
        n++;
        out
          ..add(placesInfo(i, d.day, TripStepKey.places(k, n)))
          ..add(taxiInfo(i, d.day, TripStepKey.taxi(k, n)))
          ..add(stayInfo(i, d.day, TripStepKey.stay(k, n)));
      }
    }
    out.add(journeyInfo(i, TripStepKey.comingBack));
    return out;
  }

  static TripStepInfo? infoOf(TripWizardInput i, TripStepKey key) {
    switch (key.kind) {
      case TripWizardStepKind.basics:
        return basicsInfo(i);
      case TripWizardStepKind.gettingThere:
      case TripWizardStepKind.comingBack:
        return journeyInfo(i, key);
      case TripWizardStepKind.travel:
        final k = key.legIndex;
        return k == null || k < 2 || i.plan.legAt(k) == null ? null : journeyInfo(i, key);
      case TripWizardStepKind.places:
      case TripWizardStepKind.taxi:
      case TripWizardStepKind.stay:
        final day = dayOfKey(i.plan, key);
        if (day == null) return null;
        return switch (key.kind) {
          TripWizardStepKind.places => placesInfo(i, day, key),
          TripWizardStepKind.taxi => taxiInfo(i, day, key),
          _ => stayInfo(i, day, key),
        };
    }
  }

  static TripStepState stayState(TripWizardInput i, int day) =>
      stayInfo(i, day, TripStepKey.stay(i.plan.legIndexOf(day), dayInLegOf(i.plan, day))).state;

  static TripStepState taxiState(TripWizardInput i, int day) =>
      taxiInfo(i, day, TripStepKey.taxi(i.plan.legIndexOf(day), dayInLegOf(i.plan, day))).state;

  static TripStepState placesState(TripWizardInput i, int day) =>
      placesInfo(i, day, TripStepKey.places(i.plan.legIndexOf(day), dayInLegOf(i.plan, day))).state;

  static TripStepState basicsState(TripWizardInput i) => basicsInfo(i).state;

  static TripStepState journeyStepState(TripWizardInput i, TripStepRole role) =>
      journeyInfo(i, TripStepKey.ofRole(role)).state;

  static TripStepState travelState(TripWizardInput i, int legIndex) =>
      journeyInfo(i, TripStepKey.travel(legIndex)).state;

  static ({int total, int counted, int decided, int waitingForReply, int needYou, int attention, int percent}) progress(
      List<TripStepInfo> s) {
    final counted = s.where((x) => x.counted).length;
    return (
      total: s.length,
      counted: counted,
      decided: s.where((x) => x.decided).length,
      waitingForReply: s.where((x) => x.waitingForReply).length,
      needYou: s.where((x) => x.needsYou).length,
      attention: s.where((x) => x.state == TripStepState.attention).length,
      percent: s.isEmpty ? 0 : counted * 100 ~/ s.length,
    );
  }

  static TripStepInfo? nextStep(List<TripStepInfo> s) {
    for (final x in s) {
      if (x.state == TripStepState.attention || x.needsYou) return x;
    }
    for (final x in s) {
      if (x.state == TripStepState.todo) return x;
    }
    for (final x in s) {
      if (x.state == TripStepState.waiting) return x;
    }
    return null;
  }

  static int runningCost(List<TripStepInfo> s) =>
      s.fold(0, (sum, x) => x.state == TripStepState.done ? sum + (x.agreedRupees ?? 0) : sum);

  static List<TripStepInfo> wishlist(List<TripStepInfo> s) => [for (final x in s) if (!x.counted) x];

  static DateTime? comingBackDate(TripSettings settings, TripSteps steps, int dayCount) =>
      TripStepRules.expectedDate(TripStepRole.comingBack, steps.comingBack, settings, dayCount);

  static bool hasCityPoint(TripCityLeg? l) => l != null && l.hasPoint;

  static TripStepInfo basicsInfo(TripWizardInput i) {
    final s = i.settings;
    final start = i.steps.startFrom;
    final missing = s.startDate == null
        ? TripWizardCopy.addDates
        : s.adults == null
            ? TripWizardCopy.addPeople
            : start == null
                ? TripWizardCopy.addStart
                : null;
    if (missing != null) {
      return TripStepInfo(
        key: TripStepKey.basics,
        state: TripStepState.todo,
        title: TripWizardCopy.basics,
        line: missing,
      );
    }
    final dayCount = i.dayCount;
    final end = s.endDate(dayCount);
    final dates = end == null ? TripFormat.dayMonth(s.startDate!) : TripFormat.dayMonthRange(s.startDate!, end);
    return TripStepInfo(
      key: TripStepKey.basics,
      state: TripStepState.done,
      title: TripWizardCopy.basics,
      line: [dates, ?s.peopleSummary, start!.name].join(' · '),
    );
  }

  static TripStepInfo placesInfo(TripWizardInput i, int day, TripStepKey key) {
    final d = i.plan.dayAt(day);
    final leg = i.plan.legIndexOf(day);
    final title = TripWizardCopy.places(day);
    final spots = d?.spots ?? const <TripSpotRef>[];
    if (spots.isEmpty && (d?.restDay ?? false)) {
      return TripStepInfo(
        key: key,
        day: day,
        legIndex: leg,
        state: TripStepState.skipped,
        title: title,
        line: TripWizardCopy.noPlaces,
      );
    }
    if (spots.isNotEmpty) {
      final minutes = i.dayMinutes?.call(day) ?? d!.visitMinutes;
      return TripStepInfo(
        key: key,
        day: day,
        legIndex: leg,
        state: TripStepState.done,
        title: title,
        line: TripWizardCopy.placesLine(spots.length, minutes > 0 ? TripFormat.duration(minutes) : null),
        note: (i.overLimit?.call(day) ?? false) ? TripWizardCopy.overLimit : null,
      );
    }
    return TripStepInfo(
      key: key,
      day: day,
      legIndex: leg,
      state: TripStepState.todo,
      title: title,
      line: i.notReadyLegs.contains(leg) ? TripWizardCopy.cityNotReady : TripWizardCopy.addPlaces,
    );
  }

  static int? _nightShare(TripEnquiryModel e, TripSettings settings, int day) {
    final total = e.agreedTotal;
    if (total == null) return null;
    final nights = e.nights < 1 ? 1 : e.nights;
    final ci = e.checkIn;
    final date = settings.dateOf(day);
    var k = 0;
    if (ci != null && date != null) {
      k = DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(ci.year, ci.month, ci.day)).inDays;
    }
    if (k < 0 || k >= nights) k = 0;
    return TripMoney.shareOf(total, nights, k);
  }

  static String _stayProblem(TripEnquiryModel e) => switch (e.status) {
        TripEnquiryStatuses.notAvailable => TripWizardCopy.hostFull,
        TripEnquiryStatuses.expired => TripWizardCopy.noReply,
        TripEnquiryStatuses.cancelledByOwner => TripWizardCopy.hostCancelled,
        _ => e.failReason == TripFailReasons.holdExpired ? TripWizardCopy.holdExpired : TripWizardCopy.hostNotMe,
      };

  static String _taxiProblem(TripEnquiryModel e) => switch (e.status) {
        TripEnquiryStatuses.notAvailable =>
          e.failReason == TripFailReasons.driverPaused ? TripWizardCopy.driverOff : TripWizardCopy.driverBusy,
        TripEnquiryStatuses.expired => TripWizardCopy.noBooking,
        TripEnquiryStatuses.cancelledByOwner => TripWizardCopy.driverCancelled,
        _ => TripWizardCopy.driverNotMe,
      };

  static TripEnquiryModel? _lastClosed(TripWizardInput i, List<TripEnquiryModel> rows) {
    for (final e in rows) {
      if (e.isOpen || e.status == TripEnquiryStatuses.closed || i.isDismissed(e.id)) continue;
      return e;
    }
    return null;
  }

  static TripStepInfo stayInfo(TripWizardInput i, int day, TripStepKey key) {
    final d = i.plan.dayAt(day);
    final stay = d?.stay;
    final leg = i.plan.legIndexOf(day);
    final title = TripWizardCopy.stay(day);
    final rows = nightRows(i, day);
    final live = [for (final e in rows) if (e.isOpen) e];

    TripStepInfo info(TripStepState state, String line,
            {String? note, int? rupees, bool needsYou = false, String? enquiryId}) =>
        TripStepInfo(
          key: key,
          day: day,
          legIndex: leg,
          state: state,
          title: title,
          line: line,
          note: note,
          agreedRupees: rupees,
          needsYou: needsYou,
          enquiryId: enquiryId,
        );

    final elsewhere = movedBooking(i, day, taxi: false);
    if (elsewhere != null && !live.any((e) => e.status == TripEnquiryStatuses.confirmedByBoth)) {
      return info(TripStepState.attention, TripWizardCopy.bookedElsewhere(_homeCity(i, elsewhere)),
          needsYou: true, enquiryId: elsewhere.id);
    }

    if (stay != null && (stay.isSkipped || stay.isOwn)) {
      final booked = live.where((e) => TripEnquiryStatuses.confirmed.contains(e.status)).firstOrNull;
      if (booked != null) {
        return info(TripStepState.attention, TripWizardCopy.twoPlansNight(day), needsYou: true, enquiryId: booked.id);
      }
      if (stay.isSkipped) return info(TripStepState.skipped, TripWizardCopy.noStay, note: stay.note);
      return info(TripStepState.own, TripWizardCopy.ownStay(stay.name), note: stay.note);
    }

    final both = live.where((e) => e.status == TripEnquiryStatuses.confirmedByBoth).firstOrNull;
    if (both != null) {
      final share = _nightShare(both, i.settings, day);
      final same = stay?.sameAsDay;
      final line = same != null && stay!.stayId == both.listingId
          ? TripWizardCopy.sameAs(same, both.listingName)
          : TripWizardCopy.booked(both.listingName, share);
      final advanceDue = both.advance.isPending;
      final note = both.advance.isOpenRequest
          ? TripWizardCopy.advanceDue
          : both.hasPendingRevised
              ? TripWizardCopy.newPrice
              : both.hasPendingChange
                  ? TripWizardCopy.changeAsked
                  : null;
      final others = [for (final e in live) if (e.id != both.id && e.status != TripEnquiryStatuses.confirmedByBoth) e];
      final offer = others.where((e) => e.status == TripEnquiryStatuses.offered).firstOrNull;
      final replace = others.isEmpty
          ? null
          : offer != null
              ? TripWizardCopy.offerReplaces(offer.listingName, both.listingName)
              : TripWizardCopy.askedReplaces(others.length, both.listingName);
      return info(TripStepState.done, line,
          note: [?note, ?replace].join(' · ').ifEmptyNull,
          rupees: share,
          needsYou: advanceDue || both.hasPendingRevised || offer != null,
          enquiryId: both.id);
    }

    if (live.isNotEmpty) {
      final byYou = live.where((e) => e.status == TripEnquiryStatuses.confirmedByTraveller).firstOrNull;
      if (byYou != null) return info(TripStepState.waiting, TripWizardCopy.bookedByYouHost, enquiryId: byYou.id);
      final offered = [for (final e in live) if (e.status == TripEnquiryStatuses.offered) e];
      if (offered.length == 1) {
        final e = offered.single;
        return info(TripStepState.waiting, TripWizardCopy.offer(e.openOffer?.total ?? e.agreedTotal),
            needsYou: true, enquiryId: e.id);
      }
      if (offered.length > 1) {
        return info(TripStepState.waiting, TripWizardCopy.offers(offered.length), needsYou: true, enquiryId: offered.first.id);
      }
      return info(TripStepState.waiting, TripWizardCopy.askedHosts(live.length), enquiryId: live.first.id);
    }

    final same = stay?.sameAsDay;
    if (stay != null && same != null) {
      return info(TripStepState.waiting, TripWizardCopy.sameNotAsked(same), needsYou: true);
    }
    if (stay != null && stay.hasListing) {
      return info(TripStepState.waiting, TripWizardCopy.notAsked(stay.name), needsYou: true);
    }
    final askedIds = {for (final e in rows) e.listingId};
    final fresh = (d?.stayShortlist ?? const <TripStayShortlistItem>[]).where((s) => !askedIds.contains(s.stayId)).length;
    if (fresh > 0) return info(TripStepState.waiting, TripWizardCopy.shortlisted(fresh), needsYou: true);

    final last = _lastClosed(i, rows);
    if (last != null && last.isProblem) {
      return info(TripStepState.attention, _stayProblem(last), enquiryId: last.id);
    }
    final note = last == null
        ? null
        : last.status == TripEnquiryStatuses.declined
            ? TripWizardCopy.youDeclinedStay
            : last.status == TripEnquiryStatuses.cancelledByTraveller
                ? TripWizardCopy.youCancelledStay
                : null;
    return info(TripStepState.todo, TripWizardCopy.notSorted, note: note);
  }

  static int? _taxiShare(TripEnquiryModel e, TripSettings settings, int day) {
    final fare = e.taxi?.agreedFare;
    if (fare == null) return null;
    final date = settings.dateOf(day);
    final dates = e.taxiDates;
    var k = date != null && dates.isNotEmpty ? dates.indexOf(DateTime(date.year, date.month, date.day)) : e.days.indexOf(day);
    final parts = dates.isNotEmpty ? dates.length : (e.days.isEmpty ? 1 : e.days.length);
    if (k < 0) k = 0;
    return TripMoney.shareOf(fare, parts, k);
  }

  // Live taxi rows whose driver was told an older plan: the day's places or its start (last night's stay) changed since the ask.
  static String dayStartKey(TripPlan p, int day) {
    if (day <= 1 || p.dayAt(day - 1) == null || p.legIndexOf(day - 1) != p.legIndexOf(day)) return 'arrival';
    final stay = p.dayAt(day - 1)?.stay;
    if (stay == null) return 'none';
    if (stay.isSkipped) return 'skipped';
    if (stay.isOwn) return 'own';
    return stay.stayId.isEmpty ? 'none' : 'stay:${stay.stayId.toLowerCase()}';
  }

  static Map<String, TripDriverUpdate> driverUpdates(TripWizardInput i, int day, List<TripEnquiryModel> rows) {
    final p = i.plan;
    final names = [for (final s in p.dayAt(day)?.spots ?? const <TripSpotRef>[]) if (s.name.isNotEmpty) s.name];
    final date = i.settings.dateOf(day);
    final start = dayStartKey(p, day);
    final out = <String, TripDriverUpdate>{};
    for (final e in rows) {
      if (!e.isOpen || e.isSegment) continue;
      TripContextDay? sent;
      for (final c in e.context.days) {
        final cd = c.date;
        if ((date != null && cd != null) ? _sameDay(cd, date) : c.day == day) {
          sent = c;
          break;
        }
      }
      if (sent == null) continue;
      if (!listEquals(sent.spots, names)) {
        out[e.id] = TripDriverUpdate.places;
      } else if (sent.start != null && sent.start != start) {
        out[e.id] = TripDriverUpdate.start;
      }
    }
    return out;
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static TripStepInfo taxiInfo(TripWizardInput i, int day, TripStepKey key) {
    final d = i.plan.dayAt(day);
    final taxi = d?.taxi;
    final leg = i.plan.legIndexOf(day);
    final title = TripWizardCopy.taxi(day);
    final rows = taxiRows(i, day);
    final live = [for (final e in rows) if (e.isOpen) e];

    TripStepInfo info(TripStepState state, String line,
            {String? note, int? rupees, bool needsYou = false, String? enquiryId}) =>
        TripStepInfo(
          key: key,
          day: day,
          legIndex: leg,
          state: state,
          title: title,
          line: line,
          note: note,
          agreedRupees: rupees,
          needsYou: needsYou,
          enquiryId: enquiryId,
        );

    final elsewhere = movedBooking(i, day, taxi: true);
    if (elsewhere != null && !live.any((e) => e.status == TripEnquiryStatuses.confirmedByBoth)) {
      return info(TripStepState.attention, TripWizardCopy.bookedElsewhere(_homeCity(i, elsewhere)),
          needsYou: true, enquiryId: elsewhere.id);
    }

    if (taxi != null && (taxi.isSkipped || taxi.isOwn)) {
      final booked = live
          .where((e) =>
              e.status == TripEnquiryStatuses.bookedByTraveller || e.status == TripEnquiryStatuses.confirmedByBoth)
          .firstOrNull;
      if (booked != null) {
        return info(TripStepState.attention, TripWizardCopy.twoPlansDay(day), needsYou: true, enquiryId: booked.id);
      }
      if (taxi.isSkipped) return info(TripStepState.skipped, TripWizardCopy.noTaxi, note: taxi.note);
      return info(TripStepState.own, TripWizardCopy.ownTaxi(taxi.name), note: taxi.note);
    }

    final tell = switch (driverUpdates(i, day, live).values.fold<TripDriverUpdate>(
        TripDriverUpdate.none, (a, b) => b.index > a.index ? b : a)) {
      TripDriverUpdate.places => TripWizardCopy.placesChangedTell,
      TripDriverUpdate.start => TripWizardCopy.startChangedTell,
      TripDriverUpdate.none => null,
    };

    final both = live.where((e) => e.status == TripEnquiryStatuses.confirmedByBoth).firstOrNull;
    if (both != null) {
      final share = _taxiShare(both, i.settings, day);
      final others = [for (final e in live) if (e.id != both.id && e.status != TripEnquiryStatuses.confirmedByBoth) e];
      final fare = others.where((e) => e.status == TripEnquiryStatuses.fareSent).firstOrNull;
      final replace = others.isEmpty
          ? null
          : fare != null
              ? TripWizardCopy.fareReplaces(fare.listingName, both.listingName)
              : TripWizardCopy.askedDriversReplace(others.length, both.listingName);
      return info(TripStepState.done, TripWizardCopy.taxiConfirmed(both.listingName, share),
          rupees: share,
          enquiryId: both.id,
          needsYou: fare != null,
          note: [?tell, ?replace].join(' · ').ifEmptyNull);
    }

    if (live.isNotEmpty) {
      final byYou = live.where((e) => e.status == TripEnquiryStatuses.bookedByTraveller).firstOrNull;
      if (byYou != null) {
        return info(TripStepState.waiting, TripWizardCopy.bookedByYouDriver, enquiryId: byYou.id, note: tell);
      }
      final fare = live.where((e) => e.status == TripEnquiryStatuses.fareSent).firstOrNull;
      if (fare != null) {
        return info(TripStepState.waiting, TripWizardCopy.fare(fare.taxi?.driverFare ?? fare.taxi?.agreedFare),
            needsYou: true, enquiryId: fare.id, note: tell);
      }
      return info(TripStepState.waiting, TripWizardCopy.askedDrivers(live.length), enquiryId: live.first.id, note: tell);
    }

    if (taxi != null && (taxi.taxiId.isNotEmpty || taxi.isBooked)) {
      return info(TripStepState.waiting, TripWizardCopy.chosenNotAsked(taxi.name), needsYou: true);
    }
    final askedIds = {for (final e in rows) e.listingId};
    final fresh = (d?.taxiShortlist ?? const <TripTaxiShortlistItem>[]).where((s) => !askedIds.contains(s.taxiId)).length;
    if (fresh > 0) return info(TripStepState.waiting, TripWizardCopy.shortlisted(fresh), needsYou: true);

    final last = _lastClosed(i, rows);
    if (last != null && last.isProblem) {
      return info(TripStepState.attention, _taxiProblem(last), enquiryId: last.id);
    }
    final note = last != null && last.status == TripEnquiryStatuses.cancelledByTraveller
        ? TripWizardCopy.youCancelledTaxi
        : null;
    return info(TripStepState.todo, TripWizardCopy.notSorted, note: note);
  }

  static TripJourney? _journeyById(TripWizardInput i, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final j in i.journeys) {
      if (j.id == id) return j;
    }
    return null;
  }

  static String _carsLine(List<TripCarLine> cars) => cars.map(TripWizardCopy.car).join(' · ');

  static String? _howOf(TripTravel t) => _howText(t.how, t.note, t.ownName);

  static String? _howText(TripTravelHow? h, String? note, String? ownName) {
    final how = switch (h) {
      TripTravelHow.car => 'by car',
      TripTravelHow.bus => 'by bus',
      TripTravelHow.train => 'by train',
      _ => null,
    };
    return how ?? note ?? ownName;
  }

  static TripStepInfo journeyInfo(TripWizardInput i, TripStepKey key) {
    final p = i.plan;
    final role = key.stepRole;
    final k = key.legIndex;
    final String title;
    if (role == TripStepRole.gettingThere) {
      title = TripWizardCopy.gettingThere;
    } else if (role == TripStepRole.comingBack) {
      title = TripWizardCopy.comingBack;
    } else {
      title = TripWizardCopy.travel(p.legAt(k! - 1)?.cityName ?? '', p.legAt(k)?.cityName ?? '');
    }
    final legIndex = role == null ? k : null;

    TripStepInfo info(TripStepState state, String line,
            {int? rupees, bool needsYou = false, List<TripCarLine> cars = const [], String? note}) =>
        TripStepInfo(
          key: key,
          legIndex: legIndex,
          day: role == null && k != null ? p.legStart(k) : null,
          state: state,
          title: title,
          line: line,
          note: note,
          agreedRupees: rupees,
          needsYou: needsYou,
          cars: cars,
        );

    final TripJourney? journey;
    final DateTime? travelDate;
    final List<int> ownCars;
    var startMoved = false;
    var cityMoved = false;
    var leaveMoved = false;
    final TripTravelState state;
    if (role != null) {
      final step = i.steps.of(role);
      if (step.status == TripStepStatus.own) {
        return info(TripStepState.own, TripWizardCopy.arrangeMyself(_howText(step.how, step.note, step.ownName)));
      }
      if (step.status == TripStepStatus.skipped) return info(TripStepState.skipped, TripWizardCopy.youArrange);
      if (!step.hasJourney) return info(TripStepState.todo, TripWizardCopy.notSorted);
      journey = _journeyById(i, step.journeyId);
      if (journey == null && !i.journeysKnown) return info(TripStepState.waiting, TripWizardCopy.statusUnknown);
      if (journey == null) return info(TripStepState.todo, TripWizardCopy.notSorted);
      travelDate = TripStepRules.expectedDate(role, step, i.settings, i.dayCount);
      leaveMoved = role == TripStepRole.comingBack && step.date == null && TripStepRules.leaveMoved(step, journey.date, i.settings, i.dayCount);
      ownCars = step.ownCars;
      final city = role == TripStepRole.gettingThere ? p.legAt(1) : p.legAt(p.legCount);
      final cityLat = hasCityPoint(city) ? city!.latitude : null;
      final cityLon = hasCityPoint(city) ? city!.longitude : null;
      cityMoved = TripStepRules.cityChanged(role, journey, cityLat, cityLon);
      startMoved = cityMoved || TripStepRules.startChanged(role, i.steps.endOf(role), journey);
      state = TripTravelRules.stateOf(
        role: TripJourneyRole.of(role),
        step: step,
        journey: journey,
        journeyRows: journeyRows(i, journey.id),
        travelDate: travelDate,
      );
    } else {
      final arrival = p.legAt(k!)?.arrival;
      if (arrival == null) {
        final hub = i.travelGaps[k];
        return info(TripStepState.todo,
            i.travelGaps.containsKey(k) && hub != null && hub.isNotEmpty ? TripWizardCopy.reachHub(hub) : TripWizardCopy.notSorted);
      }
      if (arrival.isOwn) return info(TripStepState.own, TripWizardCopy.arrangeMyself(_howOf(arrival)));
      journey = _journeyById(i, arrival.journeyId);
      if (journey == null && !i.journeysKnown) return info(TripStepState.waiting, TripWizardCopy.statusUnknown);
      if (journey == null) return info(TripStepState.waiting, TripWizardCopy.planSaved, needsYou: true);
      travelDate = i.settings.dateOf(p.legStart(k));
      ownCars = arrival.ownCars;
      state = TripTravelRules.stateOf(
        role: TripJourneyRole.segment,
        arrival: arrival,
        journey: journey,
        journeyRows: journeyRows(i, journey.id),
        travelDate: travelDate,
      );
    }

    final cars = TripTravelRules.carLines(journey, journeyRows(i, journey.id), ownCars);
    final perCar = cars.any((c) =>
        c.state == TripCarState.confirmed || c.state == TripCarState.bookedByYou || c.state == TripCarState.own);
    final anyFree = cars.any((c) => c.state == TripCarState.free || c.state == TripCarState.notAsked);
    if (startMoved && state != TripTravelState.own && (state != TripTravelState.confirmed || cityMoved)) {
      return info(TripStepState.attention, TripWizardCopy.startMoved, cars: cars);
    }
    switch (state) {
      case TripTravelState.own:
        if (cars.isNotEmpty && cars.every((c) => c.state == TripCarState.own)) {
          return info(TripStepState.own, _carsLine(cars), cars: cars);
        }
        return info(TripStepState.own, TripWizardCopy.arrangeMyself(null));
      case TripTravelState.confirmed:
        final rupees = cars.fold<int>(0, (s, c) => c.state == TripCarState.confirmed ? s + (c.agreedFare ?? 0) : s);
        final confirmedCars = cars.where((c) => c.state == TripCarState.confirmed).length;
        final line = cars.any((c) => c.state == TripCarState.own) ? _carsLine(cars) : TripWizardCopy.carsConfirmed(confirmedCars, rupees);
        return info(TripStepState.done, line, rupees: rupees, cars: cars);
      case TripTravelState.saved:
        return info(TripStepState.waiting, perCar ? _carsLine(cars) : TripWizardCopy.planSaved,
            needsYou: true, cars: cars);
      case TripTravelState.free:
        return info(TripStepState.waiting, perCar ? _carsLine(cars) : TripWizardCopy.allFree(cars.length),
            needsYou: true, cars: cars);
      case TripTravelState.asked:
        final asked = cars.where((c) => c.state != TripCarState.notAsked && c.state != TripCarState.own).length;
        return info(TripStepState.waiting, perCar ? _carsLine(cars) : TripWizardCopy.askedOf(asked, cars.length),
            needsYou: anyFree, cars: cars);
      case TripTravelState.partlyBooked:
      case TripTravelState.booked:
        return info(TripStepState.waiting, _carsLine(cars), needsYou: anyFree, cars: cars);
      case TripTravelState.carMissing:
        final missing = cars.where((c) => c.state == TripCarState.notAvailable).firstOrNull;
        return info(
            TripStepState.attention,
            missing != null && missing.noReply ? TripWizardCopy.carNoReply(missing.car) : TripWizardCopy.carMissing(missing?.car ?? 1),
            cars: cars);
      case TripTravelState.driverUnavailable:
        return info(TripStepState.attention, TripWizardCopy.driverPaused, cars: cars);
      case TripTravelState.dateChanged:
        return info(TripStepState.attention, leaveMoved ? TripWizardCopy.leaveMoved : TripWizardCopy.dateMoved, cars: cars);
      case TripTravelState.notPlanned:
      case TripTravelState.gap:
        return info(TripStepState.todo, TripWizardCopy.notSorted, cars: cars);
    }
  }

  static String? _dayMonth(DateTime? d) => d == null ? null : TripFormat.dayMonth(d);

  static TripStartInfo _arrivalStart(TripWizardInput i, int legIndex) {
    final p = i.plan;
    final city = p.legAt(legIndex)?.cityName ?? p.cityName;
    final heading = TripWizardCopy.arriveIn(city);
    if (legIndex <= 1) {
      final step = i.steps.gettingThere;
      if (step.status == TripStepStatus.own || step.status == TripStepStatus.skipped) {
        final how = _howText(step.how, step.note, step.ownName);
        return TripStartInfo(
          heading: heading,
          line: how == null || how.isEmpty ? TripWizardCopy.fromCityCentre : TripWizardCopy.byHow(how.replaceFirst('by ', '')),
          kind: TripStartKind.arrival,
        );
      }
      final j = step.hasJourney ? _journeyById(i, step.journeyId) : null;
      return TripStartInfo(
        heading: heading,
        line: j != null ? TripWizardCopy.fromPlace(j.fromName) : TripWizardCopy.planGettingThere,
        kind: TripStartKind.arrival,
      );
    }
    final a = p.legAt(legIndex)?.arrival;
    final String line;
    if (a == null) {
      line = TripWizardCopy.planTheMove;
    } else if (a.isOwn) {
      final how = _howOf(a);
      line = how == null ? TripWizardCopy.fromPlace(a.fromName) : TripWizardCopy.byHow(how.replaceFirst('by ', ''));
    } else {
      final j = _journeyById(i, a.journeyId);
      line = TripWizardCopy.fromPlace(j?.fromName ?? a.fromName);
    }
    return TripStartInfo(heading: heading, line: line, kind: TripStartKind.arrival);
  }

  static TripStartInfo nightStartOf(TripWizardInput i, int night) => _nightStart(i, night);

  // Default taxi pickup of day d: last night's stay in the same city (same rule as the server's TripDayStart.PlaceOf).
  static String? pickupPlaceOf(TripPlan p, int day) {
    if (day <= 1 || p.dayAt(day - 1) == null || p.legIndexOf(day - 1) != p.legIndexOf(day)) return null;
    final stay = p.dayAt(day - 1)?.stay;
    if (stay == null || stay.isSkipped) return null;
    final name = stay.name.trim();
    if (name.isEmpty) return null;
    return name.length > TripConstants.pickupPlaceMax ? name.substring(0, TripConstants.pickupPlaceMax).trim() : name;
  }

  static TripStartInfo _nightStart(TripWizardInput i, int night) {
    final p = i.plan;
    final stay = p.dayAt(night)?.stay;
    final point = stay == null ? null : TripStayBase.pointOf(p, stay);
    if (stay != null && stay.isSkipped) {
      return TripStartInfo(
        heading: TripWizardCopy.startNotSet,
        line: TripWizardCopy.choseNoStay(night),
        kind: TripStartKind.noStay,
      );
    }
    if (stay != null && stay.isOwn) {
      return TripStartInfo(
        heading: stay.name.trim().isEmpty ? TripWizardCopy.ownStayPinned : stay.name.trim(),
        line: point == null ? TripWizardCopy.ownStayNoPin : TripWizardCopy.ownStayPinned,
        point: point,
        kind: TripStartKind.ownStay,
      );
    }
    final night0 = stayInfo(i, night, TripStepKey.stay(p.legIndexOf(night), dayInLegOf(p, night)));
    final rows = nightRows(i, night);
    final row = rows.where((e) => e.isOpen && TripEnquiryStatuses.confirmed.contains(e.status)).firstOrNull;
    final name = row?.listingName ?? (stay != null && stay.hasListing ? stay.name : null);
    if (night0.state == TripStepState.done && name != null) {
      final time = TripFormat.time12(i.settings.pickupTime ?? defaultLeaveTime);
      return TripStartInfo(
        heading: name,
        line: TripWizardCopy.nightStay(night, time),
        point: point,
        kind: TripStartKind.stay,
      );
    }
    if (name != null) {
      return TripStartInfo(
        heading: TripWizardCopy.notConfirmedYet(name),
        line: point == null ? TripWizardCopy.fromCityCentre : TripWizardCopy.nightStay(night, TripFormat.time12(i.settings.pickupTime ?? defaultLeaveTime)),
        point: point,
        kind: TripStartKind.stayUnconfirmed,
      );
    }
    return const TripStartInfo(
      heading: TripWizardCopy.stayNotChosen,
      line: TripWizardCopy.fromCityCentre,
      kind: TripStartKind.notChosen,
    );
  }

  static TripStartInfo startOf(TripWizardInput i, int day) {
    final p = i.plan;
    final leg = p.legIndexOf(day);
    if (day <= 1 || p.dayAt(day - 1) == null || p.legIndexOf(day - 1) != leg) return _arrivalStart(i, leg);
    return _plannerRoute(p, day, leg, _nightStart(i, day - 1));
  }

  // The day route starts at last night's stay (TripStayBase.dayEnds); say so when the planner starts elsewhere.
  static TripStartInfo _plannerRoute(TripPlan p, int day, int leg, TripStartInfo s) {
    final from = TripStayBase.dayEnds(p, day).start;
    final point = s.point;
    if (from == null) return point == null ? s : s.withRoute(routeNote: TripWizardCopy.fromCityCentre);
    if (point != null && TripStayBase.same(point, from)) return s;
    final route = TripWizardCopy.routeFrom(TripStayBase.nameOf(p, leg, from));
    return point == null ? s.withRoute(line: route) : s.withRoute(routeNote: route);
  }

  static TripStartInfo comingBackStart(TripWizardInput i) {
    final p = i.plan;
    final n = p.days.length;
    final city = p.legAt(p.legCount)?.cityName ?? p.cityName;
    final date = _dayMonth(comingBackDate(i.settings, i.steps, n));
    if (i.steps.comingBack.leaveOnOrDefault == TripLeaveOn.lastDayEvening) {
      return TripStartInfo(
        heading: TripWizardCopy.fromPlace(city),
        line: TripWizardCopy.dayEvening(n, date),
        kind: TripStartKind.checkOut,
      );
    }
    final night = n < 1 ? null : _nightStart(i, n);
    if (night == null || night.kind == TripStartKind.notChosen || night.kind == TripStartKind.noStay) {
      return TripStartInfo(heading: TripWizardCopy.fromPlace(city), line: TripWizardCopy.checkOut(date), kind: TripStartKind.checkOut);
    }
    return TripStartInfo(
      heading: night.heading,
      line: TripWizardCopy.checkOutMorning(date),
      point: night.point,
      kind: night.kind,
    );
  }
}
