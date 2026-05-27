import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../models/city_model.dart';
import '../models/plot_model.dart';
import '../repositories/plot_repository.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';

class PlotController extends GetxController {
  final nearbyPlots = <NearbyPlotModel>[].obs;
  final myPlots = <PlotModel>[].obs;
  final plotTypes = <PlotTypeModel>[].obs;
  final isLoading = false.obs;
  final isDeleting = false.obs;
  final isUploading = false.obs;
  final hasMorePlots = false.obs;
  final plotPostedTrigger = 0.obs;
  final exploreRefreshTrigger = 0.obs;
  final filterResetTrigger = 0.obs;
  int _myPlotsPage = 1;

  @override
  void onInit() {
    super.onInit();
    loadPlotTypes();
  }

  Future<void> loadPlotTypes() async {
    try {
      final res = await ApiService.get('/admin/plot-types');
      plotTypes.value = (res['data'] as List).map((e) => PlotTypeModel.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<void> loadNearby(double lat, double lng, double radius, String cityId) async {
    try {
      isLoading.value = true;
      final res = await ApiService.get('/plots/nearby', params: {
        'latitude': lat,
        'longitude': lng,
        'radius': radius,
        'cityId': cityId,
      });
      nearbyPlots.value =
          (res['data']['items'] as List).map((e) => NearbyPlotModel.fromJson(e)).toList();
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not load nearby plots.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMyPlots({bool reset = false}) async {
    try {
      if (reset) {
        _myPlotsPage = 1;
        myPlots.clear();
        hasMorePlots.value = false;
      }
      isLoading.value = true;
      final res = await ApiService.get('/plots/my', params: {'page': _myPlotsPage, 'pageSize': 10});
      final items = (res['data']['items'] as List).map((e) => PlotModel.fromJson(e)).toList();
      if (_myPlotsPage == 1) {
        myPlots.value = items;
      } else {
        myPlots.addAll(items);
      }
      hasMorePlots.value = res['data']['hasMore'] == true;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadNextPage() async {
    if (!hasMorePlots.value || isLoading.value) return;
    _myPlotsPage++;
    await loadMyPlots();
  }

  Future<String?> createPlot(Map<String, dynamic> data) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/plots/', data);
      return res['data']?['plotId'] as String?;
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not create plot.'));
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> uploadPhoto(String plotId, String filePath, {void Function(int, int)? onProgress}) async {
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
            '/plots/$plotId/photos',
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
          if (!isRetriable) break;
          if (attempt < maxAttempts) await Future.delayed(Duration(seconds: attempt));
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

  Future<Map<String, dynamic>> getPlotPaymentFeatureConfig() =>
      Get.find<PlotRepository>().getPlotPaymentFeatureConfig();

  Future<bool> isPlotPaymentFeatureEnabled() async {
    final config = await getPlotPaymentFeatureConfig();
    return config['isEnabled'] as bool;
  }

  Future<List<Map<String, dynamic>>> getPlotPlans() =>
      Get.find<PlotRepository>().getPlotPlans();

  Future<Map<String, dynamic>?> getPlotMembershipStatus() =>
      Get.find<PlotRepository>().getPlotMembershipStatus();

  Future<Map<String, dynamic>?> activatePlotPlan(String plotId, String planType) async {
    try {
      final res = await ApiService.post('/plots/$plotId/create-order?planType=$planType', {});
      return res['data'];
    } catch (_) { return null; }
  }

  Future<bool> verifyPlotPayment(Map<String, dynamic> body) async {
    try {
      await ApiService.post('/plots/${body['plotId']}/verify-payment', body);
      Get.find<PlotRepository>().invalidateMembership();
      plotPostedTrigger.value++;
      await loadMyPlots(reset: true);
      return true;
    } catch (_) { return false; }
  }

  Future<Map<String, dynamic>?> createPlotUpgradeOrder(String planType) async {
    try {
      final res = await ApiService.post('/plots/upgrade-plan/create-order?planType=$planType', {});
      return res['data'];
    } catch (_) { return null; }
  }

  Future<bool> verifyPlotUpgradePayment(Map<String, dynamic> body) async {
    try {
      await ApiService.post('/plots/upgrade-plan/verify', body);
      Get.find<PlotRepository>().invalidateMembership();
      plotPostedTrigger.value++;
      await loadMyPlots(reset: true);
      return true;
    } catch (_) { return false; }
  }

  Future<void> toggleActive(String id, bool currentIsActive) async {
    try {
      await ApiService.put('/plots/$id', {'isActive': !currentIsActive});
      await loadMyPlots(reset: true);
      if (currentIsActive) nearbyPlots.removeWhere((p) => p.id == id);
      exploreRefreshTrigger.value++;
    } catch (_) {}
  }

  Future<void> deletePlot(String id) async {
    try {
      isDeleting.value = true;
      await ApiService.delete('/plots/$id');
      myPlots.removeWhere((p) => p.id == id);
      nearbyPlots.removeWhere((p) => p.id == id);
      AppToast.success('Plot removed successfully.');
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not delete plot.'));
    } finally {
      isDeleting.value = false;
    }
  }

  Future<PlotModel?> getById(String id) async {
    try {
      final res = await ApiService.get('/plots/$id');
      return PlotModel.fromJson(res['data']);
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          AppToast.error('No internet connection. Please check your network.');
        } else if (e.response?.statusCode != 404) {
          AppToast.error('Could not load plot. Please try again.');
        }
      }
      return null;
    }
  }

  void notifyPlotPosted() => plotPostedTrigger.value++;

  void clearData() {
    nearbyPlots.clear();
    myPlots.clear();
    hasMorePlots.value = false;
    _myPlotsPage = 1;
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
