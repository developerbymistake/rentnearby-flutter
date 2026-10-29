import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../config/app_constants.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/network_retry.dart';
import '../models/stay_detail_model.dart';
import '../models/stay_nearby_model.dart';
import '../setup/stay_option_sets.dart';

class StayGuestController extends GetxController {
  static StayGuestController get to =>
      Get.isRegistered<StayGuestController>() ? Get.find<StayGuestController>() : Get.put(StayGuestController());

  final nearbyStays = <StayNearbyModel>[].obs;
  final nearestStays = <StayNearbyModel>[].obs;
  final isLoading = false.obs;
  final isLoadingNearest = false.obs;
  final nearestActive = false.obs;
  final nearestFocusIndex = 0.obs;
  int _nearestRequestSeq = 0;

  void clearNearest() {
    nearestStays.value = [];
    nearestFocusIndex.value = 0;
  }

  Future<void> loadNearby(double lat, double lng, double radius, String districtId) async {
    try {
      isLoading.value = true;
      final res = await withRetry(() => ApiService.get('/stays/nearby', params: {
            'latitude': lat,
            'longitude': lng,
            'radius': radius,
            'districtId': districtId,
          }));
      nearbyStays.value = (res['data']['items'] as List).map((e) => StayNearbyModel.fromJson(e)).toList();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not load nearby stays.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadNearest(double lat, double lng, String districtId) async {
    final seq = ++_nearestRequestSeq;
    try {
      isLoadingNearest.value = true;
      final res = await withRetry(() => ApiService.get('/stays/nearest', params: {
            'latitude': lat,
            'longitude': lng,
            'count': AppConstants.nearestFallbackCount,
            'districtId': districtId,
          }));
      final items = (res['data']['items'] as List).map((e) => StayNearbyModel.fromJson(e)).toList();
      if (seq != _nearestRequestSeq) return;
      if (items.isEmpty) {
        AppToast.noData('No stays in this district yet', 'Try another city from the header', accent: StayColors.accent);
        return;
      }
      nearestStays.value = items;
      nearestActive.value = true;
      nearestFocusIndex.value = 0;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not load nearest stays.'));
    } finally {
      isLoadingNearest.value = false;
    }
  }

  Future<StayDetailModel?> getById(String id) async {
    try {
      final res = await ApiService.get('/stays/$id');
      return StayDetailModel.fromJson(res['data'] as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          AppToast.error('No internet connection. Please check your network.');
        } else if (e.response?.statusCode != 404 && e.response?.statusCode != 401) {
          AppToast.error('Could not load stay. Please try again.');
        }
      }
      return null;
    }
  }
}
