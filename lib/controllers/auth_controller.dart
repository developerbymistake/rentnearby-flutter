import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../utils/app_toast.dart';
import '../services/hub_session_manager.dart';

/// What triggered a logout — decides whether the server-side revoke call fires and which (if
/// any) toast is shown. Kept as a typed reason rather than booleans so each of the 3 real-world
/// triggers (explicit tap, account deletion, a server-forced 401) is unambiguous at the call site.
enum LogoutReason { explicitLogout, accountDeleted, sessionExpired }

class AuthController extends GetxController {
  final isLoading = false.obs;
  final user = Rxn<UserModel>();
  final tabIndex = AppTabs.home.obs;
  final profileTabTrigger = 0.obs;

  // Granular profile observables — each fires only when its specific field changes
  final profileName = ''.obs;
  final profilePhone = ''.obs;
  final profilePhoneVerified = false.obs;
  final profilePhoneChangeLocked = false.obs;

  // Set right after a brand-new account finishes onboarding, consumed exactly once by
  // WalletController's first loadBalance() on MainScreen mount — that's what turns the
  // silent server-side welcome-bonus credit into a one-time "100 coins added!" toast,
  // without a dedicated backend endpoint for it. Never true for a returning login.
  bool justSignedUp = false;

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
      justSignedUp = true;
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

  // The one shared cleanup routine for every logout trigger — explicit logout, account deletion,
  // and a server-forced 401 (revoked session) all funnel through here via ApiService's
  // single-flight guard, so a burst of concurrent 401s (there are ~10+ authenticated calls at
  // app start) can never race each other or diverge from what an explicit logout does.
  Future<void> forceLogout({required LogoutReason reason}) {
    return ApiService.runExclusiveLogout(() => _performLogoutCleanup(reason));
  }

  Future<void> _performLogoutCleanup(LogoutReason reason) async {
    // Timeout + catch-all: the redirect below must run even if a cleanup step hangs or throws,
    // or a revoked session leaves the app permanently stuck on the current screen.
    try {
      await Future(() async {
        if (reason == LogoutReason.explicitLogout) {
          // Fire-and-forget, same pattern as _saveSession's FCM registration below — best-effort
          // server-side revoke that must never block or fail local cleanup. Not awaited: by the
          // time this runs, ApiService.runExclusiveLogout has ALREADY claimed the single-flight
          // slot (that claim happens synchronously, several stack frames earlier in logout(),
          // before this deferred Future's computation even starts) — so if this POST itself
          // 401s, the interceptor's onError finds _logoutInFlight already non-null and just
          // awaits it, never re-entering with a different reason/toast. Holds by call-stack
          // causality, not by any assumption about microtask/macrotask scheduling order.
          ApiService.post('/auth/logout', {}).catchError((_) => <String, dynamic>{});
        }
        try {
          await NotificationService.to.clearToken();
        } catch (_) {}
        try {
          await NotificationService.to.clearDistrictTopic();
        } catch (_) {}
        await disconnectAllHubs();
        await NotificationService.to.cancelAllChatNotifications();
        await StorageService.clearAll();
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
    user.value = null;
    _syncProfileFields(null);
    if (reason == LogoutReason.sessionExpired) {
      try {
        AppToast.info('Session expired. Please log in again.');
      } catch (_) {}
    }
    Get.offAllNamed(AppRoutes.login);
    // Deliberately force:false (the default) — GetX's own delete() bypasses BOTH the permanent
    // check AND the GetxServiceMixin check when force:true, which would delete AuthController
    // itself (a GetxController marked permanent) and every hub service (GetxService) mid-call.
    // With force:false, permanent-marked instances and anything extending GetxService are
    // correctly spared, while every plain GetxController — every data controller/repository
    // registered in MainScreen.initState() — still gets wiped. This is the single place that
    // guarantees the next login on the same device never inherits a prior account's in-memory
    // state, without having to remember to hand-add a reset call per controller.
    Get.deleteAll();
  }

  Future<void> logout() {
    isLoading.value = false;
    return forceLogout(reason: LogoutReason.explicitLogout);
  }

  Future<void> deleteAccount() async {
    try {
      isLoading.value = true;
      await ApiService.delete('/account');
      await forceLogout(reason: LogoutReason.accountDeleted);
    } catch (e) {
      // A 401 here means the interceptor has already run forceLogout(sessionExpired) and shown
      // its own toast + redirected — showing "Could not delete account" on top would be a
      // second, contradictory toast on the login screen for the same underlying event.
      if (e is DioException && e.response?.statusCode == 401) return;
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

  // Two independent actions (edit-name sheet, visibility-confirm sheet on ProfileScreen), two
  // independent endpoints — deliberately not one combined "update profile" call, so editing your
  // name never has to know or care about the visibility toggle's state and vice versa.
  Future<bool> updateName(String name) async {
    try {
      isLoading.value = true;
      final res = await ApiService.put('/users/profile/name', {'name': name});
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      StorageService.saveUser(updated);
      user.value = updated;
      _syncProfileFields(updated);
      Get.find<UserRepository>().invalidate();
      return true;
    } catch (e) {
      AppToast.error(_dioMessage(e, 'Could not update name.'));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateContactVisibility(bool isContactVisible) async {
    try {
      isLoading.value = true;
      final res = await ApiService.put('/users/profile/contact-visibility', {'isContactVisible': isContactVisible});
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      StorageService.saveUser(updated);
      user.value = updated;
      _syncProfileFields(updated);
      Get.find<UserRepository>().invalidate();
      return true;
    } catch (e) {
      AppToast.error(_dioMessage(e, 'Could not update contact visibility.'));
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
