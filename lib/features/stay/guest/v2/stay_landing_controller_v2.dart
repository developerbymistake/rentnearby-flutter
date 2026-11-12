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

  final selectedStayTypeId = Rxn<String>();
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

  void refreshOwnerStatus() {
    final auth = Get.find<AuthController>();
    if (auth.staysEnabled) unawaited(auth.refreshProfile());
  }
}
