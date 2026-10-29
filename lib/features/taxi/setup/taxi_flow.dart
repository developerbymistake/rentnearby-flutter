import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import 'taxi_repository.dart';

class TaxiFlow {
  static bool _busy = false;

  static Future<void> start() async {
    if (_busy || !Get.find<AuthController>().canListTaxis.value) return;
    _busy = true;
    try {
      final taxi = await const TaxiRepository().getMine();
      if (taxi != null && taxi.isPendingReview) {
        AppToast.info('Your taxi is under review');
        Get.toNamed(AppRoutes.myTaxi);
        return;
      }
      if (taxi != null && taxi.isApproved) {
        Get.toNamed(AppRoutes.myTaxi);
        return;
      }
      Get.toNamed(AppRoutes.taxiSetup, arguments: {'fromMyTaxi': true});
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not open taxi setup.'));
    } finally {
      _busy = false;
    }
  }
}
