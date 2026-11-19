import 'dart:math' as math;

import '../models/trip_plan_model.dart';
import '../trip_constants.dart';
import 'trip_day_load.dart';

enum TripDraftBlock { none, dayFull, frozen, lastDay, placesDontFit, tooManyDays, tooManySpots, notFound }

class TripDraftDeleteResult {
  final int deletedIndex;
  final int moved;
  final List<int> intoDays;

  const TripDraftDeleteResult({required this.deletedIndex, required this.moved, required this.intoDays});
}

// A rest day counts only while it has no places. Day positions are 0-based indexes into [days]; the leading [frozenDays] are shown but never edited.
class TripLegDraft {
  final int legIndex;
  final int frozenDays;
  final int otherLegsDayCount;
  final int otherLegsSpotCount;
  final int firstDayNumber;
  final List<TripDay> _original;
  final String baseSignature;
  List<TripDay> _days;
  TripDraftDeleteResult? _deleteResult;

  TripLegDraft._({
    required this.legIndex,
    required this.frozenDays,
    required this.otherLegsDayCount,
    required this.otherLegsSpotCount,
    required this.firstDayNumber,
    required List<TripDay> original,
  })  : _original = original,
        baseSignature = signatureOf(original),
        _days = original;

  factory TripLegDraft.from(
    TripPlan plan,
    int legIndex, {
    required int frozenDays,
    required int otherLegsDayCount,
    required int otherLegsSpotCount,
  }) {
    final legDays = [
      for (final d in plan.daysOf(legIndex)) d.copyWith(spots: List<TripSpotRef>.unmodifiable(d.spots)),
    ];
    return TripLegDraft._(
      legIndex: legIndex,
      frozenDays: frozenDays.clamp(0, legDays.length).toInt(),
      otherLegsDayCount: math.max(0, otherLegsDayCount),
      otherLegsSpotCount: math.max(0, otherLegsSpotCount),
      firstDayNumber: legDays.isEmpty ? plan.days.length + 1 : legDays.first.day,
      original: List<TripDay>.unmodifiable(legDays),
    );
  }

  static String signatureOf(List<TripDay> days) =>
      [for (final d in days) '${d.restDay && d.spots.isEmpty ? 'R' : ''}:${d.spots.map((s) => s.id).join(',')}'].join('|');

  List<TripDay> get days => List<TripDay>.unmodifiable(_days);

  int get dayCount => _days.length;

  int get spotCount => _days.fold(0, (n, d) => n + d.spots.length);

  bool get changed => signatureOf(_days) != baseSignature;

  TripDraftDeleteResult? get deleteDayResult => _deleteResult;

  bool isFrozen(int dayIndex) => dayIndex >= 0 && dayIndex < frozenDays;

  bool _valid(int dayIndex) => dayIndex >= 0 && dayIndex < _days.length;

  int get _editableCount => _days.length - frozenDays;

  int? get firstEmptyDay {
    for (var i = frozenDays; i < _days.length; i++) {
      if (_days[i].spots.isEmpty && !_days[i].restDay) return i;
    }
    return null;
  }

  bool get canAddDay => otherLegsDayCount + _days.length < TripConstants.maxDaysCap;

  int get spotRoom => math.max(0, TripConstants.maxSpots - otherLegsSpotCount - spotCount);

  int? dayOfSpot(String spotId) {
    for (var i = 0; i < _days.length; i++) {
      if (_days[i].spots.any((s) => s.id == spotId)) return i;
    }
    return null;
  }

  TripDraftBlock canDrop(String spotId, int toDay) {
    final from = dayOfSpot(spotId);
    if (from == null || !_valid(toDay)) return TripDraftBlock.notFound;
    if (isFrozen(from) || isFrozen(toDay)) return TripDraftBlock.frozen;
    if (from != toDay && _days[toDay].spots.length >= TripConstants.maxSpotsPerDay) return TripDraftBlock.dayFull;
    return TripDraftBlock.none;
  }

  // atIndex is the position in the target day after the spot has been taken out of its old place.
  TripDraftBlock move(String spotId, int toDay, int atIndex) {
    final block = canDrop(spotId, toDay);
    if (block != TripDraftBlock.none) return block;
    final from = dayOfSpot(spotId)!;
    final spot = _days[from].spots.firstWhere((s) => s.id == spotId);
    final next = [for (final d in _days) [...d.spots]];
    next[from].removeWhere((s) => s.id == spotId);
    next[toDay].insert(atIndex.clamp(0, next[toDay].length).toInt(), spot);
    _setSpots({from: next[from], toDay: next[toDay]});
    return TripDraftBlock.none;
  }

  TripDraftBlock remove(String spotId) {
    final from = dayOfSpot(spotId);
    if (from == null) return TripDraftBlock.notFound;
    if (isFrozen(from)) return TripDraftBlock.frozen;
    _setSpots({from: _days[from].spots.where((s) => s.id != spotId).toList()});
    return TripDraftBlock.none;
  }

  TripDraftBlock addDay() {
    if (!canAddDay) return TripDraftBlock.tooManyDays;
    _days = [..._days, TripDay(day: firstDayNumber + _days.length, leg: legIndex)];
    return TripDraftBlock.none;
  }

  TripDraftBlock deleteDay(int dayIndex) {
    _deleteResult = null;
    if (!_valid(dayIndex)) return TripDraftBlock.notFound;
    if (isFrozen(dayIndex)) return TripDraftBlock.frozen;
    if (_editableCount <= 1) return TripDraftBlock.lastDay;
    final moving = _days[dayIndex].spots;
    var free = 0;
    for (var i = frozenDays; i < _days.length; i++) {
      if (i != dayIndex) free += math.max(0, TripConstants.maxSpotsPerDay - _days[i].spots.length);
    }
    if (moving.length > free) return TripDraftBlock.placesDontFit;
    final kept = [
      for (var i = 0; i < _days.length; i++)
        if (i != dayIndex) _days[i],
    ];
    final lists = [for (final d in kept) [...d.spots]];
    final into = <int>[];
    var at = frozenDays;
    for (final s in moving) {
      while (lists[at].length >= TripConstants.maxSpotsPerDay) {
        at++;
      }
      lists[at].add(s);
      if (into.isEmpty || into.last != at) into.add(at);
    }
    _days = [
      for (var i = 0; i < kept.length; i++)
        kept[i].copyWith(spots: List<TripSpotRef>.unmodifiable(lists[i])),
    ];
    _deleteResult = TripDraftDeleteResult(deletedIndex: dayIndex, moved: moving.length, intoDays: List.unmodifiable(into));
    return TripDraftBlock.none;
  }

  TripDraftBlock addSpots(int dayIndex, List<TripSpotRef> spots) {
    if (!_valid(dayIndex)) return TripDraftBlock.notFound;
    if (isFrozen(dayIndex)) return TripDraftBlock.frozen;
    final present = {for (final d in _days) ...d.spots.map((s) => s.id)};
    final fresh = <TripSpotRef>[];
    for (final s in spots) {
      if (present.add(s.id)) fresh.add(s);
    }
    if (fresh.isEmpty) return TripDraftBlock.none;
    final dayRoom = math.max(0, TripConstants.maxSpotsPerDay - _days[dayIndex].spots.length);
    final tripRoom = spotRoom;
    final adding = fresh.take(math.min(dayRoom, tripRoom)).toList();
    if (adding.isNotEmpty) _setSpots({dayIndex: [..._days[dayIndex].spots, ...adding]});
    if (adding.length == fresh.length) return TripDraftBlock.none;
    return dayRoom <= tripRoom ? TripDraftBlock.dayFull : TripDraftBlock.tooManySpots;
  }

  void reset() {
    _days = _original;
    _deleteResult = null;
  }

  List<TripDay> toLegDays() => [
        for (var i = 0; i < _days.length; i++)
          TripDay(
            day: firstDayNumber + i,
            leg: legIndex,
            spots: List<TripSpotRef>.unmodifiable(_days[i].spots),
            restDay: _days[i].restDay && _days[i].spots.isEmpty,
          ),
      ];

  int estimateMinutes(int dayIndex, {String? without}) {
    if (!_valid(dayIndex)) return 0;
    final spots = [for (final s in _days[dayIndex].spots) if (s.id != without) s];
    var minutes = 0;
    for (var i = 0; i < spots.length; i++) {
      minutes += spots[i].visitMinutes;
      if (i > 0) {
        minutes += TripDayLoad.estimateMinutes(
          (lat: spots[i - 1].latitude, lng: spots[i - 1].longitude),
          (lat: spots[i].latitude, lng: spots[i].longitude),
        );
      }
    }
    return minutes;
  }

  void _setSpots(Map<int, List<TripSpotRef>> edits) {
    _deleteResult = null;
    _days = [
      for (var i = 0; i < _days.length; i++)
        edits.containsKey(i) ? _days[i].copyWith(spots: List<TripSpotRef>.unmodifiable(edits[i]!)) : _days[i],
    ];
  }
}
