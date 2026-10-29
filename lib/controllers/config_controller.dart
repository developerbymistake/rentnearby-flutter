import 'package:get/get.dart';
import '../repositories/config_repository.dart';

class ConfigController extends GetxController {
  final isLoaded = false.obs;

  // Payment kill-switch (GET /config/payment-feature). Defaults to false
  // (no payment UI) so that before the first load completes — or if it
  // never does — the app never flashes payment UI on screen only to
  // hide it a moment later once the real value arrives.
  final paymentEnabled = false.obs;
  final freeGoLiveDurationDays = 30.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final repo = Get.find<ConfigRepository>();
    final paymentFeature = await repo.getPaymentFeature();
    paymentEnabled.value = paymentFeature.enabled;
    freeGoLiveDurationDays.value = paymentFeature.freeGoLiveDurationDays;
    isLoaded.value = true;
  }

  Future<void> refreshPaymentFeature() async {
    final paymentFeature = await Get.find<ConfigRepository>().getPaymentFeature(forceRefresh: true);
    paymentEnabled.value = paymentFeature.enabled;
    freeGoLiveDurationDays.value = paymentFeature.freeGoLiveDurationDays;
  }

  Future<void> ensureLoaded() async {
    if (isLoaded.value) return;
    await _load();
  }
}
