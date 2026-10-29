import 'package:get/get.dart';
import '../../services/api_service.dart';
import '../../utils/network_retry.dart';
import 'models/stay_type_model.dart';

class StayTypesController extends GetxController {
  static StayTypesController ensure() =>
      Get.isRegistered<StayTypesController>() ? Get.find<StayTypesController>() : Get.put(StayTypesController());

  final types = <StayTypeModel>[].obs;
  final isLoading = false.obs;

  Future<void> load() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      final res = await withRetry(() => ApiService.get('/stays/types'));
      types.value = (res['data'] as List).map((e) => StayTypeModel.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  void ensureLoaded() {
    if (types.isEmpty && !isLoading.value) load();
  }
}
