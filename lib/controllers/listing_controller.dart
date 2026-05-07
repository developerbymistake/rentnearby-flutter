import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../models/listing_model.dart';
import '../models/city_model.dart';
import '../services/api_service.dart';

class ListingController extends GetxController {
  final myListings = <ListingModel>[].obs;
  final nearbyListings = <NearbyListingModel>[].obs;
  final districts = <DistrictModel>[].obs;
  final cities = <CityModel>[].obs;
  final roomTypes = <RoomTypeModel>[].obs;
  final isLoading = false.obs;
  final isUploading = false.obs;
  final hasMoreNearby = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadMasterData();
  }

  Future<void> loadMasterData() async {
    try {
      final districtsRes = await ApiService.get('/admin/districts');
      districts.value = (districtsRes['data'] as List).map((e) => DistrictModel.fromJson(e)).toList();
      final typesRes = await ApiService.get('/admin/room-types');
      roomTypes.value = (typesRes['data'] as List).map((e) => RoomTypeModel.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<void> loadCities(String districtId) async {
    try {
      final res = await ApiService.get('/admin/cities', params: {'districtId': districtId});
      cities.value = (res['data'] as List).map((e) => CityModel.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<void> loadNearby(double lat, double lng, double radius, String districtId, {int page = 1}) async {
    try {
      isLoading.value = true;
      final res = await ApiService.get('/listings/nearby', params: {
        'latitude': lat,
        'longitude': lng,
        'radius': radius,
        'districtId': districtId,
        'page': page,
        'pageSize': 30,
      });
      final items = (res['data'] as List).map((e) => NearbyListingModel.fromJson(e)).toList();
      if (page == 1) {
        nearbyListings.value = items;
      } else {
        nearbyListings.addAll(items);
      }
      hasMoreNearby.value = res['hasMore'] == true;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMyListings() async {
    try {
      isLoading.value = true;
      final res = await ApiService.get('/listings/my');
      myListings.value = (res['data'] as List).map((e) => ListingModel.fromJson(e)).toList();
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<ListingModel?> getById(String id) async {
    try {
      final res = await ApiService.get('/listings/$id');
      return ListingModel.fromJson(res['data']);
    } catch (_) {
      return null;
    }
  }

  Future<String?> createListing(Map<String, dynamic> data) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/listings/', data);
      final listingId = res['data']?['listingId'] as String?;
      await loadMyListings();
      return listingId;
    } catch (_) {
      Get.snackbar('Error', 'Could not create listing.', snackPosition: SnackPosition.BOTTOM);
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> uploadPhoto(String listingId, String filePath) async {
    try {
      isUploading.value = true;
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
      });
      await ApiService.postFormData('/listings/$listingId/photos', formData);
      return true;
    } catch (e) {
      String msg;
      if (e is DioException) {
        final status = e.response?.statusCode;
        final body = e.response?.data;
        msg = status != null ? 'Server error $status: $body' : 'Network error: ${e.message}';
      } else {
        msg = e.toString();
      }
      Get.snackbar('Photo Upload Failed', msg,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 6));
      return false;
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await ApiService.put('/listings/$id', {'isActive': !isActive});
      await loadMyListings();
    } catch (_) {}
  }

  Future<void> deleteListing(String id) async {
    try {
      await ApiService.delete('/listings/$id');
      myListings.removeWhere((l) => l.id == id);
      Get.snackbar('Deleted', 'Listing removed successfully.', snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('Error', 'Could not delete listing.', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void clearData() {
    nearbyListings.clear();
    myListings.clear();
  }
}
