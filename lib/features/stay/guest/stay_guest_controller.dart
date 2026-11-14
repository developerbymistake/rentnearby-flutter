import '../../nearby/nearby_strings.dart';
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
  int _nearbyRequestSeq = 0;
  static const _nearbyCacheTtl = Duration(seconds: 60);
  final Map<String, ({List<StayNearbyModel> items, DateTime at})> _nearbyCache = {};

  void clearNearest() {
    nearestStays.value = [];
    nearestFocusIndex.value = 0;
  }

  void clearNearbyCache() => _nearbyCache.clear();

  static String _failText(Object e, String fallback) => DioErrorMapper.toMessage(e, fallback);

  static String _cacheKey(double lat, double lng, double radius) =>
      '${lat.toStringAsFixed(3)}|${lng.toStringAsFixed(3)}|$radius';

  Future<bool> loadNearby(double lat, double lng, double radius, {bool refresh = false}) async {
    final seq = ++_nearbyRequestSeq;
    final key = _cacheKey(lat, lng, radius);
    if (refresh) {
      _nearbyCache.clear();
    } else {
      final hit = _nearbyCache[key];
      if (hit != null && DateTime.now().difference(hit.at) < _nearbyCacheTtl) {
        nearbyStays.value = hit.items;
        isLoading.value = false;
        return true;
      }
    }
    try {
      isLoading.value = true;
      final res = await withRetry(() => ApiService.get('/stays/nearby', params: {
            'latitude': lat,
            'longitude': lng,
            'radius': radius,
          }));
      final items = (res['data']['items'] as List).map((e) => StayNearbyModel.fromJson(e)).toList();
      _nearbyCache[key] = (items: items, at: DateTime.now());
      if (seq == _nearbyRequestSeq) nearbyStays.value = items;
      return true;
    } catch (e) {
      if (seq != _nearbyRequestSeq) return false;
      if (e is DioException && e.response?.statusCode == 401) return false;
      AppToast.error(_failText(e, 'Could not load nearby stays.'));
      return false;
    } finally {
      if (seq == _nearbyRequestSeq) isLoading.value = false;
    }
  }

  Future<void> loadNearest(double lat, double lng) async {
    final seq = ++_nearestRequestSeq;
    try {
      isLoadingNearest.value = true;
      final res = await withRetry(() => ApiService.get('/stays/nearest', params: {
            'latitude': lat,
            'longitude': lng,
            'count': AppConstants.nearestFallbackCount,
          }));
      final items = (res['data']['items'] as List).map((e) => StayNearbyModel.fromJson(e)).toList();
      if (seq != _nearestRequestSeq) return;
      if (items.isEmpty) {
        AppToast.noData(NearbyStrings.staysNearestEmptyTitle, NearbyStrings.staysNearestEmptyBody, accent: StayColors.accent);
        return;
      }
      nearestStays.value = items;
      nearestActive.value = true;
      nearestFocusIndex.value = 0;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(_failText(e, 'Could not load nearest stays.'));
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
