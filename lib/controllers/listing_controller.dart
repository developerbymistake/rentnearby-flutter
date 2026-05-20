import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../models/listing_model.dart';
import '../models/city_model.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';

class LocationContext {
  final DistrictModel district;
  final CityModel? nearestCity;
  const LocationContext({required this.district, this.nearestCity});
}

class ListingController extends GetxController {
  final myListings = <ListingModel>[].obs;
  final nearbyListings = <NearbyListingModel>[].obs;
  final districts = <DistrictModel>[].obs;
  final cities = <CityModel>[].obs;       // AddListingScreen: district-based city list
  final nearbyCities = <CityModel>[].obs; // ExploreScreen: location-based city list
  final roomTypes = <RoomTypeModel>[].obs;
  final isLoading = false.obs;
  final isUploading = false.obs;
  final hasMoreMyListings = false.obs;
  final listingPostedTrigger = 0.obs;
  final exploreRefreshTrigger = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadMasterData();
  }

  Future<void> loadMasterData() async {
    try {
      final results = await Future.wait([
        ApiService.get('/admin/districts'),
        ApiService.get('/admin/room-types'),
      ]);
      districts.value = (results[0]['data'] as List).map((e) => DistrictModel.fromJson(e)).toList();
      roomTypes.value = (results[1]['data'] as List).map((e) => RoomTypeModel.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<LocationContext?> loadContext(double lat, double lng) async {
    try {
      final res = await ApiService.get('/listings/context', params: {'lat': lat, 'lng': lng});
      final data = res['data'];
      final district = DistrictModel.fromJson(data['district'] as Map<String, dynamic>);
      nearbyCities.value = (data['cities'] as List).map((e) => CityModel.fromJson(e as Map<String, dynamic>)).toList();
      final nearestCityId = data['nearestCityId'] as String?;
      final nearestCity = nearestCityId != null ? nearbyCities.firstWhereOrNull((c) => c.id == nearestCityId) : nearbyCities.firstOrNull;
      return LocationContext(district: district, nearestCity: nearestCity);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadCities(String districtId) async {
    try {
      final res = await ApiService.get('/admin/cities', params: {'districtId': districtId});
      cities.value = (res['data'] as List).map((e) => CityModel.fromJson(e)).toList();
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not load cities.'));
    }
  }

  Future<void> loadNearby(double lat, double lng, double radius, String cityId) async {
    try {
      isLoading.value = true;
      final res = await ApiService.get('/listings/nearby', params: {
        'latitude': lat,
        'longitude': lng,
        'radius': radius,
        'cityId': cityId,
      });
      nearbyListings.value = (res['data']['items'] as List).map((e) => NearbyListingModel.fromJson(e)).toList();
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not load nearby rooms.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMyListings({int page = 1}) async {
    try {
      isLoading.value = true;
      final res = await ApiService.get('/listings/my', params: {'page': page, 'pageSize': 10});
      final items = (res['data']['items'] as List).map((e) => ListingModel.fromJson(e)).toList();
      if (page == 1) {
        myListings.value = items;
      } else {
        myListings.addAll(items);
      }
      hasMoreMyListings.value = res['data']['hasMore'] == true;
    } catch (_) {
      AppToast.error('Could not load your rooms. Pull to refresh.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<ListingModel?> getById(String id) async {
    try {
      final res = await ApiService.get('/listings/$id');
      return ListingModel.fromJson(res['data']);
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          AppToast.error('No internet connection. Please check your network.');
        } else if (e.response?.statusCode != 404) {
          AppToast.error('Could not load room. Please try again.');
        }
      }
      return null;
    }
  }

  Future<String?> createListing(Map<String, dynamic> data) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/listings/', data);
      final listingId = res['data']?['listingId'] as String?;
      // Note: Do NOT trigger listingPostedTrigger here
      // Let AddListingScreen control when to notify (after photos are uploaded or skipped)
      return listingId;
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not create listing.'));
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  void notifyListingPosted() {
    listingPostedTrigger.value++;
  }

  Future<bool> uploadPhoto(String listingId, String filePath, {void Function(int, int)? onProgress}) async {
    isUploading.value = true;
    const maxAttempts = 3;
    int attempt = 0;
    dynamic lastError;

    try {
      while (attempt < maxAttempts) {
        attempt++;
        try {
          final formData = FormData.fromMap({
            'photo': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
          });
          await ApiService.postFormData(
            '/listings/$listingId/photos',
            formData,
            onSendProgress: onProgress,
          );
          return true;
        } catch (e) {
          lastError = e;
          final isRetriable = e is DioException &&
              (e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.receiveTimeout ||
                  e.type == DioExceptionType.connectionError ||
                  e.type == DioExceptionType.sendTimeout);
          // Immediately fail on non-retriable errors (4xx, etc.)
          if (!isRetriable) break;
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(seconds: attempt));
          }
        }
      }

      String msg;
      if (lastError is DioException) {
        final status = lastError.response?.statusCode;
        final body = lastError.response?.data;
        msg = status != null ? 'Server error $status: $body' : 'Network error: ${lastError.message}';
      } else {
        msg = lastError.toString();
      }
      AppToast.error(msg);
      return false;
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await ApiService.put('/listings/$id', {'isActive': !isActive});
      await loadMyListings();
      if (isActive) nearbyListings.removeWhere((l) => l.id == id);
      exploreRefreshTrigger.value++;
    } catch (_) {}
  }

  Future<void> deleteListing(String id) async {
    try {
      await ApiService.delete('/listings/$id');
      myListings.removeWhere((l) => l.id == id);
      nearbyListings.removeWhere((l) => l.id == id);
      AppToast.success('Listing removed successfully.');
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not delete listing.'));
    }
  }

  Future<void> activatePlan(String listingId, String planType) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post(
        '/listings/$listingId/go-live',
        {'planType': planType},
      );

      final data = res['data'];
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Invalid response from server');
      }

      listingPostedTrigger.value++;
      await loadMyListings();
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not activate free plan.'));
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> createPaymentOrder(String listingId, String planType) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post(
        '/listings/$listingId/create-order',
        {'planType': planType},
      );

      final data = res['data'];
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Invalid order response from server');
      }

      final orderId = _safeGetString(data, 'orderId');
      final keyId = _safeGetString(data, 'keyId');
      final amountRaw = data['amount'];

      if (orderId == null || amountRaw == null) {
        throw Exception('Missing order details from server');
      }

      final amount = _safeGetInt(amountRaw);
      if (amount == null) {
        throw Exception('Invalid amount format from server');
      }

      return {
        'orderId': orderId,
        'amount': amount,
        'currency': _safeGetString(data, 'currency') ?? 'INR',
        'keyId': keyId ?? '',
      };
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not create payment order.'));
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyPayment({
    required String listingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post(
        '/listings/$listingId/verify-payment',
        {
          'razorpayOrderId': razorpayOrderId,
          'razorpayPaymentId': razorpayPaymentId,
          'razorpaySignature': razorpaySignature,
        },
      );

      final data = res['data'];
      if (data != null && data is Map<String, dynamic>) {
        final success = data['success'] == true;
        if (success) {
          listingPostedTrigger.value++;
          await loadMyListings();
        } else {
          throw Exception(data['message'] ?? 'Payment verification failed');
        }
      } else {
        throw Exception('Invalid payment response');
      }
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Payment verification failed.'));
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  String? _safeGetString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value : null;
  }

  int? _safeGetInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        return null;
      }
    }
    if (value is double) return value.toInt();
    return null;
  }

  Future<Map<String, dynamic>?> getMembershipStatus() async {
    try {
      final res = await ApiService.get('/listings/payment/status');
      return res['data'];
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createUpgradeOrder(String planType) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/listings/upgrade-plan/create-order', {'planType': planType});
      final data = res['data'] as Map<String, dynamic>;
      return {
        'orderId': data['orderId'] as String,
        'amount': (data['amount'] as num).toInt(),
        'currency': data['currency'] as String? ?? 'INR',
        'keyId': data['keyId'] as String? ?? '',
      };
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not create upgrade order.'));
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyUpgradePayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      await ApiService.post('/listings/upgrade-plan/verify', {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });
      listingPostedTrigger.value++;
      await loadMyListings();
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not verify upgrade payment.'));
      rethrow;
    }
  }

  Future<bool> isPaymentFeatureEnabled() async {
    try {
      final res = await ApiService.get('/admin/payment-feature');
      final data = res['data'];
      return data != null && data is Map<String, dynamic> && (data['isEnabled'] == true);
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, Map<String, dynamic>>> getPlans() async {
    try {
      final res = await ApiService.get('/listings/plans');
      final list = res['data'] as List;
      final result = <String, Map<String, dynamic>>{};
      for (final item in list) {
        final p = Map<String, dynamic>.from(item as Map);
        result[p['planType'] as String] = p;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  void clearData() {
    nearbyListings.clear();
    myListings.clear();
    hasMoreMyListings.value = false;
  }

  static String _errorMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final status = e.response?.statusCode;
      String? message;

      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        message = responseData['error']?['message'] as String? ??
                  responseData['message'] as String?;
      } else if (responseData is String) {
        message = responseData;
      }

      if (status == 400 && message != null) return message;
      if (status == 429) return 'Too many attempts. Please try again later.';
      if (status != null && status >= 500) return 'Server error. Please try again.';
      if (message != null) return message;
    }
    return fallback;
  }
}
