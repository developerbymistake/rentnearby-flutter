import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../repositories/listing_repository.dart';
import '../repositories/plot_repository.dart';
import '../repositories/user_repository.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/app_routes.dart';
import '../utils/app_toast.dart';
import 'listing_controller.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;
  final user = Rxn<UserModel>();
  final tabIndex = 0.obs;
  final profileTabTrigger = 0.obs;

  @override
  void onInit() {
    super.onInit();
    user.value = StorageService.getUser();
  }

  Future<bool> sendOtp(String phone) async {
    try {
      isLoading.value = true;
      await ApiService.post('/auth/send-otp', {'phoneNumber': phone});
      return true;
    } catch (e) {
      AppToast.error(_otpSendError(e));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/auth/verify-otp', {'phoneNumber': phone, 'otp': otp});
      final token = res['data']['token'];
      final userData = res['data']['user'];
      await StorageService.saveToken(token);
      final userModel = UserModel.fromJson(userData);
      StorageService.saveUser(userModel);
      user.value = userModel;
      return true;
    } catch (e) {
      AppToast.error(_otpVerifyError(e));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    isLoading.value = false;
    try {
      await ApiService.post('/auth/logout', {});
    } catch (_) {}
    await StorageService.clearAll();
    user.value = null;
    Get.find<ListingController>().clearData();
    Get.offAllNamed(AppRoutes.otp);
  }

  Future<void> deleteAccount() async {
    try {
      isLoading.value = true;
      await ApiService.delete('/account');
      await StorageService.clearAll();
      user.value = null;
      Get.find<ListingController>().clearData();
      Get.offAllNamed(AppRoutes.otp);
    } catch (e) {
      AppToast.error(_dioMessage(e, 'Could not delete account. Please try again.'));
    } finally {
      isLoading.value = false;
    }
  }

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
      final message = e.response?.data?['message'] as String?;
      return message ?? 'Failed to send OTP. Please try again.';
    }
    return 'Failed to send OTP. Please try again.';
  }

  static String _otpVerifyError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 429) return 'Too many attempts. Try again in ${_retryAfter(e)}.';
      if (status == 400 || status == 401) return 'Incorrect OTP. Please check and try again.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final message = e.response?.data?['message'] as String?;
      return message ?? 'Invalid or expired OTP. Please try again.';
    }
    return 'Invalid or expired OTP. Please try again.';
  }

  static String _dioMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final status = e.response?.statusCode;
      final message = e.response?.data?['message'] as String?;
      if (status == 400 && message != null) return message;
      if (status == 429) return 'Too many attempts. Please try again later.';
      if (status != null && status >= 500) return 'Server error. Please try again.';
      if (message != null) return message;
    }
    return fallback;
  }

  Future<void> refreshProfile() async {
    Get.find<UserRepository>().invalidate();
    try {
      final res = await ApiService.get('/users/profile');
      final updated = UserModel.fromJson(res['data']);
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
      final updated = UserModel.fromJson(res['data']);
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
}
