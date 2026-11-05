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

  static bool carMissing(TripJourney j, int car, List<TripEnquiryModel> rows) {
    if (carBooked(j, car, rows)) return false;
    final leg = _leg(j, car);
    if (leg == null) return false;
    if (leg.lastKnownStatus == _notFree) return true;
    final mine = _carRows(car, rows);
    return leg.isAsked && mine.isNotEmpty && mine.every(isRedRow);
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

  static TripTravelState stateOf({
    required TripTravel? arrival,
    required TripJourney? journey,
    required List<TripEnquiryModel> journeyRows,
    required DateTime? travelDate,
    bool gap = false,
  }) {
    if (arrival == null) return gap ? TripTravelState.gap : TripTravelState.notPlanned;
    if (arrival.isOwn) return TripTravelState.own;
    final j = journey;
    if (j == null) return TripTravelState.notPlanned;
    if (travelDate != null && !_sameDay(j.date, travelDate)) return TripTravelState.dateChanged;
    final rows = [
      for (final e in journeyRows)
        if (isLive(e) && (e.context.journeyId == null || e.context.journeyId == j.id)) e,
    ];
    final cars = [for (final l in j.legs) l.legIndex];
    if (cars.isEmpty) return TripTravelState.saved;
    if (cars.any((c) => carMissing(j, c, rows))) return TripTravelState.carMissing;
    final booked = {for (final c in cars) if (carBooked(j, c, rows)) c};
    if (j.legs.any((l) => !booked.contains(l.legIndex) && !l.driverAvailable)) {
      return TripTravelState.driverUnavailable;
    }
    if (booked.length == cars.length) {
      return cars.every((c) => carConfirmed(j, c, rows)) ? TripTravelState.confirmed : TripTravelState.booked;
    }
    if (booked.isNotEmpty) return TripTravelState.partlyBooked;
    final asked = j.legs.where((l) => l.isAsked).toList();
    if (asked.isEmpty) return TripTravelState.saved;
    if (asked.every((l) => l.lastKnownStatus == _free)) return TripTravelState.free;
    return TripTravelState.asked;
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
