import 'package:get/get.dart';

import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_live.dart';
import '../../shared/social_models.dart';
import '../data/public_trips_api.dart';

class TripsRailController extends GetxController {
  TripsRailController({PublicTripsApi api = const PublicTripsApi()}) : _api = api;

  static TripsRailController? get maybe => Get.isRegistered<TripsRailController>() ? Get.find<TripsRailController>() : null;

  final PublicTripsApi _api;
  final items = <PublicTrip>[].obs;
  final loading = false.obs;
  final failed = false.obs;
  final loaded = false.obs;
  int _gen = 0;
  Worker? _posts;

  @override
  void onInit() {
    super.onInit();
    _posts = ever<int>(SocialLive.posts, (_) => load());
  }

  Future<void> load() async {
    final gen = ++_gen;
    loading.value = !loaded.value;
    final r = await _api.rail();
    if (gen != _gen) return;
    loading.value = false;
    if (r case BuddyOk<List<PublicTrip>>(:final value)) {
      items.assignAll(value);
      failed.value = false;
      loaded.value = true;
    } else if (!loaded.value) {
      failed.value = true;
    }
  }

  void clear() {
    _gen++;
    items.clear();
    loading.value = false;
    failed.value = false;
    loaded.value = false;
  }

  @override
  void onClose() {
    _posts?.dispose();
    super.onClose();
  }
}
