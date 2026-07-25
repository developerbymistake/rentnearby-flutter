import 'package:get/get.dart';
import '../repositories/config_repository.dart';

/// Holds the flat, admin-configured listing-creation caps (GET
/// /config/listing-limits) — the only thing ListingPermissionService and
/// PlotPermissionService need to decide "has this user hit their cap."
/// Loaded once eagerly on put(); `ensureLoaded()` lets callers await the
/// first successful load before reading the Rx values.
class ConfigController extends GetxController {
  final roomLimit = 5.obs;
  final plotLimit = 5.obs;
  final isLoaded = false.obs;

  // Payment kill-switch (GET /config/payment-feature). Defaults to false
  // (no payment UI) so that before the first load completes — or if it
  // never does — the app never flashes payment/credit UI on screen only to
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
    final limits = await repo.getListingLimits();
    roomLimit.value = limits.roomLimit;
    plotLimit.value = limits.plotLimit;
    final paymentFeature = await repo.getPaymentFeature();
    paymentEnabled.value = paymentFeature.enabled;
    freeGoLiveDurationDays.value = paymentFeature.freeGoLiveDurationDays;
    isLoaded.value = true;
  }

  Future<void> ensureLoaded() async {
    if (isLoaded.value) return;
    await _load();
  }
}
