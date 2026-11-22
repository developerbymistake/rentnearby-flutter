import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/trip_strings.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../stay_owner/strings/stay_setup_strings.dart';
import '../guest/stay_landing_controller.dart';
import '../guest/v2/stay_landing_controller_v2.dart';
import '../models/stay_owner_model.dart';
import 'stay_repository.dart';

class StaySetupController extends GetxController {
  static StaySetupController ensure() =>
      Get.isRegistered<StaySetupController>() ? Get.find<StaySetupController>() : Get.put(StaySetupController());

  StaySetupController({StayRepository? repo}) : _repo = repo ?? const StayRepository();

  final StayRepository _repo;
  final stay = Rxn<StayOwnerModel>();
  final isLoading = false.obs;
  final hasLoaded = false.obs;
  final loadFailed = false.obs;
  final isSaving = false.obs;
  bool mainBelow = false;
  String? lastErrorType;
  String? lastErrorMessage;
  bool lastCanUpgrade = false;
  bool lastNetwork = false;

  static const _stayErrorTypes = {'StayStepLocked', 'StayLocked', 'StayNotApproved', 'StayAlreadyExists', 'StayRoomLimit', 'StayRegistrationRequired', 'StayOutsideDistrict'};

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

  Future<bool> saveShareDetails({String? upiId, String? whatsAppNumber}) =>
      _mutate(() => _repo.saveShareDetails(upiId: upiId, whatsAppNumber: whatsAppNumber), TripStrings.couldNotLoad);

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

  // Silent: the screen shows one line for the whole batch (G5, the server line, or no connection).
  Future<bool> uploadPhoto(String filePath, {void Function(int, int)? onProgress}) async {
    _resetError();
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
    _readError(lastError);
    return false;
  }

  Future<bool> replacePhoto(String photoId, String filePath, {void Function(int, int)? onProgress}) async {
    _resetError();
    const maxAttempts = 3;
    var attempt = 0;
    dynamic lastError;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        await _repo.replacePhoto(photoId, filePath, onProgress: onProgress);
        return true;
      } catch (e) {
        lastError = e;
        if (!DioErrorMapper.isNetworkError(e)) break;
        if (attempt < maxAttempts) await Future.delayed(Duration(seconds: attempt));
      }
    }
    _readError(lastError);
    return false;
  }

  // A plan limit refusal: the limit sheet when the server says Plus would help, else its one line.
  Future<void> showLimitRefusal(BuildContext context, GateSpec Function() gate) async {
    if (lastCanUpgrade && PlanGate.canUpgrade) {
      await PlanGate.showLimit(context, gate());
      return;
    }
    final m = lastErrorMessage;
    if (m != null && m.isNotEmpty) AppToast.info(m);
  }

  void _resetError() {
    lastErrorType = null;
    lastErrorMessage = null;
    lastCanUpgrade = false;
    lastNetwork = false;
  }

  void _readError(dynamic e) {
    lastErrorType = DioErrorMapper.errorType(e);
    lastErrorMessage = DioErrorMapper.serverMessage(e);
    lastNetwork = DioErrorMapper.isNetworkError(e);
    final body = e is DioException ? e.response?.data : null;
    final data = body is Map<String, dynamic> ? body['data'] : null;
    lastCanUpgrade = data is Map && data['canUpgrade'] == true;
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
    _resetError();
    try {
      isSaving.value = true;
      final updated = await call();
      final current = stay.value;
      stay.value = updated == null ? await _repo.getMine() : (current == null ? updated : current.mergeFrom(updated));
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
    if (Get.isRegistered<StayLandingControllerV2>(tag: StayLandingControllerV2.tag)) Get.find<StayLandingControllerV2>(tag: StayLandingControllerV2.tag).stayPostedTrigger.value++;
    if (Get.isRegistered<StayLandingController>(tag: 'stays')) {
      Get.find<StayLandingController>(tag: 'stays').stayPostedTrigger.value++;
    }
  }

  void _handleError(dynamic e, String fallback) {
    _readError(e);
    if (e is DioException && e.response?.statusCode == 401) return;
    if (DioErrorMapper.isNetworkError(e)) {
      AppToast.error(StaySetupStrings.noConnection);
      return;
    }
    if (lastErrorType == 'OnboardingClosed' || lastErrorType == 'StayOutsideDistrict') return;
    if (lastErrorType == 'PlanRoomTypeLimit' || lastErrorType == 'PlanPhotoLimit') return;
    if (lastErrorType == 'StayNeedsPhoto') {
      AppToast.warning(StaySetupStrings.keepOnePhoto);
      return;
    }
    if (_stayErrorTypes.contains(lastErrorType)) {
      AppToast.warning(DioErrorMapper.toMessage(e, fallback));
      return;
    }
    AppToast.error(DioErrorMapper.toMessage(e, fallback));
  }
}
