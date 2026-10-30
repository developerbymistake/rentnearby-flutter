import 'package:get/get.dart';
import '../../services/api_service.dart';
import '../../utils/network_retry.dart';
import 'models/stay_registration_type_model.dart';

class StayRegistrationTypesController extends GetxController {
  static StayRegistrationTypesController ensure() => Get.isRegistered<StayRegistrationTypesController>()
      ? Get.find<StayRegistrationTypesController>()
      : Get.put(StayRegistrationTypesController());

  static const _ttl = Duration(hours: 1);

  final types = <StayRegistrationTypeModel>[].obs;
  final isLoading = false.obs;
  DateTime? _loadedAt;

  Future<void> load() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      final res = await withRetry(() => ApiService.get('/stays/registration-types'));
      types.value = (res['data'] as List)
          .map((e) => StayRegistrationTypeModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _loadedAt = DateTime.now();
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  void ensureLoaded() {
    if (isLoading.value) return;
    final at = _loadedAt;
    if (types.isEmpty || at == null || DateTime.now().difference(at) > _ttl) load();
  }
}
