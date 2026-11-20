import 'package:get/get.dart';

import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../data/notices_api.dart';
import '../models/notice_models.dart';

class NoticesController extends GetxController {
  NoticesController({this.api = const NoticesApi()});

  static NoticesController? get maybe => Get.isRegistered<NoticesController>() ? Get.find<NoticesController>() : null;

  final NoticesApi api;
  final notices = <Notice>[].obs;
  final unread = 0.obs;
  final nextCursor = RxnString();
  final loadFailed = false.obs;
  final isLoadingMore = false.obs;
  Worker? _live;
  int _requestId = 0;
  bool _refreshing = false;

  bool get hasMore => nextCursor.value != null;

  @override
  void onInit() {
    super.onInit();
    _live = ever<int>(BuddyLive.notices, (_) => refreshFirstPage());
  }

  Future<void> refreshFirstPage() async {
    final id = ++_requestId;
    _refreshing = true;
    final r = await api.list();
    if (id != _requestId) return;
    _refreshing = false;
    isLoadingMore.value = false;
    if (r is BuddyOk<NoticePage>) {
      notices.assignAll(r.value.items.where((n) => n.isKnown));
      nextCursor.value = r.value.nextCursor;
      unread.value = r.value.unread;
      loadFailed.value = false;
    } else {
      loadFailed.value = true;
    }
  }

  Future<void> loadMore() async {
    final cursor = nextCursor.value;
    if (cursor == null || isLoadingMore.value || _refreshing) return;
    final id = ++_requestId;
    isLoadingMore.value = true;
    final r = await api.list(cursor: cursor);
    if (id != _requestId) return;
    isLoadingMore.value = false;
    if (r is BuddyOk<NoticePage>) {
      final known = notices.map((n) => n.id).toSet();
      notices.addAll(r.value.items.where((n) => n.isKnown && !known.contains(n.id)));
      nextCursor.value = r.value.nextCursor;
    }
  }

  Future<void> markRead(String id) async {
    final i = notices.indexWhere((n) => n.id == id);
    if (i == -1 || notices[i].isRead) return;
    notices[i] = notices[i].markedRead();
    if (unread.value > 0) unread.value--;
    await api.markRead(id);
  }

  void markAllReadLocal() {
    if (notices.any((n) => !n.isRead)) notices.assignAll(notices.map((n) => n.isRead ? n : n.markedRead()));
    unread.value = 0;
  }

  @override
  void onClose() {
    _live?.dispose();
    super.onClose();
  }
}
