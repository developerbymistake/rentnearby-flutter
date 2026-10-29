import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../models/taxi_owner_model.dart';

class TaxiPhotoResult {
  final String? photoUrl;
  final String? status;
  const TaxiPhotoResult({this.photoUrl, this.status});
}

class TaxiRepository {
  const TaxiRepository();

  TaxiOwnerModel? _parse(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? TaxiOwnerModel.fromJson(data) : null;
  }

  Future<TaxiOwnerModel?> getMine() async => _parse(await ApiService.get('/taxis/me'));

  Future<TaxiOwnerModel?> saveBasic(Map<String, dynamic> body) async =>
      _parse(await ApiService.put('/taxis/me/basic', body));

  Future<TaxiPhotoResult> uploadPlatePhoto(String filePath, {void Function(int, int)? onProgress}) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
    });
    final res = await ApiService.postFormData('/taxis/me/plate-photo', formData, onSendProgress: onProgress);
    final data = res['data'];
    if (data is Map<String, dynamic>) {
      return TaxiPhotoResult(photoUrl: data['photoUrl'] as String?, status: data['status'] as String?);
    }
    return const TaxiPhotoResult();
  }

  Future<TaxiOwnerModel?> saveRoutes(List<Map<String, dynamic>> routes) async =>
      _parse(await ApiService.put('/taxis/me/routes', {'routes': routes}));

  Future<TaxiOwnerModel?> updateFare(String routeId, int fare) async =>
      _parse(await ApiService.put('/taxis/me/routes/$routeId/fare', {'fare': fare}));

  Future<TaxiOwnerModel?> submit() async => _parse(await ApiService.post('/taxis/me/submit', {}));

  Future<TaxiOwnerModel?> setAvailable(bool available) async =>
      _parse(await ApiService.put('/taxis/me/availability', {'isAvailable': available}));

  Future<void> deleteTaxi() => ApiService.delete('/taxis/me');
}
