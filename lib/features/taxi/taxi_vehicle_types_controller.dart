import 'package:get/get.dart';
import '../../services/api_service.dart';
import '../../utils/network_retry.dart';
import 'models/taxi_vehicle_type_model.dart';
import 'taxi_option_sets.dart';

class TaxiVehicleTypesController extends GetxController {
  static TaxiVehicleTypesController ensure() => Get.isRegistered<TaxiVehicleTypesController>()
      ? Get.find<TaxiVehicleTypesController>()
      : Get.put(TaxiVehicleTypesController());

  final types = <TaxiVehicleTypeModel>[].obs;
  final isLoading = false.obs;
  final loadFailed = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      loadFailed.value = false;
      final res = await withRetry(() => ApiService.get('/taxis/vehicle-types'));
      final data = res['data'];
      types.value = data is List
          ? data.map((e) => TaxiVehicleTypeModel.fromJson(e as Map<String, dynamic>)).toList()
          : <TaxiVehicleTypeModel>[];
    } catch (_) {
      loadFailed.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  void ensureLoaded() {
    if (types.isEmpty && !isLoading.value) load();
  }

  Map<String, List<TaxiVehicleTypeModel>> byCategory([String query = '']) {
    final q = query.trim().toLowerCase();
    final out = <String, List<TaxiVehicleTypeModel>>{};
    for (final c in TaxiOptionSets.categories) {
      final rows = types
          .where((t) => t.category == c.value && (q.isEmpty || t.name.toLowerCase().contains(q)))
          .toList()
        ..sort((a, b) {
          final s = a.sortOrder.compareTo(b.sortOrder);
          return s != 0 ? s : a.name.compareTo(b.name);
        });
      if (rows.isNotEmpty) out[c.value] = rows;
    }
    return out;
  }

  TaxiVehicleTypeModel? byId(String? id) {
    if (id == null) return null;
    for (final t in types) {
      if (t.id == id) return t;
    }
    return null;
  }

  String? nameOf(String? id) => byId(id)?.name;
}
