import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../utils/app_toast.dart';
import 'listing_controller.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;
  final user = Rxn<UserModel>();
  final tabIndex = 0.obs;
  final profileTabTrigger = 0.obs;

  final _googleSignIn = GoogleSignIn(
    serverClientId: AppConstants.googleWebClientId,
    scopes: ['email', 'profile', 'openid'],
  );

  @override
  void onInit() {
    super.onInit();
    user.value = StorageService.getUser();
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      final account = await _googleSignIn.signIn();
      if (account == null) return; // User cancelled

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        AppToast.error('Could not get Google token. Please try again.');
        return;
      }

      final res = await ApiService.post('/auth/google', {'idToken': idToken});
      final data = res['data'] as Map<String, dynamic>;
      final needsOnboarding = data['needsOnboarding'] as bool? ?? false;

      if (needsOnboarding) {
        final profile = data['googleProfile'] as Map<String, dynamic>;
        Get.offAllNamed(AppRoutes.onboarding, arguments: {
          'idToken': idToken,
          'name': profile['name'] ?? '',
          'email': profile['email'] ?? '',
          'photoUrl': profile['photoUrl'],
        });
      } else {
        await _saveSession(data);
        Get.offAllNamed(AppRoutes.main);
      }
    } catch (e) {
      AppToast.error(_dioMessage(e, 'Sign in failed. Please try again.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeOnboarding({
    required String idToken,
    required String name,
    required String phoneNumber,
  }) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/auth/complete-onboarding', {
        'idToken': idToken,
        'name': name,
        'phoneNumber': phoneNumber,
      });
      await _saveSession(res['data'] as Map<String, dynamic>);
      Get.offAllNamed(AppRoutes.main);
    } catch (e) {
      AppToast.error(_onboardingError(e));
    } finally {
      isLoading.value = false;
    }
  }

  // ── Phone Verification ────────────────────────────────────────────────────

  /// Returns null on success, error string on failure (409 = phone claimed).
  Future<String?> sendPhoneOtp(String phone) async {
    try {
      isLoading.value = true;
      await ApiService.post('/auth/send-otp', {'phoneNumber': phone});
      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        return 'phone_claimed';
      }
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
      Get.find<UserRepository>().invalidate();
      return true;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        AppToast.warning('This number is already verified by another account.');
      } else {
        AppToast.error(_otpVerifyError(e));
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
  }

  Future<void> logout() async {
    isLoading.value = false;
    try {
      await ApiService.post('/auth/logout', {});
    } catch (_) {}
    await _googleSignIn.signOut().catchError((_) => null);
    await StorageService.clearAll();
    user.value = null;
    Get.find<ListingController>().clearData();
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> deleteAccount() async {
    try {
      isLoading.value = true;
      await ApiService.delete('/account');
      await _googleSignIn.signOut().catchError((_) => null);
      await StorageService.clearAll();
      user.value = null;
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

  static String _otpVerifyError(dynamic e) {
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
