import '../../../services/api_service.dart';
import '../../../utils/network_retry.dart';
import 'journey_models.dart';

class JourneyRepository {
  const JourneyRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  SavedJourney _one(Map<String, dynamic> res) => SavedJourney.fromJson(_data(res));

  Future<List<SavedJourney>> list() async {
    final items = _data(await withRetry(() => ApiService.get('/taxis/journeys')))['items'];
    return items is List ? items.whereType<Map<String, dynamic>>().map(SavedJourney.fromJson).toList() : <SavedJourney>[];
  }

  Future<SavedJourney> get(String id) async => _one(await withRetry(() => ApiService.get('/taxis/journeys/$id')));

  Future<SavedJourney> save(Map<String, dynamic> body) async => _one(await ApiService.post('/taxis/journeys', body));

  Future<void> delete(String id) => ApiService.delete('/taxis/journeys/$id');

  Future<SavedJourney> refresh(String id) async => _one(await ApiService.post('/taxis/journeys/$id/refresh', const {}));

  Future<SavedJourney> replaceDriver(String id, int legIndex, String taxiId) async =>
      _one(await ApiService.put('/taxis/journeys/$id/legs/$legIndex/driver', {'taxiId': taxiId}));

  Future<SavedJourney> complete(String id) async =>
      _one(await ApiService.put('/taxis/journeys/$id/status', const {'status': 'Completed'}));
}
