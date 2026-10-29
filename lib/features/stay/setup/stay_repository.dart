import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../models/stay_owner_model.dart';

class StayRepository {
  const StayRepository();

  StayOwnerModel? _parse(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? StayOwnerModel.fromJson(data) : null;
  }

  Future<StayOwnerModel?> getMine() async => _parse(await ApiService.get('/stays/me'));

  Future<StayOwnerModel?> saveBasic(Map<String, dynamic> body) async =>
      _parse(await ApiService.put('/stays/me/basic', body));

  Future<void> uploadPhoto(String filePath, {void Function(int, int)? onProgress}) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
    });
    await ApiService.postFormData('/stays/me/photos', formData, onSendProgress: onProgress);
  }

  Future<void> deletePhoto(String photoId) => ApiService.delete('/stays/me/photos/$photoId');

  Future<StayOwnerModel?> saveRooms(List<Map<String, dynamic>> rooms) async =>
      _parse(await ApiService.put('/stays/me/rooms', {'rooms': rooms}));

  Future<StayOwnerModel?> saveRules(Map<String, dynamic> body) async =>
      _parse(await ApiService.put('/stays/me/rules', body));

  Future<StayOwnerModel?> submit() async => _parse(await ApiService.post('/stays/me/submit', {}));

  Future<StayOwnerModel?> setAccepting(bool accepting) async =>
      _parse(await ApiService.put('/stays/me/accepting', {'acceptingGuests': accepting}));

  Future<StayOwnerModel?> updateRoomPrice(String roomId, int price) async =>
      _parse(await ApiService.put('/stays/me/rooms/$roomId/price', {'pricePerNight': price}));

  Future<void> deleteStay() => ApiService.delete('/stays/me');
}
