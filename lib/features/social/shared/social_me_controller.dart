import 'dart:async';

import 'package:get/get.dart';

import '../../buddy/buddy_live.dart';
import '../../buddy/shared/buddy_result.dart';
import 'data/social_me_api.dart';
import 'social_models.dart';
import 'social_strings.dart';

class SocialMeController extends GetxController {
  SocialMeController({SocialMeApi api = const SocialMeApi()}) : _api = api;

  static SocialMeController get to => Get.find<SocialMeController>();

  static SocialMeController? get maybe => Get.isRegistered<SocialMeController>() ? Get.find<SocialMeController>() : null;

  static const sharedTripsDebounce = Duration(milliseconds: 600);

  final SocialMeApi _api;
  final me = Rxn<SocialMe>();
  final loading = false.obs;
  final failed = false.obs;
  int _gen = 0;
  bool _quietRunning = false;
  Worker? _sharedWorker;
  Timer? _sharedTimer;

  SocialLimits get limits => me.value?.limits ?? SocialLimits.free;

  MyProfile? get profile => me.value?.profile;

  SocialCatalogData get catalog => me.value?.catalog ?? SocialCatalogData.empty;

  @override
  void onInit() {
    super.onInit();
    _sharedWorker = ever<int>(BuddyLive.sharedTrips, (_) {
      _sharedTimer?.cancel();
      _sharedTimer = Timer(sharedTripsDebounce, refreshQuiet);
    });
    load();
  }

  @override
  void onClose() {
    _sharedWorker?.dispose();
    _sharedTimer?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    final gen = ++_gen;
    loading.value = me.value == null;
    final result = await _api.me();
    if (gen != _gen) return;
    loading.value = false;
    if (result case BuddyOk<SocialMe>(:final value)) {
      me.value = value;
      failed.value = false;
    } else if (me.value == null) {
      failed.value = true;
    }
  }

  Future<void> refreshQuiet() async {
    if (_quietRunning) return;
    _quietRunning = true;
    try {
      final gen = ++_gen;
      final result = await _api.me();
      if (gen != _gen) return;
      loading.value = false;
      if (result case BuddyOk<SocialMe>(:final value)) {
        me.value = value;
        failed.value = false;
      } else if (me.value == null) {
        failed.value = true;
      }
    } finally {
      _quietRunning = false;
    }
  }

  /// false only when the server said so; unknown (not loaded, older answer) never blocks, the server enforces.
  bool get guidelinesMissing => me.value?.guidelinesAccepted == false;

  Future<String?> acceptGuidelines() async {
    final r = await _api.acceptGuidelines();
    switch (r) {
      case BuddyOk():
        applyGuidelinesAccepted(true);
        return null;
      case BuddyRefused(:final message):
        return message ?? SocialStrings.failed;
      case BuddyOffline():
        return SocialStrings.offline;
      case BuddyFailed():
        return SocialStrings.failed;
    }
  }

  void applyGuidelinesAccepted(bool accepted) {
    final current = me.value;
    if (current == null) return;
    _gen++;
    loading.value = false;
    me.value = current.copyWith(guidelinesAccepted: accepted);
  }

  void applyProfile(MyProfile p) {
    _gen++;
    loading.value = false;
    final current = me.value;
    me.value = current == null ? SocialMe(profile: p, limits: SocialLimits.free) : current.copyWith(profile: p);
  }

  void applyUnread(ChatUnread u) {
    final current = me.value;
    if (current != null) me.value = current.copyWith(chatUnread: u);
  }

  void applyFollowRequests(int n) {
    final current = me.value;
    if (current != null) me.value = current.copyWith(followRequests: n < 0 ? 0 : n);
  }

  void clear() {
    _gen++;
    me.value = null;
    loading.value = false;
    failed.value = false;
  }
}
