import 'package:get/get.dart';
import '../../../services/api_service.dart';

class MyEnquiryCountController extends GetxController {
  static MyEnquiryCountController? get maybe =>
      Get.isRegistered<MyEnquiryCountController>() ? Get.find<MyEnquiryCountController>() : null;

  final offers = 0.obs;
  Future<void>? _inFlight;

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  Future<void> refresh() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/trips/enquiries/mine/count');
      final data = res['data'];
      final n = data is Map ? data['offers'] : null;
      if (n is num) offers.value = n.toInt();
    } catch (_) {}
  }

  void apply({required int waiting, required int offers, required int booked}) {
    this.offers.value = offers;
  }

  void clear() => offers.value = 0;
}
