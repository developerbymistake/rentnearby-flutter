import 'package:get/get.dart';

import '../../owner_core/data/owner_result.dart';
import 'stay_ring_api.dart';

/// The Stay Owner's own "Ring me for new enquiries" switch, stored on the server (default on).
class StayRingSettingsController extends GetxController {
  static StayRingSettingsController get to =>
      Get.isRegistered<StayRingSettingsController>() ? Get.find<StayRingSettingsController>() : Get.put(StayRingSettingsController());

  final enabled = true.obs;
  final settings = Rxn<StayRingSettings>();
  final loaded = false.obs;
  final loadFailed = false.obs;
  final saving = false.obs;

  void _apply(StayRingSettings s) {
    settings.value = s;
    enabled.value = s.ringOn;
    loaded.value = true;
  }

  Future<void> load() async {
    loadFailed.value = false;
    final r = await StayRingApi.load();
    if (isClosed) return;
    switch (r) {
      case OwnerOk<StayRingSettings>(:final value):
        _apply(value);
      default:
        loadFailed.value = true;
    }
  }

  /// True when the server saved [on]; the switch goes back on any failure.
  Future<bool> setEnabled(bool on) async {
    if (saving.value) return false;
    final before = enabled.value;
    saving.value = true;
    enabled.value = on;
    try {
      final r = await StayRingApi.save(on);
      if (isClosed) return false;
      if (r case OwnerOk<StayRingSettings>(:final value)) {
        _apply(value);
        return true;
      }
      enabled.value = before;
      return false;
    } finally {
      if (!isClosed) saving.value = false;
    }
  }
}
