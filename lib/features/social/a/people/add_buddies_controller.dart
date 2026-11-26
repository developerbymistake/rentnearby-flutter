import 'dart:async';

import 'package:get/get.dart';

import '../../../buddy/shared/buddy_result.dart';
import '../../shared/data/follow_api.dart';
import '../../shared/social_live.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import 'people_controller.dart';

class AddBuddiesController extends GetxController {
  AddBuddiesController({FollowApi api = const FollowApi(), this.debounce = const Duration(milliseconds: 300)}) : _api = api;

  final FollowApi _api;
  final Duration debounce;

  final list = PeopleList<PersonRow>();
  final buddies = 0.obs;
  final query = ''.obs;
  final busy = <String>{}.obs;
  Timer? _timer;
  bool changed = false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  void onQuery(String q) {
    query.value = q;
    _timer?.cancel();
    _timer = Timer(debounce, load);
  }

  String? get _q {
    final t = query.value.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> load({bool more = false}) async {
    if (more && (!list.hasMore || list.loadingMore.value)) return;
    final gen = more ? list.gen : ++list.gen;
    if (more) {
      list.loadingMore.value = true;
    } else {
      list.state.value = ListLoad.loading;
    }
    final r = await _api.followers(cursor: more ? list.cursor : null, q: _q);
    if (gen != list.gen) return;
    list.loadingMore.value = false;
    if (r case BuddyOk<PeoplePage>(:final value)) {
      if (more) {
        list.items.addAll(value.items);
      } else {
        list.items.assignAll(value.items);
      }
      list.cursor = value.nextCursor;
      list.total.value = value.total;
      buddies.value = value.buddies;
      list.state.value = ListLoad.ready;
    } else {
      if (!more) list.items.clear();
      list.state.value = r is BuddyOffline ? ListLoad.offline : ListLoad.failed;
    }
  }

  Future<String?> toggle(String userId) async {
    final i = list.items.indexWhere((r) => r.person.userId == userId);
    if (i < 0 || busy.contains(userId)) return null;
    busy.add(userId);
    final was = list.items[i].isBuddy;
    list.items[i] = list.items[i].copyWith(isBuddy: !was);
    buddies.value += was ? -1 : 1;
    try {
      final r = was ? await _api.removeBuddy(userId) : await _api.addBuddy(userId);
      if (r.isOk) {
        changed = true;
        SocialLive.followers.value++;
        return null;
      }
      final j = list.items.indexWhere((x) => x.person.userId == userId);
      if (j >= 0) list.items[j] = list.items[j].copyWith(isBuddy: was);
      buddies.value += was ? 1 : -1;
      return switch (r) {
        BuddyRefused(:final message) => message ?? SocialStrings.failed,
        BuddyOffline() => SocialStrings.offline,
        _ => SocialStrings.failed,
      };
    } finally {
      busy.remove(userId);
    }
  }
}
