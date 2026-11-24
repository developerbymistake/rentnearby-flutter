import 'dart:async';

import 'package:get/get.dart';

import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../buddy_feedback.dart';
import '../data/buddies_api.dart';
import '../models/buddy_models.dart';
import 'buddy_summary_controller.dart';

enum BuddyListState { loading, ready, failed }

abstract final class BuddiesTab {
  static const int find = 0;
  static const int buddies = 1;
  static const int requests = 2;
}

class BuddiesController extends GetxController {
  BuddiesController({this.api = const BuddiesApi(), int initialTab = BuddiesTab.find}) : tab = initialTab.obs;

  static const Duration seenDelay = Duration(seconds: 2);

  final BuddiesApi api;
  final RxInt tab;
  final state = BuddyListState.loading.obs;
  final items = <BuddyItem>[].obs;
  final count = 0.obs;
  final loadingMore = false.obs;
  final removing = <String>{}.obs;
  String? _cursor;
  final Set<String> _seenSent = {};
  final Set<String> _pendingSeen = {};
  Timer? _seenTimer;
  Worker? _live;
  Worker? _tabWorker;
  int _gen = 0;

  bool get hasMore => _cursor != null;

  @override
  void onInit() {
    super.onInit();
    _live = ever<int>(BuddyLive.buddies, (_) => load());
    _tabWorker = ever<int>(tab, (t) {
      if (t == BuddiesTab.buddies) {
        _noteNew(items);
      } else {
        flushSeen();
      }
    });
    load();
  }

  Future<void> load() async {
    final gen = ++_gen;
    if (items.isEmpty) state.value = BuddyListState.loading;
    final r = await api.buddies(limit: 50);
    if (gen != _gen) return;
    if (r is BuddyOk<BuddyList>) {
      items.assignAll(r.value.items);
      count.value = r.value.count;
      _cursor = r.value.nextCursor;
      state.value = BuddyListState.ready;
      _noteNew(r.value.items);
    } else if (items.isEmpty) {
      state.value = BuddyListState.failed;
    }
  }

  Future<void> loadMore() async {
    final c = _cursor;
    if (c == null || loadingMore.value) return;
    loadingMore.value = true;
    final gen = _gen;
    final r = await api.buddies(cursor: c, limit: 50);
    loadingMore.value = false;
    if (gen != _gen || r is! BuddyOk<BuddyList>) return;
    final known = items.map((e) => e.userId).toSet();
    items.addAll(r.value.items.where((e) => !known.contains(e.userId)));
    _cursor = r.value.nextCursor;
    _noteNew(r.value.items);
  }

  void _noteNew(List<BuddyItem> list) {
    if (tab.value != BuddiesTab.buddies) return;
    for (final b in list) {
      if (b.isNew && !_seenSent.contains(b.userId)) _pendingSeen.add(b.userId);
    }
    if (_pendingSeen.isEmpty) return;
    _seenTimer?.cancel();
    _seenTimer = Timer(seenDelay, flushSeen);
  }

  void flushSeen() {
    _seenTimer?.cancel();
    _seenTimer = null;
    if (_pendingSeen.isEmpty) return;
    final ids = _pendingSeen.toList();
    _seenSent.addAll(ids);
    _pendingSeen.clear();
    api.markSeen(ids).then((r) {
      if (r is BuddyOk) BuddySummaryController.maybe?.load();
    });
  }

  void dropPerson(String userId) {
    final before = items.length;
    items.removeWhere((e) => e.userId == userId);
    if (items.length != before && count.value > 0) count.value--;
  }

  Future<bool> remove(String userId) async {
    if (removing.contains(userId)) return false;
    removing.add(userId);
    final r = await api.remove(userId);
    removing.remove(userId);
    if (r is BuddyOk) {
      dropPerson(userId);
      BuddySummaryController.maybe?.load();
      return true;
    }
    BuddyFeedback.writeFailed(r);
    return false;
  }

  @override
  void onClose() {
    flushSeen();
    _live?.dispose();
    _tabWorker?.dispose();
    super.onClose();
  }
}
