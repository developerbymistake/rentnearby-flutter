import 'dart:async';
import 'package:get/get.dart';
import '../../../../config/app_tabs.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../nearby/controllers/nearby_centre_controller.dart';
import '../../../nearby/controllers/nearby_feed_controller.dart';
import '../../../nearby/models/nearby_models.dart';
import 'stay_feed_item.dart';
import 'stay_feed_repository.dart';

class StayLandingControllerV2 extends NearbyFeedController<StayFeedItem> {
  static const tag = 'stays-v2';
  static const defaultSort = 'nearest';

  final selectedStayTypeId = Rxn<String>();
  final selectedMeals = Rxn<String>();
  final sortBy = defaultSort.obs;
  final resetGeneration = 0.obs;
  final stayPostedTrigger = 0.obs;
  final _repo = StayFeedRepository();
  final _workers = <Worker>[];

  @override
  int? get tabIndex => AppTabs.stays;

  @override
  String idOf(StayFeedItem item) => item.id;

  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) => _repo.fetch(
        centre: NearbyCentreController.to.centre,
        stayTypeId: selectedStayTypeId.value,
        meals: selectedMeals.value,
        token: token,
      );

  @override
  void onInit() {
    super.onInit();
    _workers.add(ever(stayPostedTrigger, (_) => markDirty()));
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void setStayType(String? id) {
    if (selectedStayTypeId.value == id) return;
    selectedStayTypeId.value = id;
    unawaited(reload());
  }

  void applyFilters({String? meals, String? stayTypeId, required String sort}) {
    final changed = selectedMeals.value != meals || selectedStayTypeId.value != stayTypeId;
    selectedMeals.value = meals;
    selectedStayTypeId.value = stayTypeId;
    sortBy.value = sort;
    if (changed) unawaited(reload());
  }

  List<StayFeedItem> sorted(List<StayFeedItem> list) {
    final s = sortBy.value;
    if (s == defaultSort) return list;
    final out = [...list];
    num price(StayFeedItem x) => x.minPrice ?? double.infinity;
    out.sort((a, b) => s == 'price_asc' ? price(a).compareTo(price(b)) : (b.minPrice ?? -1).compareTo(a.minPrice ?? -1));
    return out;
  }

  void refreshOwnerStatus() {
    final auth = Get.find<AuthController>();
    if (auth.staysEnabled) unawaited(auth.refreshProfile());
  }
}
