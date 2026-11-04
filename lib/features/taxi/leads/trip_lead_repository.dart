import '../../../services/api_service.dart';
import '../../../utils/network_retry.dart';
import '../../trip/models/trip_enquiry_model.dart';

class TripLeadRepository {
  const TripLeadRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  TripEnquiryModel _one(Map<String, dynamic> res) => TripEnquiryModel.fromJson(_data(res));

  Future<TripDriverLeadPage> list({required String status, int page = 1, int pageSize = 20}) async =>
      TripDriverLeadPage.fromJson(_data(await withRetry(() => ApiService.get('/trips/leads/driver', params: {
            'status': status,
            'page': page,
            'pageSize': pageSize,
          }))));

  Future<TripEnquiryModel> fare(String id, {required int fare, String? note}) async =>
      _one(await ApiService.post('/trips/leads/$id/fare', {'fare': fare, 'note': ?note}));

  Future<TripEnquiryModel> notAvailable(String id) async =>
      _one(await ApiService.post('/trips/leads/$id/not-available', const {}));

  Future<TripEnquiryModel> confirm(String id) async => _one(await ApiService.post('/trips/leads/$id/confirm', const {}));

  Future<TripEnquiryModel> deny(String id) async => _one(await ApiService.post('/trips/leads/$id/deny', const {}));
}
