import '../../../services/api_service.dart';
import '../../../utils/network_retry.dart';
import '../models/trip_city_model.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_summary_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';

class TripErrorTypes {
  static const String tripNotFound = 'TripNotFound';
  static const String spotsUnavailable = 'SpotsUnavailable';
  static const String plannerDisabled = 'TripPlannerDisabled';
  static const String cityNotFound = 'CityNotFound';
  static const String citiesUnavailable = 'TripCitiesUnavailable';
  static const String concurrentUpdate = 'CONCURRENT_UPDATE';
  static const String tripNotEnded = 'TripNotEnded';
}

class TripRepository {
  const TripRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<TripCityVersion> citiesVersion() async =>
      TripCityVersion.fromJson(_data(await withRetry(() => ApiService.get('/trips/cities/version'))));

  Future<TripCityPage> cities({int page = 1, int pageSize = TripConstants.citiesPageSize, String? q}) async =>
      TripCityPage.fromJson(_data(await withRetry(() => ApiService.get('/trips/cities', params: {
            'page': page,
            'pageSize': pageSize,
            'q': ?q,
          }))));

  Future<TripSpotsPage> spots(int cityKey, {String? cursor, int pageSize = TripConstants.spotsPageSize}) async =>
      TripSpotsPage.fromJson(_data(await withRetry(() => ApiService.get('/trips/cities/$cityKey/spots', params: {
            'cursor': ?cursor,
            'pageSize': pageSize,
          }))));

  Future<TripPlanResult> plan(Map<String, dynamic> body) async =>
      TripPlanResult.fromJson(_data(await ApiService.post('/trips/plan', body)));

  Future<TripListPage> list({int page = 1, int pageSize = 20, String state = 'upcoming'}) async =>
      TripListPage.fromJson(_data(await withRetry(() => ApiService.get('/trips', params: {
            'page': page,
            'pageSize': pageSize,
            'state': state,
          }))));

  Future<TripSummaryRecord> summary(String id) async =>
      TripSummaryRecord.fromJson(_data(await withRetry(() => ApiService.get('/trips/$id/summary'))));

  Future<TripModel> complete(String id) async =>
      TripModel.fromJson(_data(await ApiService.post('/trips/$id/complete', {})));

  Future<TripModel> mute(String id, {required bool muted}) async =>
      TripModel.fromJson(_data(await ApiService.put('/trips/$id/mute', {'muted': muted})));

  Future<({String problemId, TripEnquiryModel? enquiry, bool marked})> reportProblem(
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
    return (
      problemId: data['problemId'] as String? ?? '',
      enquiry: enquiry is Map<String, dynamic> ? TripEnquiryModel.fromJson(enquiry) : null,
      marked: data['marked'] == true,
    );
  }

  Future<TripModel> get(String id) async => TripModel.fromJson(_data(await withRetry(() => ApiService.get('/trips/$id'))));

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
