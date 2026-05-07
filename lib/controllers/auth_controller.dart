import 'package:get/get.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/app_routes.dart';
import 'listing_controller.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;
  final user = Rxn<UserModel>();
  final tabIndex = 0.obs;

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
    } catch (_) {
      Get.snackbar('Error', 'Failed to send OTP. Please try again.',
          snackPosition: SnackPosition.BOTTOM);
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
      StorageService.saveToken(token);
      final userModel = UserModel.fromJson(userData);
      StorageService.saveUser(userModel);
      user.value = userModel;
      return true;
    } catch (_) {
      Get.snackbar('Invalid OTP', 'Please enter the correct OTP.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout', {});
    } catch (_) {}
    StorageService.clearAll();
    user.value = null;
    Get.find<ListingController>().clearData();
    Get.offAllNamed(AppRoutes.otp);
  }

  Future<bool> updateProfile(String? name, String? gmailId) async {
    try {
      isLoading.value = true;
      final res = await ApiService.put('/users/profile', {
        if (name != null) 'name': name,
        if (gmailId != null) 'gmailId': gmailId,
      });
      final updated = UserModel.fromJson(res['data']);
      StorageService.saveUser(updated);
      user.value = updated;
      Get.snackbar('Success', 'Profile updated!', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (_) {
      Get.snackbar('Error', 'Could not update profile.', snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
