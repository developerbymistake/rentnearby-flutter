import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../models/banner_model.dart';
import '../services/api_service.dart';

class BannerController extends GetxController {
  final activeBanner = Rxn<BannerModel>();

  static const _storageKey = 'dismissed_banner_ids';
  final _box = GetStorage();

  // In-memory cache — avoids disk read on every isDismissed() check
  late Set<String> _dismissedIds;

  @override
  void onInit() {
    super.onInit();
    final raw = _box.read<List>(_storageKey);
    _dismissedIds = raw != null ? raw.cast<String>().toSet() : {};
  }

  bool isDismissed(String bannerId) => _dismissedIds.contains(bannerId);

  void _saveDismissed(String bannerId) {
    _dismissedIds.add(bannerId);
    _box.write(_storageKey, _dismissedIds.toList());
  }

  // Called only on: app start, district change, WS reconnect, WS connect failure
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

  // Called directly from BannerActivated push — zero REST call
  void applyFromPush(Map<String, dynamic> data) {
    final banner = BannerModel.fromJson(data);
    if (!isDismissed(banner.id)) {
      activeBanner.value = banner;
    }
  }

  Future<void> dismiss(String bannerId) async {
    activeBanner.value = null;
    _saveDismissed(bannerId);
    try {
      await ApiService.post('/banners/$bannerId/dismiss', {});
    } catch (_) {}
  }
}
