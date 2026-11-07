import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/models/trip_plan_model.dart';
import '../ways/models/ask_models.dart';
import '../ways/models/taxi_ways_models.dart';
import '../ways/taxi_ways_strings.dart';
import 'journey_local_store.dart';
import 'journey_models.dart';
import 'journey_repository.dart';
import 'journey_strings.dart';

typedef JourneyTripLink = ({String role, int? legIndex, int? travelDay});

class JourneyErrorTypes {
  static const String notFound = 'JourneyNotFound';
  static const String limitReached = 'JourneyLimitReached';
  static const String journeyInTrip = 'JourneyInTrip';
}

class JourneysController extends GetxController {
  static JourneysController ensure() {
    final userId = Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;
    if (Get.isRegistered<JourneysController>()) {
      final c = Get.find<JourneysController>();
      if (c._userId != userId) c._reset();
      c._userId = userId;
      return c;
    }
    final c = JourneysController().._userId = userId;
    return Get.put(c, permanent: true);
  }

  static JourneysController get to => ensure();

  static const Duration staleAfter = Duration(minutes: 10);
  static const int _nameMax = 80;

  final _repo = const JourneyRepository();
  final journeys = <SavedJourney>[].obs;
  final isLoading = false.obs;
  final loadFailed = false.obs;
  final isOffline = false.obs;
  final busyIds = <String>{}.obs;

  String? _userId;
  int _requestId = 0;
  final _committedDuringLoad = <String, SavedJourney>{};
  DateTime? _syncedAt;
  Future<void>? _running;
  bool _saving = false;
  final _createdForTrip = <String, String>{};

  bool get hasUnavailable => journeys.any((j) => j.status == JourneyStatus.driverUnavailable);

  @override
  void onInit() {
    super.onInit();
    JourneyLocalStore.init();
  }

  void _reset() {
    _requestId++;
    _syncedAt = null;
    journeys.clear();
    busyIds.clear();
    _createdForTrip.clear();
    isLoading.value = false;
    loadFailed.value = false;
    isOffline.value = false;
  }

  SavedJourney? byId(String id) {
    for (final j in journeys) {
      if (j.id == id) return j;
    }
    return null;
  }

  SavedJourney? findByPlan(String planKey, DateTime date, {int? people, String? forTripId}) {
    for (final j in journeys) {
      if (j.isCompleted || j.planKey != planKey) continue;
      if (people != null && j.people != people) continue;
      if (forTripId != null && j.tripId != null && j.tripId != forTripId) continue;
      if (j.date.year == date.year && j.date.month == date.month && j.date.day == date.day) return j;
    }
    return null;
  }

  void _assign(List<SavedJourney> list) {
    final sorted = [...list]..sort(SavedJourney.compare);
    journeys.assignAll(sorted);
  }

  Future<void> _commit(SavedJourney journey) async {
    if (isLoading.value) _committedDuringLoad[journey.id] = journey;
    await JourneyLocalStore.upsert(journey);
    _assign(await JourneyLocalStore.read());
    if (Get.isRegistered<TripPlanController>()) {
      Get.find<TripPlanController>().refreshLinkedJourney(byId(journey.id) ?? journey);
    }
  }

  Future<void> syncTripLinks(
    String tripId,
    Set<String> linkedIds, {
    Map<String, JourneyTripLink> links = const {},
    String? tripTitle,
  }) async {
    if (journeys.isEmpty) _assign(await JourneyLocalStore.read());
    final changed = <SavedJourney>[];
    for (final j in journeys) {
      final link = links[j.id];
      if (linkedIds.contains(j.id)) {
        if (link != null && !_sameLink(j, tripId, link)) {
          changed.add(_withLink(j, tripId, link, tripTitle));
        } else if (j.tripId != tripId) {
          changed.add(j.copyWith(tripId: tripId));
        }
      } else if (j.tripId == tripId) {
        changed.add(j.copyWith(clearTripId: true));
      }
    }
    if (changed.isEmpty) return;
    for (final j in changed) {
      await JourneyLocalStore.upsert(j);
    }
    _assign(await JourneyLocalStore.read());
  }

  static bool _sameLink(SavedJourney j, String tripId, JourneyTripLink link) =>
      j.tripId == tripId &&
      j.tripRole == link.role &&
      j.tripLegIndex == link.legIndex &&
      j.tripTravelDay == link.travelDay;

  static SavedJourney _withLink(SavedJourney j, String tripId, JourneyTripLink link, String? tripTitle) =>
      SavedJourney.fromJson({
        ...j.toJson(),
        'tripId': tripId,
        'tripTitle': tripTitle ?? j.tripTitle,
        'tripRole': link.role,
        'tripLegIndex': link.legIndex,
        'tripTravelDay': link.travelDay,
      });

  bool createdForTrip(String journeyId, String tripId) => _createdForTrip[journeyId] == tripId;

  Future<void> _drop(String id) async {
    _committedDuringLoad.remove(id);
    journeys.removeWhere((j) => j.id == id);
    await JourneyLocalStore.remove(id);
  }

  Future<void> load({bool force = false}) async {
    final running = _running;
    if (running != null) {
      await running;
      if (!force) return;
    }
    final run = _load(force);
    _running = run;
    try {
      await run;
    } finally {
      if (identical(_running, run)) _running = null;
    }
  }

  Future<void> _load(bool force) async {
    final id = ++_requestId;
    _committedDuringLoad.clear();
    isLoading.value = true;
    loadFailed.value = false;
    try {
      final local = await JourneyLocalStore.read();
      if (id != _requestId) return;
      _assign(local);
      final synced = _syncedAt;
      final stale = synced == null || DateTime.now().difference(synced) > staleAfter;
      if (!force && !stale) return;
      try {
        final remote = await _repo.list();
        if (id != _requestId) return;
        final remoteIds = {for (final j in remote) j.id};
        await JourneyLocalStore.replaceAll([
          ...remote,
          for (final j in _committedDuringLoad.values)
            if (!remoteIds.contains(j.id)) j,
        ]);
        _assign(await JourneyLocalStore.read());
        _syncedAt = DateTime.now();
        isOffline.value = false;
      } catch (e) {
        if (id != _requestId) return;
        isOffline.value = DioErrorMapper.isNetworkError(e);
        if (journeys.isEmpty) loadFailed.value = true;
      }
    } finally {
      if (id == _requestId) isLoading.value = false;
    }
  }

  String _cut(String s) => s.length > _nameMax ? s.substring(0, _nameMax) : s;

  String _label(String name, String key, {required bool start, required bool end}) =>
      _cut(wayNameOr(name, key, start: start, end: end));

  @visibleForTesting
  Map<String, dynamic>? saveBodyOf({
    required WayPlan plan,
    required Map<int, WayDriver> chosen,
    required DateTime date,
    required int people,
    required String fromName,
    required double fromLat,
    required double fromLng,
    required String toName,
    required double toLat,
    required double toLng,
    String? tripId,
    int? legIndex,
  }) {
    if (plan.legs.isEmpty) return null;
    final legs = <Map<String, dynamic>>[];
    for (final leg in plan.legs) {
      final manual = chosen[leg.index];
      final d = leg.driverFor(manual);
      if (d == null) return null;
      final cover = leg.coverOthersFor(manual);
      final backups = leg.allDrivers.where((x) => x.taxiId != d.taxiId && !cover.contains(x.taxiId)).take(2).toList();
      legs.add({
        'legIndex': leg.index,
        'legKey': leg.legKey,
        'fromName': _label(leg.from.name, leg.from.key, start: leg.index == 1, end: false),
        'fromLat': leg.from.lat,
        'fromLng': leg.from.lng,
        'toName': _label(leg.to.name, leg.to.key, start: false, end: leg.index == plan.legs.length),
        'toLat': leg.to.lat,
        'toLng': leg.to.lng,
        'meetingPlace': ?(leg.meetingPlace == null ? null : _cut(leg.meetingPlace!)),
        'driverTaxiId': d.taxiId,
        'driverRouteId': ?d.routeId,
        'listedFare': ?(d.listedFare > 0 ? d.listedFare : null),
        'partial': d.partial,
        'backup1TaxiId': ?(backups.isNotEmpty ? backups[0].taxiId : null),
        'backup2TaxiId': ?(backups.length > 1 ? backups[1].taxiId : null),
        if (cover.isNotEmpty) 'coverTaxiIds': cover,
      });
    }
    return {
      'fromName': _label(fromName, plan.from.key, start: true, end: false),
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toName': _label(toName, plan.to.key, start: false, end: true),
      'toLat': toLat,
      'toLng': toLng,
      'date': JourneyFormat.wireDate(date),
      'people': people,
      'planKey': plan.planKey,
      'legs': legs,
      'tripId': ?tripId,
      'legIndex': ?(tripId == null ? null : legIndex),
    };
  }

  Future<SavedJourney?> save({
    required WayPlan plan,
    required Map<int, WayDriver> chosen,
    required DateTime date,
    required int people,
    required String fromName,
    required double fromLat,
    required double fromLng,
    required String toName,
    required double toLat,
    required double toLng,
    bool quiet = false,
    String? tripId,
    int? legIndex,
  }) async {
    if (_saving) return null;
    final body = saveBodyOf(
      plan: plan,
      chosen: chosen,
      date: date,
      people: people,
      fromName: fromName,
      fromLat: fromLat,
      fromLng: fromLng,
      toName: toName,
      toLat: toLat,
      toLng: toLng,
      tripId: tripId,
      legIndex: legIndex,
    );
    if (body == null) return null;
    _saving = true;
    try {
      final res = await ApiService.post('/taxis/journeys', body);
      final data = res['data'];
      final saved = SavedJourney.fromJson(data is Map<String, dynamic> ? data : const {});
      if (tripId != null && res['code'] == 201 && saved.id.isNotEmpty) _createdForTrip[saved.id] = tripId;
      await _commit(saved);
      if (!quiet) AppToast.success(TaxiWaysStrings.saved);
      return byId(saved.id) ?? saved;
    } catch (e) {
      _toastSaveError(e);
      return null;
    } finally {
      _saving = false;
    }
  }

  Future<SavedJourney?> saveIfNeeded({
    required WayPlan plan,
    required Map<int, WayDriver> chosen,
    required DateTime date,
    required int people,
    required String fromName,
    required double fromLat,
    required double fromLng,
    required String toName,
    required double toLat,
    required double toLng,
    bool quiet = false,
    String? forTripId,
    int? forTripLegIndex,
  }) async {
    if (journeys.isEmpty) _assign(await JourneyLocalStore.read());
    final existing = findByPlan(plan.planKey, date, people: people, forTripId: forTripId);
    if (existing != null) return _syncDrivers(existing, plan, chosen);
    final saved = await save(
      plan: plan,
      chosen: chosen,
      date: date,
      people: people,
      fromName: fromName,
      fromLat: fromLat,
      fromLng: fromLng,
      toName: toName,
      toLat: toLat,
      toLng: toLng,
      quiet: quiet,
      tripId: forTripLegIndex == null ? null : forTripId,
      legIndex: forTripLegIndex,
    );
    return saved == null ? null : _syncDrivers(saved, plan, chosen);
  }

  Future<SavedJourney?> _syncDrivers(SavedJourney journey, WayPlan plan, Map<int, WayDriver> chosen) async {
    var current = journey;
    for (final leg in plan.legs) {
      final want = chosen[leg.index] ?? leg.firstDriver;
      final have = current.leg(leg.index);
      if (want == null || have == null || want.taxiId == have.driver.taxiId) continue;
      try {
        await _commit(await _repo.replaceDriver(current.id, leg.index, want.taxiId));
        isOffline.value = false;
      } catch (e) {
        _handleError(e, current.id);
        return null;
      }
      current = byId(current.id) ?? current;
    }
    return current;
  }

  Future<void> refreshOne(String id, {bool silent = false}) async {
    if (busyIds.contains(id)) return;
    busyIds.add(id);
    try {
      final old = byId(id);
      var fresh = await _repo.refresh(id);
      if (old != null) fresh = _markFareChanges(old, fresh);
      await _commit(fresh);
      isOffline.value = false;
    } catch (e) {
      _handleError(e, id, silent: silent);
    } finally {
      busyIds.remove(id);
    }
  }

  SavedJourney _markFareChanges(SavedJourney old, SavedJourney fresh) {
    final legs = fresh.legs.map((l) {
      final o = old.leg(l.legIndex);
      if (o == null || o.driver.taxiId != l.driver.taxiId) return l.copyWith(clearPreviousFare: true);
      final was = o.listedFare;
      final now = l.listedFare;
      if (was != null && now != null && was != now) return l.copyWith(previousFare: was);
      if (l.fareChanged && o.previousFare != null) return l.copyWith(previousFare: o.previousFare);
      return l.copyWith(clearPreviousFare: true);
    }).toList();
    return fresh.copyWith(legs: legs);
  }

  Future<void> replaceDriver(String id, int legIndex, String taxiId) async {
    if (busyIds.contains(id)) return;
    busyIds.add(id);
    try {
      await _commit(await _repo.replaceDriver(id, legIndex, taxiId));
      isOffline.value = false;
      AppToast.success(JourneyStrings.driverReplaced);
    } catch (e) {
      _handleError(e, id);
    } finally {
      busyIds.remove(id);
    }
  }

  Future<bool> complete(String id) async {
    if (busyIds.contains(id)) return false;
    busyIds.add(id);
    try {
      await _commit(await _repo.complete(id));
      AppToast.success(JourneyStrings.markedDone);
      return true;
    } catch (e) {
      _handleError(e, id);
      return false;
    } finally {
      busyIds.remove(id);
    }
  }

  Future<bool> remove(String id) async {
    if (busyIds.contains(id)) return false;
    busyIds.add(id);
    try {
      final tripId = byId(id)?.tripId;
      await _repo.delete(id);
      await _drop(id);
      _unlinkFromTrip(tripId, id);
      AppToast.success(JourneyStrings.deleted);
      return true;
    } catch (e) {
      _handleError(e, id);
      return false;
    } finally {
      busyIds.remove(id);
    }
  }

  void _unlinkFromTrip(String? tripId, String journeyId) {
    if (!Get.isRegistered<TripPlanController>()) return;
    final c = Get.find<TripPlanController>();
    if (tripId != null && c.trip.value?.id != tripId) return;
    for (final role in TripStepRole.values) {
      if (c.stepOf(role).journeyId == journeyId) c.unlinkJourney(role);
    }
    c.unlinkSegmentJourney(journeyId);
  }

  void recordAsk(String journeyId, AskResult result) {
    final j = byId(journeyId);
    if (j == null) return;
    final now = DateTime.now();
    final legs = j.legs.map((l) {
      final mine = result.items.where((i) => i.legIndex == l.legIndex && i.enquiryId.isNotEmpty);
      final item = mine.where((i) => i.taxiId == l.driver.taxiId).firstOrNull ?? mine.firstOrNull;
      if (item == null) return l;
      return l.copyWith(lastEnquiryId: item.enquiryId, lastKnownStatus: _legStatusOf(item.status), lastKnownAt: now);
    }).toList();
    final status = j.status == JourneyStatus.notAsked ? JourneyStatus.ready : j.status;
    unawaited(_commit(j.copyWith(legs: legs, status: status)));
    if (Get.isRegistered<TripPlanController>()) {
      final c = Get.find<TripPlanController>();
      if (c.trip.value?.journeys.any((x) => x.id == journeyId) ?? false) unawaited(c.refreshEnquiries());
    }
  }

  LegStatus _legStatusOf(String status) => switch (status) {
        'FareSent' || 'BookedByTraveller' || 'ConfirmedByBoth' => LegStatus.free,
        'NotAvailable' || 'Failed' => LegStatus.notFree,
        'Expired' || 'Closed' => LegStatus.unknown,
        _ => LegStatus.noAnswer,
      };

  void _toastSaveError(Object e) {
    final type = DioErrorMapper.errorType(e);
    if (type == JourneyErrorTypes.limitReached) {
      AppToast.warning(TaxiWaysStrings.journeyLimit);
    } else if (type == JourneyErrorTypes.journeyInTrip) {
      AppToast.warning(DioErrorMapper.toMessage(e, TaxiWaysStrings.saveFailed, showRawMessageForStatusCodes: {409}));
    } else if (DioErrorMapper.isNetworkError(e)) {
      AppToast.error(TaxiWaysStrings.offlineTitle);
    } else if (type == ApiService.tabInactiveType) {
      AppToast.warning(TaxiWaysStrings.taxisOff);
    } else {
      AppToast.error(DioErrorMapper.toMessage(e, TaxiWaysStrings.saveFailed, showRawMessageForStatusCodes: {400, 409, 429}));
    }
  }

  void _handleError(Object e, String id, {bool silent = false}) {
    final type = DioErrorMapper.errorType(e);
    if (type == JourneyErrorTypes.notFound) {
      unawaited(_drop(id));
      return;
    }
    if (DioErrorMapper.isNetworkError(e)) {
      isOffline.value = true;
      if (!silent) AppToast.warning(TaxiWaysStrings.offlineSaved);
      return;
    }
    if (silent) return;
    if (type == JourneyErrorTypes.journeyInTrip) {
      AppToast.warning(DioErrorMapper.toMessage(e, TaxiWaysStrings.saveFailed, showRawMessageForStatusCodes: {409}));
    } else if (type == ApiService.tabInactiveType) {
      AppToast.warning(TaxiWaysStrings.taxisOff);
    } else {
      AppToast.error(DioErrorMapper.toMessage(e, TaxiWaysStrings.saveFailed, showRawMessageForStatusCodes: {400, 403, 409, 429}));
    }
  }
}
