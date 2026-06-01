import 'package:get/get.dart';
import '../models/banner_model.dart';
import '../services/api_service.dart';

class BannerController extends GetxController {
  final activeBanner = Rxn<BannerModel>();

  Future<void> checkBanner(String districtId) async {
    try {
      final res = await ApiService.get(
        '/banners/active',
        params: {'districtId': districtId},
      );
      final data = res['data'];
      activeBanner.value = data != null
          ? BannerModel.fromJson(data as Map<String, dynamic>)
          : null;
    } catch (_) {}
  }

  Future<void> dismiss(String bannerId) async {
    activeBanner.value = null;
    try {
      await ApiService.post('/banners/$bannerId/dismiss', {});
    } catch (_) {}
  }
}
