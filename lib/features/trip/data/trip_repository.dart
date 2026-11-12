import 'package:get/get.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/network_retry.dart';
import '../models/trip_city_model.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_summary_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../utils/trip_spot_picks.dart';

class TripErrorTypes {
  static const String tripNotFound = 'TripNotFound';
  static const String spotsUnavailable = 'SpotsUnavailable';
  static const String plannerDisabled = 'TripPlannerDisabled';
  static const String cityNotFound = 'CityNotFound';
  static const String citiesUnavailable = 'TripCitiesUnavailable';
  static const String concurrentUpdate = 'CONCURRENT_UPDATE';
  static const String tripNotEnded = 'TripNotEnded';
  static const String tripNeedsUpdate = 'TripNeedsUpdate';
  static const String tripCompleted = 'TripCompleted';
  static const String travelDateChanged = 'TravelDateChanged';
  static const String journeyInTrip = 'JourneyInTrip';
  static const String journeyNotInPlan = 'JourneyNotInPlan';
  static const String routeMismatch = 'RouteMismatch';
  static const String journeyNotFound = 'JourneyNotFound';
  static const String noStayNight = 'NoStayNight';
  static const String daysAcrossCities = 'DaysAcrossCities';
  static const String tooManySpotsPerDay = 'TooManySpotsPerDay';
  static const String tooManySpotsForDays = 'TooManySpotsForDays';
}

class TripCitySupply {
  final String? districtId;
  final int listedStays;
  final int listedDrivers;

  const TripCitySupply({this.districtId, int stays = 0, int drivers = 0})
      : listedStays = stays,
        listedDrivers = drivers;

  static bool _tabOn(int index) =>
      !Get.isRegistered<TabConfigController>() || TabConfigController.to.isActiveForIndex(index);

  int get stays => _tabOn(AppTabs.stays) ? listedStays : 0;

  int get drivers => _tabOn(AppTabs.taxi) ? listedDrivers : 0;

  bool get isEmpty => stays == 0 && drivers == 0;

  factory TripCitySupply.fromJson(Map<String, dynamic> json) => TripCitySupply(
        districtId: json['districtId'] as String?,
        stays: (json['stays'] as num?)?.toInt() ?? 0,
        drivers: (json['drivers'] as num?)?.toInt() ?? 0,
      );
}

class TripProblemResult {
  final String problemId;
  final TripEnquiryModel? enquiry;
  final TripEnquiryModel? keptEnquiry;
  final bool marked;

  const TripProblemResult({required this.problemId, this.enquiry, this.keptEnquiry, this.marked = false});

  List<TripEnquiryModel> get rows => [?enquiry, ?keptEnquiry];
}

class TripCached<T> {
  final T value;
  final DateTime? savedAt;

  const TripCached(this.value, this.savedAt);
}

class TripListStates {
  static const String active = 'active';
  static const String past = 'past';
}

class TripRepository {
  const TripRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<TripCityVersion> citiesVersion({bool once = false}) async =>
      TripCityVersion.fromJson(_data(await withRetry(() => ApiService.get('/trips/cities/version'), once: once)));

  Future<TripCityPage> cities({int page = 1, int pageSize = TripConstants.citiesPageSize, String? q, bool once = false}) async =>
      TripCityPage.fromJson(_data(await withRetry(() => ApiService.get('/trips/cities', params: {
            'page': page,
            'pageSize': pageSize,
            'q': ?q,
          }), once: once)));

  Future<TripSpotsPage> spots(int cityKey, {String? cursor, int pageSize = TripConstants.spotsPageSize}) async =>
      TripSpotsPage.fromJson(_data(await withRetry(() => ApiService.get('/trips/cities/$cityKey/spots', params: {
            'cursor': ?cursor,
            'pageSize': pageSize,
          }))));

  Future<TripSpotMinutes?> spotMinutes(int cityKey, List<String> spotIds) async => TripSpotMinutes.fromJson(
      _data(await ApiService.post('/trips/cities/$cityKey/spots/minutes', {'spotIds': spotIds})));

  Future<TripPlanResult> plan(Map<String, dynamic> body) async =>
      TripPlanResult.fromJson(_data(await ApiService.post('/trips/plan', body)));

  static const String _savedAtKey = 'cachedAt';

  static Map<String, dynamic> _stamp(Map<String, dynamic> data) =>
      {...data, _savedAtKey: DateTime.now().toIso8601String()};

  static DateTime? _savedAt(Map<String, dynamic> json) => DateTime.tryParse(json[_savedAtKey] as String? ?? '');

  // No signal: one try, so the saved copy shows at once.
  static Future<T> _read<T>(Future<T> Function() request) =>
      Get.isRegistered<LocationController>() && Get.find<LocationController>().isOffline.value ? request() : withRetry(request);

  Future<TripListPage> list({int page = 1, int pageSize = 20, String state = TripListStates.active}) async {
    final data = _data(await _read(() => ApiService.get('/trips', params: {
          'page': page,
          'pageSize': pageSize,
          'state': state,
        })));
    if (page == 1) StorageService.saveTripListCache(state, _stamp(data));
    return TripListPage.fromJson(data);
  }

  void forgetCached(String id) {
    for (final state in const [TripListStates.active, TripListStates.past]) {
      final json = StorageService.getTripListCache(state);
      final items = json?['items'];
      if (json == null || items is! List || !items.any((e) => e is Map && e['id'] == id)) continue;
      StorageService.saveTripListCache(state, {
        ...json,
        'items': [for (final e in items) if (!(e is Map && e['id'] == id)) e],
      });
    }
  }

  TripCached<TripListPage>? cachedList(String state) {
    final json = StorageService.getTripListCache(state);
    if (json == null) return null;
    try {
      return TripCached(TripListPage.fromJson(json), _savedAt(json));
    } catch (_) {
      return null;
    }
  }

  Future<TripSummaryRecord> summary(String id) async {
    final data = _data(await withRetry(() => ApiService.get('/trips/$id/summary')));
    StorageService.saveTripSummaryCache(id, _stamp(data));
    return TripSummaryRecord.fromJson(data);
  }

  TripCached<TripSummaryRecord>? cachedSummary(String id) {
    final json = StorageService.getTripSummaryCache(id);
    if (json == null) return null;
    try {
      return TripCached(TripSummaryRecord.fromJson(json), _savedAt(json));
    } catch (_) {
      return null;
    }
  }

  Future<TripCitySupply> citySupply(int cityKey) async =>
      TripCitySupply.fromJson(_data(await withRetry(() => ApiService.get('/trips/cities/$cityKey/supply'))));

  Future<TripModel> complete(String id) async =>
      TripModel.fromJson(_data(await ApiService.post('/trips/$id/complete', {})));

  Future<TripModel> mute(String id, {required bool muted}) async =>
      TripModel.fromJson(_data(await ApiService.put('/trips/$id/mute', {'muted': muted})));

  Future<TripProblemResult> reportProblem(
    String tripId, {
    required int day,
    required String kind,
    String? enquiryId,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final data = _data(await ApiService.post('/trips/$tripId/problems', {
      'day': day,
      'kind': kind,
      'enquiryId': ?enquiryId,
      'note': ?note,
      'latitude': ?latitude,
      'longitude': ?longitude,
    }));
    final enquiry = data['enquiry'];
    final kept = data['keptEnquiry'];
    return TripProblemResult(
      problemId: data['problemId'] as String? ?? '',
      enquiry: enquiry is Map<String, dynamic> ? TripEnquiryModel.fromJson(enquiry) : null,
      keptEnquiry: kept is Map<String, dynamic> ? TripEnquiryModel.fromJson(kept) : null,
      marked: data['marked'] == true,
    );
  }

  Future<TripModel> get(String id) async => TripModel.fromJson(_data(await _read(() => ApiService.get('/trips/$id'))));

  Future<TripModel> create({String? title, String? status, required TripPlan plan, String? clientTripId}) async =>
      TripModel.fromJson(_data(await ApiService.post('/trips', {
        'title': ?title,
        'status': ?status,
        'plan': plan.toJson(),
        'clientTripId': ?clientTripId,
      })));

  Future<TripModel> update(String id, {String? title, String? status, required TripPlan plan}) async =>
      TripModel.fromJson(_data(await ApiService.put('/trips/$id', {
        'title': ?title,
        'status': ?status,
        'plan': plan.toJson(),
      })));

  Future<void> delete(String id) => ApiService.delete('/trips/$id');
}
