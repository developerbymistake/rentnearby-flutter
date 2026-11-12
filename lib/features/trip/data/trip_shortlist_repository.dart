import '../../../services/api_service.dart';
import '../models/trip_shortlist_model.dart';

class TripShortlistErrorTypes {
  static const String full = 'ShortlistFull';
}

class TripShortlistRepository {
  const TripShortlistRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final d = res['data'];
    return d is Map<String, dynamic> ? d : res;
  }

  Future<TripShortlist> list(String tripId) async =>
      TripShortlist.fromJson(_data(await ApiService.get('/trips/$tripId/shortlist')));

  String _path(String tripId, String stepKey, String listingId) =>
      '/trips/$tripId/steps/${Uri.encodeComponent(stepKey)}/shortlist/$listingId';

  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async {
    final data = _data(await ApiService.put(_path(tripId, stepKey, listingId), item.toBody()));
    return TripShortlist.parseItems(data['items'], stepKey: stepKey);
  }

  Future<void> remove(String tripId, String stepKey, String listingId) =>
      ApiService.delete(_path(tripId, stepKey, listingId));

  Future<void> close(String tripId, String stepKey, {required String reason}) async {
    await ApiService.post('/trips/$tripId/steps/${Uri.encodeComponent(stepKey)}/shortlist/close', {'reason': reason});
  }

  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async => MarkBookedResult.fromJson(
        _data(await ApiService.post('/trips/$tripId/steps/${Uri.encodeComponent(stepKey)}/mark-booked', {'listingId': listingId})),
      );
}
