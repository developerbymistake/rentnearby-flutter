import 'package:get/get.dart';
import '../services/api_service.dart';

class AppFeatureController extends GetxController {
  final isRoomPaymentEnabled = false.obs;
  final roomPaymentFreeLimit  = 1.obs;
  final isPlotPaymentEnabled = false.obs;
  final plotPaymentFreeLimit  = 1.obs;

  bool _refreshing = false;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final res = await ApiService.get('/admin/features');
      final list = res as List;
      for (final item in list) {
        final key     = item['key'] as String?;
        final enabled = item['isEnabled'] == true;
        final limit   = (item['freeLimit'] as num?)?.toInt() ?? 1;
        if (key == 'room_payment') {
          isRoomPaymentEnabled.value = enabled;
          roomPaymentFreeLimit.value  = limit;
        } else if (key == 'plot_payment') {
          isPlotPaymentEnabled.value = enabled;
          plotPaymentFreeLimit.value  = limit;
        }
      }
    } catch (_) {
    } finally {
      _refreshing = false;
    }
  }

  Future<void> refresh() => _load();
}
