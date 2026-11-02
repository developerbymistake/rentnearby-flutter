import '../../../services/api_service.dart';
import '../../../utils/network_retry.dart';
import '../models/trip_city_model.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';

class TripErrorTypes {
  static const String tripNotFound = 'TripNotFound';
  static const String spotsUnavailable = 'SpotsUnavailable';
  static const String plannerDisabled = 'TripPlannerDisabled';
  static const String cityNotFound = 'CityNotFound';
  static const String citiesUnavailable = 'TripCitiesUnavailable';
  static const String concurrentUpdate = 'CONCURRENT_UPDATE';
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

  Future<TripListPage> list({int page = 1, int pageSize = 20}) async =>
      TripListPage.fromJson(_data(await withRetry(() => ApiService.get('/trips', params: {
            'page': page,
            'pageSize': pageSize,
          }))));

  Future<TripModel> get(String id) async => TripModel.fromJson(_data(await withRetry(() => ApiService.get('/trips/$id'))));

  Future<TripModel> create({String? title, String? status, required TripPlan plan}) async =>
      TripModel.fromJson(_data(await ApiService.post('/trips', {
        'title': ?title,
        'status': ?status,
        'plan': plan.toJson(),
      })));

  Future<TripModel> update(String id, {String? title, String? status, required TripPlan plan}) async =>
      TripModel.fromJson(_data(await ApiService.put('/trips/$id', {
        'title': ?title,
        'status': ?status,
        'plan': plan.toJson(),
      })));

  Future<void> delete(String id) => ApiService.delete('/trips/$id');
}
