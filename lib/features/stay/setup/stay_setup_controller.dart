import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../guest/stay_landing_controller.dart';
import '../models/stay_owner_model.dart';
import 'stay_repository.dart';

class StaySetupController extends GetxController {
  static StaySetupController ensure() =>
      Get.isRegistered<StaySetupController>() ? Get.find<StaySetupController>() : Get.put(StaySetupController());

  final _repo = const StayRepository();
  final stay = Rxn<StayOwnerModel>();
  final isLoading = false.obs;
  final hasLoaded = false.obs;
  final loadFailed = false.obs;
  final isSaving = false.obs;
  bool mainBelow = false;
  String? lastErrorType;
  String? lastErrorMessage;

  static const _stayErrorTypes = {'StayStepLocked', 'StayLocked', 'StayNotApproved', 'StayAlreadyExists', 'StayRoomLimit', 'StayRegistrationRequired'};

  void clear() {
    stay.value = null;
    hasLoaded.value = false;
  }

  Future<bool> load() async {
    try {
      isLoading.value = true;
      stay.value = await _repo.getMine();
      hasLoaded.value = true;
      loadFailed.value = false;
      return true;
    } catch (e) {
      loadFailed.value = !hasLoaded.value;
      _handleError(e, 'Could not load your stay.');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveBasic(Map<String, dynamic> body) =>
      _mutate(() => _repo.saveBasic(body), 'Could not save details.');

  Future<bool> saveRooms(List<Map<String, dynamic>> rooms) =>
      _mutate(() => _repo.saveRooms(rooms), 'Could not save rooms.');

  Future<bool> saveRules(Map<String, dynamic> body) =>
      _mutate(() => _repo.saveRules(body), 'Could not save rules.');

  Future<bool> submit() => _mutate(_repo.submit, 'Could not submit your stay.', awaitProfile: true);

  Future<bool> setAccepting(bool accepting) =>
      _mutate(() => _repo.setAccepting(accepting), 'Could not update your stay.');

  Future<bool> updateRoomPrice(String roomId, int price) =>
      _mutate(() => _repo.updateRoomPrice(roomId, price), 'Could not update the price.');

  Future<bool> deleteStay() async {
    try {
      isSaving.value = true;
      await _repo.deleteStay();
      stay.value = null;
      await _afterChange(awaitProfile: false);
      AppToast.success('Stay deleted.');
      return true;
    } catch (e) {
      _handleError(e, 'Could not delete your stay.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> uploadPhoto(String filePath, {void Function(int, int)? onProgress}) async {
    const maxAttempts = 3;
    var attempt = 0;
    dynamic lastError;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        await _repo.uploadPhoto(filePath, onProgress: onProgress);
        return true;
      } catch (e) {
        lastError = e;
        if (!DioErrorMapper.isNetworkError(e)) break;
        if (attempt < maxAttempts) await Future.delayed(Duration(seconds: attempt));
      }
    }
    if (!(lastError is DioException && lastError.response?.statusCode == 401)) {
      AppToast.error(DioErrorMapper.toMessage(lastError, 'Could not upload photo.'));
    }
    return false;
  }

  Future<bool> deletePhoto(String photoId) async {
    try {
      await _repo.deletePhoto(photoId);
      return true;
    } catch (e) {
      _handleError(e, 'Could not remove photo.');
      return false;
    }
  }

  Future<bool> _mutate(Future<StayOwnerModel?> Function() call, String fallback, {bool awaitProfile = false}) async {
    lastErrorType = null;
    lastErrorMessage = null;
    try {
      isSaving.value = true;
      final updated = await call();
      stay.value = updated ?? await _repo.getMine();
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
    if (Get.isRegistered<StayLandingController>(tag: 'stays')) {
      Get.find<StayLandingController>(tag: 'stays').stayPostedTrigger.value++;
    }
  }

  void _handleError(dynamic e, String fallback) {
    lastErrorType = DioErrorMapper.errorType(e);
    lastErrorMessage = DioErrorMapper.serverMessage(e);
    if (e is DioException && e.response?.statusCode == 401) return;
    if (_stayErrorTypes.contains(lastErrorType)) {
      AppToast.warning(DioErrorMapper.toMessage(e, fallback));
      return;
    }
    AppToast.error(DioErrorMapper.toMessage(e, fallback));
  }
}
