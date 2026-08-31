import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../config/app_constants.dart';
import '../models/city_model.dart';
import '../models/go_live_result.dart';
import '../models/listing_model.dart';
import '../repositories/listing_repository.dart';
import '../repositories/wallet_repository.dart';
import '../controllers/wallet_controller.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';
import '../utils/dio_error_mapper.dart';
import '../utils/network_retry.dart';

class ListingController extends GetxController {
  bool hasLoadedMyListings = false;

  final myListings = <ListingModel>[].obs;
  final nearbyListings = <NearbyListingModel>[].obs;
  final nearestListings = <NearbyListingModel>[].obs;
  final isLoadingNearest = false.obs;
  final nearestActive = false.obs;
  final nearestFocusIndex = 0.obs;
  int _nearestRequestSeq = 0;

  void clearNearest() {
    nearestListings.value = [];
    nearestFocusIndex.value = 0;
  }

  final roomTypes = <RoomTypeModel>[].obs;
  final roomTypesLoading = false.obs;
  final isLoading = false.obs;
  final isDeleting = false.obs;
  final isUploading = false.obs;
  final isTogglingActive = false.obs;
  final isSharing = false.obs;
  final hasMoreMyListings = false.obs;
  final listingPostedTrigger = 0.obs;
  final exploreRefreshTrigger = 0.obs;
  final filterResetTrigger = 0.obs;
  /// Bumped ONLY by toggleActive() after the server confirms an active-status
  /// change — unlike exploreRefreshTrigger (also bumped on every Rooms/Plots
  /// tab switch by main_screen.dart, for Explore's own unrelated needs), this
  /// is the narrow signal HomeController listens to, so it never reloads on
  /// bare navigation.
  final listingStatusChangedTrigger = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadRoomTypes();
    loadMyListings();
  }

  Future<void> loadRoomTypes() async {
    try {
      roomTypesLoading.value = true;
      final res = await withRetry(() => ApiService.get('/admin/room-types'));
      roomTypes.value = (res['data'] as List).map((e) => RoomTypeModel.fromJson(e)).toList();
    } catch (_) {
    } finally {
      roomTypesLoading.value = false;
    }
  }

  Future<void> loadNearby(double lat, double lng, double radius, String districtId) async {
    try {
      isLoading.value = true;
      final res = await withRetry(() => ApiService.get('/listings/nearby', params: {
        'latitude': lat,
        'longitude': lng,
        'radius': radius,
        'districtId': districtId,
      }));
      nearbyListings.value = (res['data']['items'] as List).map((e) => NearbyListingModel.fromJson(e)).toList();
    } catch (e) {
      // A 401 here means the interceptor has already run forceLogout(sessionExpired) and shown
      // its own toast + redirected — showing a second, contradictory toast on top would be wrong.
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not load nearby rooms.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadNearest(double lat, double lng, String districtId) async {
    final seq = ++_nearestRequestSeq;
    try {
      isLoadingNearest.value = true;
      final res = await withRetry(() => ApiService.get('/listings/nearest', params: {
        'latitude': lat,
        'longitude': lng,
        'count': AppConstants.nearestFallbackCount,
        'districtId': districtId,
      }));
      final items = (res['data']['items'] as List).map((e) => NearbyListingModel.fromJson(e)).toList();
      if (seq != _nearestRequestSeq) return;
      if (items.isEmpty) {
        AppToast.info('No rooms available in this district yet.', alignment: Alignment.center, compact: true);
        return;
      }
      nearestListings.value = items;
      nearestActive.value = true;
      nearestFocusIndex.value = 0;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not load nearest rooms.'));
    } finally {
      isLoadingNearest.value = false;
    }
  }

  Future<bool> loadMyListings({int page = 1}) async {
    try {
      if (page == 1) myListings.clear();
      isLoading.value = true;
      final res = await withRetry(() => ApiService.get('/listings/my', params: {'page': page, 'pageSize': 10}));
      final items = (res['data']['items'] as List).map((e) => ListingModel.fromJson(e)).toList();
      if (page == 1) {
        myListings.value = items;
      } else {
        myListings.addAll(items);
      }
      hasMoreMyListings.value = res['data']['hasMore'] == true;
      hasLoadedMyListings = true;
      return true;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return false;
      AppToast.error('Could not load your rooms. Pull to refresh.');
      return false;
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
        } else if (e.response?.statusCode != 404 && e.response?.statusCode != 401) {
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
      if (e is DioException && e.response?.statusCode == 401) return null;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not create listing.'));
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

  /// Deactivation only — turning a listing OFF is always free and never
  /// touches ValidUntil, so a later go-live within the same paid window
  /// reactivates for free too (server-enforced: PUT with isActive:true now
  /// 400s, telling callers to use POST /go-live instead).
  Future<void> toggleActive(String id, bool isActive) async {
    try {
      isTogglingActive.value = true;
      await ApiService.put('/listings/$id', {'isActive': !isActive});
      AppToast.success('Listing hidden.');
      nearbyListings.removeWhere((l) => l.id == id);
      exploreRefreshTrigger.value++;
      listingStatusChangedTrigger.value++;
      await loadMyListings();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not update listing status.'));
    } finally {
      isTogglingActive.value = false;
    }
  }

  Future<void> deleteListing(String id) async {
    try {
      isDeleting.value = true;
      await ApiService.delete('/listings/$id');
      myListings.removeWhere((l) => l.id == id);
      nearbyListings.removeWhere((l) => l.id == id);
      AppToast.success('Listing removed successfully.');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not delete listing.'));
    } finally {
      isDeleting.value = false;
    }
  }

  /// POST /listings/{id}/go-live. Pass [planType] null for a free
  /// reactivation of a listing still within its previously-paid ValidUntil
  /// window; pass it (and the credit cost of that plan, so an
  /// INSUFFICIENT_BALANCE result can report it) when going live for the
  /// first time or after expiry. On success, refreshes myListings and the
  /// wallet balance (a spend just happened).
  Future<GoLiveResult> goLive(String listingId, {String? planType, int requiredCredits = 0}) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/listings/$listingId/go-live', {'planType': planType});
      final data = res['data'];
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Invalid response from server');
      }
      listingPostedTrigger.value++;
      await loadMyListings();
      // The response already carries the authoritative post-spend balance — apply it directly
      // instead of triggering a separate (cache-prone, previously-buggy) refresh call.
      final newBalance = (data['balance'] as num?)?.toInt() ?? 0;
      Get.find<WalletController>().applyBalanceUpdate(newBalance, reason: 'golive');
      // A first-time (or never-approved) Go-Live now submits for admin review instead of
      // activating immediately — isActive stays false and the server marks status Pending.
      if (data['isActive'] == false && data['status'] == 'Pending') {
        return GoLiveSubmittedForReview(creditsSpent: (data['creditsSpent'] as num?)?.toInt() ?? 0);
      }
      return GoLiveSuccess(
        validUntil: data['validUntil'] != null ? DateTime.tryParse(data['validUntil'] as String) : null,
        planType: data['planType'] as String?,
        balance: newBalance,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final responseData = e.response?.data;
      String? message;
      String? type;
      if (responseData is Map<String, dynamic>) {
        final error = responseData['error'];
        if (error is Map<String, dynamic>) {
          message = error['message'] as String?;
          type = error['type'] as String?;
        }
        message ??= responseData['message'] as String?;
      }
      if (status == 409 && type == 'INSUFFICIENT_BALANCE') {
        // Balance may have changed since this attempt started (spent elsewhere, admin
        // debit, another device) — invalidate the cache and refresh before returning so the
        // insufficient-balance sheet shows the real current shortfall, not a stale cached value.
        // Must be awaited (unlike the response-driven update on the success branch above) since
        // the caller reads WalletController.balance.value synchronously right after this returns.
        Get.find<WalletRepository>().invalidateBalance();
        await Get.find<WalletController>().loadBalance();
        return GoLiveInsufficientBalance(message: message ?? 'Insufficient balance.', requiredCredits: requiredCredits);
      }
      if (status == 409 && type == 'CONCURRENT_UPDATE') {
        return GoLiveConcurrentUpdate(message ?? 'This listing was just modified by another request. Please retry.');
      }
      return GoLiveFailure(DioErrorMapper.toMessage(e, 'Could not go live. Please try again.'));
    } catch (_) {
      return GoLiveFailure('Could not go live. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, Map<String, dynamic>>> getPlans() =>
      Get.find<ListingRepository>().getPlans();
}
