import 'package:get/get.dart';

import '../../../buddy/buddies/data/buddies_api.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/data/follow_api.dart';
import '../../shared/social_live.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import 'discover/discover_controller.dart';

enum ListLoad { idle, loading, ready, offline, failed }

class PeopleList<T> {
  PeopleList();

  final items = <T>[].obs;
  final state = ListLoad.idle.obs;
  final total = 0.obs;
  final loadingMore = false.obs;
  String? cursor;
  int gen = 0;

  bool get hasMore => cursor != null;

  void clear() {
    items.clear();
    cursor = null;
    total.value = 0;
    state.value = ListLoad.idle;
    gen++;
  }
}

class PeopleController extends GetxController {
  PeopleController({String tab = tabDiscover, FollowApi api = const FollowApi(), BuddiesApi buddiesApi = const BuddiesApi(), DiscoverController? discover})
      : _api = api,
        _buddiesApi = buddiesApi,
        discover = discover ?? DiscoverController(api: api),
        initialTab = tab;

  static const String tabDiscover = 'discover';
  static const String tabFollowers = 'followers';
  static const String tabFollowing = 'following';
  static const String tabBuddies = 'buddies';
  static const String tabRequests = 'requests';
  static const List<String> tabs = [tabDiscover, tabFollowers, tabFollowing, tabBuddies];

  final FollowApi _api;
  final BuddiesApi _buddiesApi;
  final String initialTab;
  final DiscoverController discover;

  late final selected = (tabs.indexOf(initialTab) < 0 ? 0 : tabs.indexOf(initialTab)).obs;
  final followers = PeopleList<PersonRow>();
  final following = PeopleList<PersonRow>();
  final buddies = PeopleList<BuddyItem>();
  final requests = PeopleList<PersonRow>();
  final buddiesTotal = 0.obs;
  final _workers = <Worker>[];

  bool get requestsOnly => initialTab == tabRequests;

  String get selectedTab => tabs[selected.value];

  @override
  void onInit() {
    super.onInit();
    if (requestsOnly) {
      loadRequests();
    } else {
      loadRequests();
      loadTab(selected.value);
    }
    _workers.add(ever<int>(SocialLive.followers, (_) => _onFollowsChanged()));
    _workers.add(ever<int>(SocialLive.followRequests, (_) => loadRequests()));
    _workers.add(ever<(String, bool, bool)?>(SocialLive.followChange, (e) {
      if (e != null) discover.onFollowChanged(e.$1, e.$2, e.$3);
    }));
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void select(int i) {
    if (i == selected.value) return;
    selected.value = i;
    final list = _listOf(i);
    if (list.state.value == ListLoad.idle) loadTab(i);
  }

  PeopleList<dynamic> _listOf(int i) => switch (tabs[i]) {
        tabDiscover => discover.current,
        tabFollowing => following,
        tabBuddies => buddies,
        _ => followers,
      };

  // Discover never reloads after a follow (the card flips itself); the other lists reload when opened.
  void _onFollowsChanged() {
    if (requestsOnly || selectedTab != tabDiscover) {
      refreshCurrent();
      return;
    }
    followers.clear();
    following.clear();
  }

  Future<void> refreshCurrent() async {
    if (requestsOnly) return loadRequests();
    await loadTab(selected.value);
  }

  /// Pull to refresh: Discover asks the server to rebuild its suggestions.
  Future<void> pullRefresh() async {
    if (requestsOnly) return loadRequests();
    await Future.wait([selectedTab == tabDiscover ? discover.refresh() : loadTab(selected.value), loadRequests()]);
  }

  Future<void> loadTab(int i, {bool more = false}) => loadKey(tabs[i], more: more);

  Future<void> loadKey(String key, {bool more = false}) => switch (key) {
        tabDiscover => discover.load(more: more),
        tabFollowing => _loadFollowing(more: more),
        tabBuddies => _loadBuddies(more: more),
        _ => _loadFollowers(more: more),
      };

  static ListLoad _failState(BuddyResult<dynamic> r) => r is BuddyOffline ? ListLoad.offline : ListLoad.failed;

  Future<void> _loadPage(PeopleList<PersonRow> list, Future<BuddyResult<PeoplePage>> Function(String? cursor) fetch, {required bool more}) async {
    if (more && (!list.hasMore || list.loadingMore.value)) return;
    final gen = more ? list.gen : ++list.gen;
    if (more) {
      list.loadingMore.value = true;
    } else if (list.items.isEmpty) {
      list.state.value = ListLoad.loading;
    }
    final r = await fetch(more ? list.cursor : null);
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
      if (list == followers && value.buddies > 0) buddiesTotal.value = value.buddies;
      list.state.value = ListLoad.ready;
    } else if (list.items.isEmpty) {
      list.state.value = _failState(r);
    }
  }

  Future<void> _loadFollowers({bool more = false}) => _loadPage(followers, (c) => _api.followers(cursor: c), more: more);

  Future<void> _loadFollowing({bool more = false}) => _loadPage(following, (c) => _api.following(cursor: c), more: more);

  Future<void> loadRequests({bool more = false}) => _loadPage(requests, (c) => _api.requests(cursor: c), more: more);

  Future<void> _loadBuddies({bool more = false}) async {
    final list = buddies;
    if (more && (!list.hasMore || list.loadingMore.value)) return;
    final gen = more ? list.gen : ++list.gen;
    if (more) {
      list.loadingMore.value = true;
    } else if (list.items.isEmpty) {
      list.state.value = ListLoad.loading;
    }
    final r = await _buddiesApi.buddies(cursor: more ? list.cursor : null);
    if (gen != list.gen) return;
    list.loadingMore.value = false;
    if (r case BuddyOk<BuddyList>(:final value)) {
      if (more) {
        list.items.addAll(value.items);
      } else {
        list.items.assignAll(value.items);
      }
      list.cursor = value.nextCursor;
      list.total.value = value.count;
      buddiesTotal.value = value.count;
      list.state.value = ListLoad.ready;
    } else if (list.items.isEmpty) {
      list.state.value = _failState(r);
    }
  }

  void _replace(PeopleList<PersonRow> list, String userId, PersonRow Function(PersonRow) change) {
    final i = list.items.indexWhere((r) => r.person.userId == userId);
    if (i >= 0) list.items[i] = change(list.items[i]);
  }

  void onFollowChanged(String userId, bool iFollow, bool requested) {
    _replace(followers, userId, (r) => r.copyWith(iFollow: iFollow, followRequested: requested));
    _replace(following, userId, (r) => r.copyWith(iFollow: iFollow, followRequested: requested));
  }

  static String _message(BuddyResult<dynamic> r) => switch (r) {
        BuddyRefused(:final message) => message ?? SocialStrings.failed,
        BuddyOffline() => SocialStrings.offline,
        _ => SocialStrings.failed,
      };

  Future<String?> removeFollower(String userId) async {
    final i = followers.items.indexWhere((r) => r.person.userId == userId);
    if (i < 0) return null;
    final row = followers.items.removeAt(i);
    followers.total.value = followers.total.value > 0 ? followers.total.value - 1 : 0;
    final r = await _api.removeFollower(userId);
    if (r.isOk) {
      buddies.items.removeWhere((b) => b.userId == userId);
      SocialMeController.maybe?.refreshQuiet();
      return null;
    }
    followers.items.insert(i.clamp(0, followers.items.length), row);
    followers.total.value++;
    return _message(r);
  }

  Future<String?> removeBuddy(String userId) async {
    final i = buddies.items.indexWhere((b) => b.userId == userId);
    final removed = i >= 0 ? buddies.items.removeAt(i) : null;
    if (removed != null) {
      buddies.total.value = buddies.total.value > 0 ? buddies.total.value - 1 : 0;
      buddiesTotal.value = buddies.total.value;
    }
    _replace(followers, userId, (r) => r.copyWith(isBuddy: false));
    final r = await _api.removeBuddy(userId);
    if (r.isOk) {
      SocialMeController.maybe?.refreshQuiet();
      return null;
    }
    if (removed != null) {
      buddies.items.insert(i.clamp(0, buddies.items.length), removed);
      buddies.total.value++;
      buddiesTotal.value = buddies.total.value;
    }
    _replace(followers, userId, (r) => r.copyWith(isBuddy: true));
    return _message(r);
  }

  Future<String?> answerRequest(String userId, {required bool accept}) async {
    final i = requests.items.indexWhere((r) => r.person.userId == userId);
    if (i < 0) return null;
    final row = requests.items.removeAt(i);
    requests.total.value = requests.total.value > 0 ? requests.total.value - 1 : 0;
    final r = accept ? await _api.acceptRequest(userId) : await _api.declineRequest(userId);
    if (r.isOk || (r is BuddyRefused && r.statusCode == 404)) {
      SocialMeController.maybe?.applyFollowRequests(requests.total.value);
      if (accept) {
        followers.clear();
        if (!requestsOnly && selectedTab == tabFollowers) loadKey(tabFollowers);
        SocialMeController.maybe?.refreshQuiet();
      }
      return null;
    }
    requests.items.insert(i.clamp(0, requests.items.length), row);
    requests.total.value++;
    return _message(r);
  }

  void onBlocked(String userId) {
    followers.items.removeWhere((r) => r.person.userId == userId);
    following.items.removeWhere((r) => r.person.userId == userId);
    requests.items.removeWhere((r) => r.person.userId == userId);
    buddies.items.removeWhere((b) => b.userId == userId);
    discover.onBlocked(userId);
    SocialMeController.maybe?.refreshQuiet();
  }
}
