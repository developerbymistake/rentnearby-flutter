import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';

enum TripTravelState {
  notPlanned,
  gap,
  own,
  saved,
  asked,
  free,
  partlyBooked,
  booked,
  confirmed,
  dateChanged,
  carMissing,
  driverUnavailable;

  static TripTravelState? parse(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return null;
  }
}

enum TripJourneyRole {
  gettingThere,
  comingBack,
  segment;

  static TripJourneyRole of(TripStepRole r) => r == TripStepRole.gettingThere ? gettingThere : comingBack;

  static TripJourneyRole? parse(Object? wire) {
    for (final r in values) {
      if (r.name == wire) return r;
    }
    return null;
  }

  TripStepRole? get stepRole => switch (this) {
        gettingThere => TripStepRole.gettingThere,
        comingBack => TripStepRole.comingBack,
        segment => null,
      };
}

enum TripCarState { notAsked, asked, free, bookedByYou, confirmed, own, notAvailable, paused }

class TripCarLine {
  final int car;
  final String driverName;
  final TripCarState state;
  final int? agreedFare;
  final bool noReply;

  const TripCarLine({required this.car, this.driverName = '', required this.state, this.agreedFare, this.noReply = false});

  bool get settled => state == TripCarState.confirmed || state == TripCarState.own;
}

enum TravelFindBlock { none, noDates, tooFarAhead, taxiOff, readOnly, offline }

enum TripLinkResult { saved, notSaved, needsConfirm }

class TravelImpact {
  final int openRows;
  final int bookedRows;
  final int cars;

  const TravelImpact({this.openRows = 0, this.bookedRows = 0, this.cars = 0});

  bool get hasBooked => bookedRows > 0;

  bool get isEmpty => openRows == 0 && bookedRows == 0;
}

class TripTravelRules {
  static const String freeStatus = 'Free';
  static const String notFreeStatus = 'NotFree';
  static const String _free = freeStatus;
  static const String _notFree = notFreeStatus;

  static const List<String> redStatuses = [
    'NotAvailable',
    'Expired',
    'Declined',
    'Failed',
    'CancelledByOwner',
    'CancelledByTraveller',
  ];

  static const List<String> bookedStatuses = [
    TripEnquiryStatuses.bookedByTraveller,
    TripEnquiryStatuses.confirmedByBoth,
  ];

  static bool isLive(TripEnquiryModel e) => e.status != TripEnquiryStatuses.closed;

  static bool isRedRow(TripEnquiryModel e) => redStatuses.contains(e.status);

  static bool _byTraveller(TripEnquiryModel e) =>
      e.status == TripEnquiryStatuses.cancelledByTraveller || e.status == TripEnquiryStatuses.declined;

  static List<TripEnquiryModel> liveRowsOf(String journeyId, Iterable<TripEnquiryModel> rows) => [
        for (final e in rows)
          if (e.isSegment && isLive(e) && e.context.journeyId == journeyId) e,
      ];

  static List<TripEnquiryModel> _carRows(int car, List<TripEnquiryModel> rows) => [
        for (final e in rows)
          if (isLive(e) && e.context.journeyLegIndex == car) e,
      ];

  static bool carBooked(TripJourney j, int car, List<TripEnquiryModel> rows) =>
      _carRows(car, rows).any((e) => bookedStatuses.contains(e.status));

  static bool carConfirmed(TripJourney j, int car, List<TripEnquiryModel> rows) =>
      _carRows(car, rows).any((e) => e.status == TripEnquiryStatuses.confirmedByBoth);

  static List<TripEnquiryModel> _driverRows(TripJourneyLeg leg, int car, List<TripEnquiryModel> rows) => _carRows(car, rows)
      .where((e) => !_byTraveller(e) && (leg.taxiId == null || e.listingId == leg.taxiId))
      .toList();

  static bool carMissing(TripJourney j, int car, List<TripEnquiryModel> rows) {
    if (carBooked(j, car, rows)) return false;
    final leg = _leg(j, car);
    if (leg == null) return false;
    if (leg.lastKnownStatus == _notFree) return true;
    final mine = _driverRows(leg, car, rows);
    return leg.isAsked && mine.isNotEmpty && mine.every(isRedRow);
  }

  static bool carNoReply(TripJourney j, int car, List<TripEnquiryModel> rows) {
    if (!carMissing(j, car, rows)) return false;
    final leg = _leg(j, car)!;
    return leg.lastKnownStatus != _notFree &&
        _driverRows(leg, car, rows).every((e) => e.status == TripEnquiryStatuses.expired);
  }

  static TripEnquiryModel? carBooking(int car, List<TripEnquiryModel> rows) {
    TripEnquiryModel? best;
    for (final e in _carRows(car, rows)) {
      if (!bookedStatuses.contains(e.status)) continue;
      if (best == null ||
          (e.status == TripEnquiryStatuses.confirmedByBoth && best.status != TripEnquiryStatuses.confirmedByBoth)) {
        best = e;
        continue;
      }
      final a = e.updatedAt ?? e.createdAt;
      final b = best.updatedAt ?? best.createdAt;
      if (e.status == best.status && a != null && b != null && a.isAfter(b)) best = e;
    }
    return best;
  }

  static TripJourneyLeg? _leg(TripJourney j, int car) {
    for (final l in j.legs) {
      if (l.legIndex == car) return l;
    }
    return null;
  }

  static bool _answered(TripJourneyLeg l) => l.lastKnownStatus == _free || l.lastKnownStatus == _notFree;

  static int answeredCount(TripJourney j) => j.legs.where((l) => l.isAsked && _answered(l)).length;

  static int askedCount(TripJourney j) => j.legs.where((l) => l.isAsked).length;

  static List<String> freeNames(TripJourney j, List<TripEnquiryModel> rows) => [
        for (final l in j.legs)
          if (l.lastKnownStatus == _free && !carBooked(j, l.legIndex, rows) && l.driverName.isNotEmpty) l.driverName,
      ];

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static List<TripEnquiryModel> _rowsOf(TripJourney j, List<TripEnquiryModel> journeyRows) => [
        for (final e in journeyRows)
          if (isLive(e) && (e.context.journeyId == null || e.context.journeyId == j.id)) e,
      ];

  static TripTravelState stateOf({
    required TripJourneyRole role,
    TripTravel? arrival,
    TripStep? step,
    required TripJourney? journey,
    required List<TripEnquiryModel> journeyRows,
    required DateTime? travelDate,
    bool gap = false,
  }) {
    final List<int> own;
    if (role == TripJourneyRole.segment) {
      if (arrival == null) return gap ? TripTravelState.gap : TripTravelState.notPlanned;
      if (arrival.isOwn) return TripTravelState.own;
      own = arrival.ownCars;
    } else {
      final s = step;
      if (s == null) return TripTravelState.notPlanned;
      if (s.status == TripStepStatus.own || s.status == TripStepStatus.skipped) return TripTravelState.own;
      if (!s.hasJourney) return TripTravelState.notPlanned;
      own = s.ownCars;
    }
    final j = journey;
    if (j == null) return TripTravelState.notPlanned;
    if (travelDate != null && !_sameDay(j.date, travelDate)) return TripTravelState.dateChanged;
    final rows = _rowsOf(j, journeyRows);
    final cars = [for (final l in j.legs) l.legIndex];
    if (cars.isEmpty) return TripTravelState.saved;
    final open = [for (final c in cars) if (!own.contains(c)) c];
    if (open.isEmpty) return TripTravelState.own;
    if (open.any((c) => carMissing(j, c, rows))) return TripTravelState.carMissing;
    final booked = {for (final c in open) if (carBooked(j, c, rows)) c};
    if (j.legs.any((l) => open.contains(l.legIndex) && !booked.contains(l.legIndex) && !l.driverAvailable)) {
      return TripTravelState.driverUnavailable;
    }
    if (booked.length == open.length) {
      return open.every((c) => carConfirmed(j, c, rows)) ? TripTravelState.confirmed : TripTravelState.booked;
    }
    if (booked.isNotEmpty) return TripTravelState.partlyBooked;
    final asked = j.legs.where((l) => open.contains(l.legIndex) && l.isAsked).toList();
    if (asked.isEmpty) return TripTravelState.saved;
    if (asked.every((l) => l.lastKnownStatus == _free)) return TripTravelState.free;
    return TripTravelState.asked;
  }

  static List<TripCarLine> carLines(TripJourney? journey, List<TripEnquiryModel> journeyRows, List<int> ownCars) {
    final j = journey;
    if (j == null) return const [];
    final rows = _rowsOf(j, journeyRows);
    return [
      for (final l in j.legs) _carLine(j, l, rows, ownCars),
    ];
  }

  static TripCarLine _carLine(TripJourney j, TripJourneyLeg l, List<TripEnquiryModel> rows, List<int> ownCars) {
    final car = l.legIndex;
    if (ownCars.contains(car)) return TripCarLine(car: car, driverName: l.driverName, state: TripCarState.own);
    final booking = carBooking(car, rows);
    if (booking != null) {
      final confirmed = booking.status == TripEnquiryStatuses.confirmedByBoth;
      return TripCarLine(
        car: car,
        driverName: l.driverName,
        state: confirmed ? TripCarState.confirmed : TripCarState.bookedByYou,
        agreedFare: booking.taxi?.agreedFare,
      );
    }
    final TripCarState state;
    if (carMissing(j, car, rows)) {
      state = TripCarState.notAvailable;
    } else if (!l.driverAvailable) {
      state = TripCarState.paused;
    } else if (l.lastKnownStatus == _free ||
        _carRows(car, rows).any((e) => e.status == TripEnquiryStatuses.fareSent)) {
      state = TripCarState.free;
    } else if (l.isAsked || _carRows(car, rows).any((e) => e.status == TripEnquiryStatuses.asked)) {
      state = TripCarState.asked;
    } else {
      state = TripCarState.notAsked;
    }
    return TripCarLine(
      car: car,
      driverName: l.driverName,
      state: state,
      noReply: state == TripCarState.notAvailable && carNoReply(j, car, rows),
    );
  }

  static TravelImpact impactOf(List<TripEnquiryModel> journeyRows, {int cars = 0}) {
    var open = 0;
    var booked = 0;
    for (final e in journeyRows) {
      if (!isLive(e)) continue;
      if (bookedStatuses.contains(e.status)) {
        booked++;
      } else if (e.isWithdrawable) {
        open++;
      }
    }
    return TravelImpact(openRows: open, bookedRows: booked, cars: cars);
  }
}
