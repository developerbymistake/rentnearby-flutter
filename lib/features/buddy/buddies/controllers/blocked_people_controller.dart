import 'package:get/get.dart';

import '../../shared/buddy_result.dart';
import '../buddy_feedback.dart';
import '../data/buddies_api.dart';
import '../models/buddy_models.dart';
import 'buddies_controller.dart';
import 'buddy_summary_controller.dart';

class BlockedPeopleController extends GetxController {
  BlockedPeopleController({this.api = const BuddiesApi()});

  final BuddiesApi api;
  final state = BuddyListState.loading.obs;
  final items = <BlockedPerson>[].obs;
  final count = 0.obs;
  final busy = <String>{}.obs;
  final loadingMore = false.obs;
  String? _cursor;
  int _gen = 0;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final gen = ++_gen;
    if (items.isEmpty) state.value = BuddyListState.loading;
    final r = await api.blocks();
    if (gen != _gen) return;
    if (r is BuddyOk<BlockedList>) {
      items.assignAll(r.value.items);
      count.value = r.value.count;
      _cursor = r.value.nextCursor;
      state.value = BuddyListState.ready;
    } else if (items.isEmpty) {
      state.value = BuddyListState.failed;
    }
  }

  Future<void> loadMore() async {
    final c = _cursor;
    if (c == null || loadingMore.value) return;
    loadingMore.value = true;
    final gen = _gen;
    final r = await api.blocks(cursor: c);
    loadingMore.value = false;
    if (gen != _gen || r is! BuddyOk<BlockedList>) return;
    final known = items.map((e) => e.userId).toSet();
    items.addAll(r.value.items.where((e) => !known.contains(e.userId)));
    _cursor = r.value.nextCursor;
  }

  Future<void> unblock(String userId) async {
    if (!busy.add(userId)) return;
    busy.refresh();
    final r = await api.unblock(userId);
    busy.remove(userId);
    if (r is BuddyOk) {
      final before = items.length;
      items.removeWhere((e) => e.userId == userId);
      if (items.length != before && count.value > 0) count.value--;
      BuddySummaryController.maybe?.load();
    } else {
      BuddyFeedback.writeFailed(r);
    }
  }
}
