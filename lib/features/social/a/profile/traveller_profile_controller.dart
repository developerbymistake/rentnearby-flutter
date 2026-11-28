import 'package:get/get.dart';

import '../../../buddy/shared/buddy_result.dart';
import '../../shared/data/follow_api.dart';
import '../../shared/data/social_me_api.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_live.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../social_strings_a.dart';

enum TravellerLoad { loading, ready, gone, offline, failed }

class TravellerProfileController extends GetxController {
  TravellerProfileController({required this.userId, SocialMeApi api = const SocialMeApi(), FollowApi follow = const FollowApi()})
      : _api = api,
        _follow = follow;

  final String userId;
  final SocialMeApi _api;
  final FollowApi _follow;

  final state = TravellerLoad.loading.obs;
  final profile = Rxn<TravellerProfile>();
  final buddyBusy = false.obs;
  final similar = <DiscoverPerson>[].obs;
  int _gen = 0;
  int _similarGen = 0;
  bool _closed = false;
  Worker? _followChange;

  static const int similarSize = 5;

  @override
  void onInit() {
    super.onInit();
    _followChange = ever<(String, bool, bool)?>(SocialLive.followChange, (e) {
      if (e != null) onSimilarFollowChanged(e.$1, e.$2, e.$3);
    });
    load();
  }

  @override
  void onClose() {
    _closed = true;
    _followChange?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final gen = ++_gen;
    if (profile.value == null) state.value = TravellerLoad.loading;
    final r = await _api.traveller(userId);
    if (gen != _gen) return;
    switch (r) {
      case BuddyOk(:final value):
        profile.value = value;
        state.value = TravellerLoad.ready;
      case BuddyRefused(:final statusCode, :final type):
        if (profile.value == null || statusCode == 404 || type == SocialErrorTypes.personNotFound) {
          profile.value = null;
          state.value = statusCode == 404 || type == SocialErrorTypes.personNotFound ? TravellerLoad.gone : TravellerLoad.failed;
        }
      case BuddyOffline():
        if (profile.value == null) state.value = TravellerLoad.offline;
      case BuddyFailed():
        if (profile.value == null) state.value = TravellerLoad.failed;
    }
  }

  void onFollowChanged(bool iFollow, bool requested) {
    final p = profile.value;
    if (_closed || p == null) return;
    final delta = (iFollow ? 1 : 0) - (p.iFollow ? 1 : 0);
    profile.value = p.copyWith(iFollow: iFollow, followRequested: requested, followers: p.followers + delta < 0 ? 0 : p.followers + delta);
    if (iFollow && p.privateLocked) load();
    if (!iFollow || requested) {
      _similarGen++;
      similar.clear();
    }
  }

  /// B2: the similar strip loads only after the server accepted the follow.
  void onFollowSettled(bool iFollow, bool requested) {
    final p = profile.value;
    if (_closed || p == null || !iFollow || requested || p.privateLocked) return;
    _loadSimilar();
  }

  Future<void> _loadSimilar() async {
    final gen = ++_similarGen;
    final r = await _follow.similar(userId, limit: similarSize);
    if (gen != _similarGen) return;
    similar.assignAll(switch (r) {
      BuddyOk<List<DiscoverPerson>>(:final value) => value,
      _ => const <DiscoverPerson>[],
    });
  }

  void onSimilarFollowChanged(String id, bool iFollow, bool requested) {
    final i = similar.indexWhere((x) => x.userId == id);
    if (i != -1) similar[i] = similar[i].copyWith(iFollow: iFollow, followRequested: requested);
  }

  Future<String?> toggleBuddy() async {
    final p = profile.value;
    if (p == null || buddyBusy.value) return null;
    buddyBusy.value = true;
    final was = p.isBuddy;
    profile.value = p.copyWith(isBuddy: !was);
    try {
      final r = was ? await _follow.removeBuddy(userId) : await _follow.addBuddy(userId);
      if (r.isOk) {
        SocialLive.followers.value++;
        return was ? SocialStringsA.removeBuddyDone : SocialStringsA.makeBuddyDone;
      }
      profile.value = profile.value?.copyWith(isBuddy: was);
      return switch (r) {
        BuddyRefused(:final message) => message ?? SocialStrings.failed,
        BuddyOffline() => SocialStrings.offline,
        _ => SocialStrings.failed,
      };
    } finally {
      buddyBusy.value = false;
    }
  }
}
