import '../../../services/api_service.dart';
import '../../../utils/network_retry.dart';
import '../models/taxi_request_models.dart';
import '../utils/taxi_result.dart';

class TaxiRequestRepository {
  const TaxiRequestRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<TaxiResult<T>> _run<T>(Future<T> Function() call) async {
    try {
      return TaxiOk(await call());
    } catch (e) {
      return TaxiResult.fromError<T>(e);
    }
  }

  Future<TaxiResult<TaxiRequest>> _request(Future<Map<String, dynamic>> Function() call) =>
      _run(() async => TaxiRequest.fromJson(_data(await call())));

  Future<TaxiResult<TaxiPickupPlaces>> pickupPlaces(String tripId) => _run(() async =>
      TaxiPickupPlaces.fromJson(_data(await withRetry(() => ApiService.get('/trips/$tripId/taxi-request/pickup-places')))));

  Future<TaxiResult<TaxiRequest>> create(String tripId, Map<String, dynamic> body) =>
      _request(() => ApiService.post('/trips/$tripId/taxi-request', body));

  Future<TaxiResult<TaxiRequest?>> forTrip(String tripId) => _run(() async {
        final data = (await withRetry(() => ApiService.get('/trips/$tripId/taxi-request')))['data'];
        return data is Map<String, dynamic> ? TaxiRequest.fromJson(data) : null;
      });

  Future<TaxiResult<TaxiRequest>> get(String requestId) =>
      _request(() => withRetry(() => ApiService.get('/taxi-requests/$requestId')));

  Future<TaxiResult<TaxiRequest>> cancel(String requestId, {String reason = 'TravellerCancelled', ReasonChip? chip}) =>
      _request(() => ApiService.post('/taxi-requests/$requestId/cancel', {'reason': reason, 'chip': chip?.wire}));

  Future<TaxiResult<TaxiRequest>> askMore(String requestId) =>
      _request(() => ApiService.post('/taxi-requests/$requestId/ask-more', const {}));

  Future<TaxiResult<TaxiRequest>> select(String requestId, String offerId) =>
      _request(() => ApiService.post('/taxi-requests/$requestId/offers/$offerId/select', const {}));

  Future<TaxiResult<TaxiRequest>> notAgreed(String requestId, String offerId) =>
      _request(() => ApiService.post('/taxi-requests/$requestId/offers/$offerId/not-agreed', const {}));

  Future<TaxiResult<TaxiRequest>> end(String requestId) =>
      _request(() => ApiService.post('/taxi-requests/$requestId/end', const {}));

  Future<TaxiResult<TaxiRequest>> rate(String requestId, int stars) =>
      _request(() => ApiService.post('/taxi-requests/$requestId/rating', {'stars': stars}));
}
