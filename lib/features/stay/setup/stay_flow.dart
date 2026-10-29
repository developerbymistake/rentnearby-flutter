import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import 'stay_repository.dart';

class StayFlow {
  static bool _busy = false;

  static Future<void> start() async {
    if (_busy || !Get.find<AuthController>().staysEnabled) return;
    _busy = true;
    try {
      final stay = await const StayRepository().getMine();
      if (stay != null && (stay.isPendingReview || stay.isApproved)) {
        AppToast.info('One stay per account');
        Get.toNamed(AppRoutes.myStays);
        return;
      }
      Get.toNamed(AppRoutes.staySetup, arguments: {'fromMyStays': true});
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not open stay setup.'));
    } finally {
      _busy = false;
    }
  }
}
