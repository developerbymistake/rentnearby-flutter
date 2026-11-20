import 'package:get/get.dart';

import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../data/buddies_api.dart';
import '../models/buddy_models.dart';

class BuddySummaryController extends GetxController {
  BuddySummaryController({this.api = const BuddiesApi()});

  static BuddySummaryController? get maybe => Get.isRegistered<BuddySummaryController>() ? Get.find<BuddySummaryController>() : null;

  final BuddiesApi api;
  final summary = BuddySummary.empty.obs;
  Worker? _live;
  Future<void>? _inFlight;

  @override
  void onInit() {
    super.onInit();
    _live = ever<int>(BuddyLive.buddies, (_) => load());
    load();
  }

  Future<void> load() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    final r = await api.summary();
    if (r is BuddyOk<BuddySummary>) summary.value = r.value;
  }

  @override
  void onClose() {
    _live?.dispose();
    super.onClose();
  }
}
