import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../config/app_routes.dart';
import '../utils/app_toast.dart';
import 'listing_controller.dart';
import '../services/banner_hub_service.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;
  final user = Rxn<UserModel>();
  final tabIndex = 0.obs;
  final profileTabTrigger = 0.obs;

  // Granular profile observables — each fires only when its specific field changes
  final profileName = ''.obs;
  final profilePhone = ''.obs;
  final profilePhoneVerified = false.obs;
  final profilePhoneChangeLocked = false.obs;

  void _syncProfileFields(UserModel? u) {
    profileName.value = u?.name ?? '';
    profilePhone.value = u?.phoneNumber ?? '';
    profilePhoneVerified.value = u?.isPhoneVerified ?? false;
    profilePhoneChangeLocked.value = u?.hasUsedPhoneChange ?? false;
  }

  @override
  void onInit() {
    super.onInit();
    user.value = StorageService.getUser();
    _syncProfileFields(user.value);
  }

  // ── Phone Login ───────────────────────────────────────────────────────────

  Future<bool> sendLoginOtp(String phone) async {
    try {
      isLoading.value = true;
      await ApiService.post('/auth/phone/send-otp', {'phoneNumber': phone});
      return true;
    } catch (e) {
      AppToast.error(_otpSendError(e));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Returns null on success (login), 'onboarding' if new user, error string on failure.
  Future<String?> verifyLoginOtp(String phone, String otp) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/auth/phone/verify-otp', {
        'phoneNumber': phone,
        'otp': otp,
      });
      final data = res['data'] as Map<String, dynamic>;
      final needsOnboarding = data['needsOnboarding'] as bool? ?? false;
      if (needsOnboarding) return 'onboarding';
      await _saveSession(data);
      Get.offAllNamed(AppRoutes.main);
      return null;
    } catch (e) {
      return _otpVerifyError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completePhoneOnboarding({
    required String phone,
    required String name,
  }) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/auth/phone/complete-onboarding', {
        'phoneNumber': phone,
        'name': name,
      });
      await _saveSession(res['data'] as Map<String, dynamic>);
      Get.offAllNamed(AppRoutes.main);
    } catch (e) {
      AppToast.error(_onboardingError(e));
    } finally {
      isLoading.value = false;
    }
  }

  // ── Phone Verification (profile — change number) ──────────────────────────

  /// Returns null on success, error string on failure (409 = phone claimed).
  Future<String?> sendPhoneOtp(String phone) async {
    try {
      isLoading.value = true;
      await ApiService.post('/auth/send-otp', {'phoneNumber': phone});
      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) return 'phone_claimed';
      return _dioMessage(e, 'Could not send OTP. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyPhoneOtp(String phone, String otp) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/auth/verify-phone', {
        'phoneNumber': phone,
        'otp': otp,
      });
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      StorageService.saveUser(updated);
      user.value = updated;
      _syncProfileFields(updated);
      Get.find<UserRepository>().invalidate();
      return true;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        AppToast.warning('This number is already verified by another account.');
      } else {
        AppToast.error(_otpVerifyError(e) ?? 'Invalid or expired OTP.');
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final userData = data['user'] as Map<String, dynamic>;
    await StorageService.saveToken(token);
    final userModel = UserModel.fromJson(userData);
    StorageService.saveUser(userModel);
    user.value = userModel;
    _syncProfileFields(userModel);
    // Register FCM token after login — fire-and-forget, must not block login flow
    NotificationService.to.registerTokenAfterLogin()
        .catchError((e) => debugPrint('FCM token registration failed: $e'));
  }

  Future<void> logout() async {
    isLoading.value = false;
    try {
      await ApiService.post('/auth/logout', {});
    } catch (_) {}
    try {
      await NotificationService.to.clearToken();
    } catch (_) {}
    try {
      await Get.find<BannerHubService>().disconnect();
    } catch (_) {}
    await StorageService.clearAll();
    user.value = null;
    _syncProfileFields(null);
    Get.find<ListingController>().clearData();
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> deleteAccount() async {
    try {
      isLoading.value = true;
      await ApiService.delete('/account');
      await NotificationService.to.clearToken();
      try {
        await Get.find<BannerHubService>().disconnect();
      } catch (_) {}
      await StorageService.clearAll();
      user.value = null;
      _syncProfileFields(null);
      Get.find<ListingController>().clearData();
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      AppToast.error(_dioMessage(e, 'Could not delete account. Please try again.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshProfile() async {
    Get.find<UserRepository>().invalidate();
    try {
      final res = await ApiService.get('/users/profile');
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      StorageService.saveUser(updated);
      user.value = updated;
      _syncProfileFields(updated);
    } catch (_) {}
  }

  Future<bool> updateProfile(String? name, {bool? isContactVisible}) async {
    try {
      isLoading.value = true;
      final body = <String, dynamic>{'name': name};
      if (isContactVisible != null) body['isContactVisible'] = isContactVisible;
      final res = await ApiService.put('/users/profile', body);
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      StorageService.saveUser(updated);
      user.value = updated;
      profileName.value = updated.name ?? '';
      Get.find<UserRepository>().invalidate();
      return true;
    } catch (e) {
      AppToast.error(_dioMessage(e, 'Could not update profile.'));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Error helpers ─────────────────────────────────────────────────────────

  static String _retryAfter(DioException e) {
    final raw = e.response?.headers.value('retry-after');
    final seconds = raw != null ? int.tryParse(raw) : null;
    if (seconds == null || seconds <= 0) return '1 hour';
    final totalMinutes = (seconds / 60).ceil();
    if (totalMinutes < 60) return '$totalMinutes minute${totalMinutes == 1 ? '' : 's'}';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '$hours hour${hours == 1 ? '' : 's'}';
    return '$hours hour${hours == 1 ? '' : 's'} $mins minute${mins == 1 ? '' : 's'}';
  }

  static String _otpSendError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 429) return 'OTP limit reached. Try again in ${_retryAfter(e)}.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final message = e.response?.data?['error']?['message'] as String?;
      return message ?? 'Failed to send OTP. Please try again.';
    }
    return 'Failed to send OTP. Please try again.';
  }

  static String? _otpVerifyError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 429) return 'Too many attempts. Try again in ${_retryAfter(e)}.';
      if (status == 400) return 'Incorrect OTP. Please check and try again.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final message = e.response?.data?['error']?['message'] as String?;
      return message ?? 'Invalid or expired OTP. Please try again.';
    }
    return 'Invalid or expired OTP. Please try again.';
  }

  static String _onboardingError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 409) {
        final message = e.response?.data?['error']?['message'] as String?;
        return message ?? 'This phone number is not available. Please try another.';
      }
      if (status == 400) {
        final message = e.response?.data?['error']?['message'] as String?;
        return message ?? 'Invalid details. Please check and try again.';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
    }
    return 'Could not complete sign up. Please try again.';
  }

  static String _dioMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final status = e.response?.statusCode;
      final message = e.response?.data?['error']?['message'] as String?;
      if (status == 400 && message != null) return message;
      if (status == 429) return 'Too many attempts. Please try again later.';
      if (status != null && status >= 500) return 'Server error. Please try again.';
      if (message != null) return message;
    }
    return fallback;
  }
}
