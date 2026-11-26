import 'package:get/get.dart';

import '../../buddy/shared/buddy_result.dart';
import 'data/social_me_api.dart';
import 'social_models.dart';

class SocialMeController extends GetxController {
  SocialMeController({SocialMeApi api = const SocialMeApi()}) : _api = api;

  static SocialMeController get to => Get.find<SocialMeController>();

  static SocialMeController? get maybe => Get.isRegistered<SocialMeController>() ? Get.find<SocialMeController>() : null;

  final SocialMeApi _api;
  final me = Rxn<SocialMe>();
  final loading = false.obs;
  final failed = false.obs;
  int _gen = 0;
  bool _quietRunning = false;

  SocialLimits get limits => me.value?.limits ?? SocialLimits.free;

  MyProfile? get profile => me.value?.profile;

  SocialCatalogData get catalog => me.value?.catalog ?? SocialCatalogData.empty;

  @override
  void onInit() {
    super.onInit();
    load();
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

  void applyProfile(MyProfile p) {
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
