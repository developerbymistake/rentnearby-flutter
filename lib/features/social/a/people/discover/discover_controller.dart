import 'package:get/get.dart';

import '../../../../buddy/shared/buddy_result.dart';
import '../../../shared/data/follow_api.dart';
import '../../../shared/social_error_types.dart';
import '../../../shared/social_me_controller.dart';
import '../../../shared/social_models.dart';
import '../../../shared/social_strings.dart';
import '../people_controller.dart';

/// Discover tab state: one paged list per chip, deduped by userId, hidden people never come back.
class DiscoverController {
  DiscoverController({FollowApi api = const FollowApi(), bool Function()? nearAllowed})
      : _api = api,
        _nearAllowed = nearAllowed ?? _plusNear;

  static bool _plusNear() => SocialMeController.maybe?.limits.nearMe ?? false;

  // A page may come back short or empty while the cursor is set: keep fetching, but never more than this in one go.
  static const int fillTarget = 8;
  static const int maxAutoPages = 3;

  final FollowApi _api;
  final bool Function() _nearAllowed;

  final chip = DiscoverChips.forYou.obs;
  final myTrip = Rxn<DiscoverTrip>();
  final nearRefused = false.obs;
  final Map<String, PeopleList<DiscoverPerson>> lists = {for (final c in DiscoverChips.all) c: PeopleList<DiscoverPerson>()};
  final Set<String> _hidden = {};

  bool get nearLocked => nearRefused.value || !_nearAllowed();

  /// The near chip while locked shows the Plus card above the For you list (D1) and never calls the API.
  bool get showsNearLock => chip.value == DiscoverChips.near && nearLocked;

  String get listChip => showsNearLock ? DiscoverChips.forYou : chip.value;

  PeopleList<DiscoverPerson> get current => lists[listChip]!;

  void selectChip(String c) {
    if (!DiscoverChips.all.contains(c) || c == chip.value) return;
    chip.value = c;
    if (current.state.value == ListLoad.idle) load();
  }

  Future<void> load({bool more = false}) => _load(listChip, more: more, refresh: false);

  /// Pull to refresh: the server rebuilds the snapshot, so the other chips start over too.
  Future<void> refresh() {
    final c = listChip;
    for (final e in lists.entries) {
      if (e.key != c) e.value.clear();
    }
    return _load(c, more: false, refresh: true);
  }

  Future<void> _load(String c, {required bool more, required bool refresh}) async {
    if (c == DiscoverChips.near && nearLocked) return;
    final list = lists[c]!;
    if (more && (!list.hasMore || list.loadingMore.value)) return;
    final gen = more ? list.gen : ++list.gen;
    if (more) {
      list.loadingMore.value = true;
    } else {
      list.loadingMore.value = false;
      if (list.items.isEmpty) list.state.value = ListLoad.loading;
    }
    var cursor = more ? list.cursor : null;
    final seen = more ? {for (final p in list.items) p.userId} : <String>{};
    final got = <DiscoverPerson>[];
    for (var page = 0; page < maxAutoPages; page++) {
      final r = await _api.discover(chip: c, cursor: cursor, refresh: refresh && page == 0);
      if (gen != list.gen) return;
      if (r case BuddyOk<DiscoverPage>(:final value)) {
        for (final p in value.items) {
          if (!_hidden.contains(p.userId) && seen.add(p.userId)) got.add(p);
        }
        if (c == DiscoverChips.sameTrip && !more && page == 0) myTrip.value = value.myTrip;
        cursor = value.nextCursor;
        final have = (more ? list.items.length : 0) + got.length;
        if (cursor == null || (have >= fillTarget && got.isNotEmpty)) break;
        continue;
      }
      if (page > 0) break;
      list.loadingMore.value = false;
      if (r is BuddyRefused<DiscoverPage> && r.type == SocialErrorTypes.plusRequired && c == DiscoverChips.near) {
        nearRefused.value = true;
        list.state.value = ListLoad.idle;
        if (lists[DiscoverChips.forYou]!.state.value == ListLoad.idle) await _load(DiscoverChips.forYou, more: false, refresh: false);
        return;
      }
      if (list.items.isEmpty) list.state.value = r is BuddyOffline ? ListLoad.offline : ListLoad.failed;
      return;
    }
    list.loadingMore.value = false;
    if (!more) {
      list.items.assignAll(got);
    } else {
      list.items.addAll(got);
    }
    list.cursor = cursor;
    list.total.value = list.items.length;
    list.state.value = ListLoad.ready;
  }

  /// The card's FollowButton already flipped itself; keep every chip's copy in step.
  void onFollowChanged(String userId, bool iFollow, bool requested) {
    for (final list in lists.values) {
      final i = list.items.indexWhere((p) => p.userId == userId);
      if (i >= 0) list.items[i] = list.items[i].copyWith(iFollow: iFollow, followRequested: requested);
    }
  }

  /// X on a card: gone at once from every chip; put back at the same place if the server refuses.
  Future<String?> hide(String userId) async {
    if (!_hidden.add(userId)) return null;
    final removed = <(PeopleList<DiscoverPerson>, int, DiscoverPerson)>[];
    for (final list in lists.values) {
      final i = list.items.indexWhere((p) => p.userId == userId);
      if (i >= 0) removed.add((list, i, list.items.removeAt(i)));
    }
    final r = await _api.hide(userId);
    if (r.isOk) return null;
    _hidden.remove(userId);
    for (final (list, i, p) in removed) {
      if (list.items.any((e) => e.userId == userId)) continue;
      list.items.insert(i.clamp(0, list.items.length), p);
    }
    return switch (r) {
      BuddyRefused(:final message) => message ?? SocialStrings.failed,
      BuddyOffline() => SocialStrings.offline,
      _ => SocialStrings.failed,
    };
  }

  void onBlocked(String userId) {
    _hidden.add(userId);
    for (final list in lists.values) {
      list.items.removeWhere((p) => p.userId == userId);
    }
  }
}
