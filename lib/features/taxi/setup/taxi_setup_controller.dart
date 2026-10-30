import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../guest/taxi_list_controller.dart';
import '../models/taxi_owner_model.dart';
import 'taxi_repository.dart';

class TaxiSetupController extends GetxController {
  static TaxiSetupController ensure() =>
      Get.isRegistered<TaxiSetupController>() ? Get.find<TaxiSetupController>() : Get.put(TaxiSetupController());

  final _repo = const TaxiRepository();
  final taxi = Rxn<TaxiOwnerModel>();
  final isLoading = false.obs;
  final hasLoaded = false.obs;
  final loadFailed = false.obs;
  final isSaving = false.obs;
  bool mainBelow = false;
  String? lastErrorType;
  String? lastErrorMessage;

  static const cipherUnavailableMessage = 'Licence details cannot be saved right now. Try again later.';

  static const _taxiErrorTypes = {
    'TaxiStepLocked',
    'TaxiLocked',
    'TaxiNotApproved',
    'TaxiAlreadyExists',
    'TaxiRouteLimit',
    'TaxiPlateTaken',
    'TaxiBaseOutsideDistrict',
    'TaxiIdentityRequired',
    'IdentityCipherNotConfigured',
  };

  void clear() {
    taxi.value = null;
    hasLoaded.value = false;
  }

  Future<bool> load() async {
    try {
      isLoading.value = true;
      taxi.value = await _repo.getMine();
      hasLoaded.value = true;
      loadFailed.value = false;
      return true;
    } catch (e) {
      loadFailed.value = !hasLoaded.value;
      _handleError(e, 'Could not load your taxi.');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveBasic(Map<String, dynamic> body) =>
      _mutate(() => _repo.saveBasic(body), 'Could not save details.');

  Future<bool> saveRoutes(List<Map<String, dynamic>> routes) =>
      _mutate(() => _repo.saveRoutes(routes), 'Could not save routes.');

  Future<bool> updateFare(String routeId, int fare) =>
      _mutate(() => _repo.updateFare(routeId, fare), 'Could not update the fare.');

  Future<bool> submit() => _mutate(_repo.submit, 'Could not submit your taxi.', awaitProfile: true);

  Future<bool> setAvailable(bool available) =>
      _mutate(() => _repo.setAvailable(available), 'Could not update your taxi.');

  Future<bool> deleteTaxi() async {
    if (isSaving.value) return false;
    try {
      isSaving.value = true;
      await _repo.deleteTaxi();
      taxi.value = null;
      await _afterChange(awaitProfile: false);
      AppToast.success('Taxi deleted.');
      return true;
    } catch (e) {
      _handleError(e, 'Could not delete your taxi.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<TaxiPhotoResult?> uploadPlatePhoto(String filePath, {void Function(int, int)? onProgress}) async {
    const maxAttempts = 3;
    var attempt = 0;
    dynamic lastError;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        return await _repo.uploadPlatePhoto(filePath, onProgress: onProgress);
      } catch (e) {
        lastError = e;
        if (!DioErrorMapper.isNetworkError(e)) break;
        if (attempt < maxAttempts) await Future.delayed(Duration(seconds: attempt));
      }
    }
    _handleError(lastError, 'Could not upload photo.');
    return null;
  }

  Future<bool> _mutate(Future<TaxiOwnerModel?> Function() call, String fallback, {bool awaitProfile = false}) async {
    if (isSaving.value) return false;
    lastErrorType = null;
    lastErrorMessage = null;
    try {
      isSaving.value = true;
      final updated = await call();
      taxi.value = updated ?? await _repo.getMine();
      await _afterChange(awaitProfile: awaitProfile);
      return true;
    } catch (e) {
      _handleError(e, fallback);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _afterChange({required bool awaitProfile}) async {
    final refresh = Get.find<AuthController>().refreshProfile();
    if (awaitProfile) await refresh;
    if (Get.isRegistered<TaxiListController>(tag: TaxiListController.tag)) {
      Get.find<TaxiListController>(tag: TaxiListController.tag).refreshTrigger.value++;
    }
  }

  void _handleError(dynamic e, String fallback) {
    lastErrorType = DioErrorMapper.errorType(e);
    lastErrorMessage = DioErrorMapper.serverMessage(e);
    if (e is DioException && e.response?.statusCode == 401) return;
    if (lastErrorType == 'IdentityCipherNotConfigured') {
      AppToast.warning(cipherUnavailableMessage);
      return;
    }
    if (_taxiErrorTypes.contains(lastErrorType)) {
      AppToast.warning(DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: const {400, 409}));
      return;
    }
    AppToast.error(DioErrorMapper.toMessage(e, fallback));
  }
}
