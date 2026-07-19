import 'package:get/get.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

/// Owns the Home-screen bell's unread badge and the notification inbox list. Fetches
/// [unreadCount] once per session (mirrors AgentController.checkAgentStatus's onInit()-fetches
/// -once pattern), refreshed on app resume rather than a live push — see the plan's Design
/// decisions for why InquiryHubService staying lazy-connected wasn't worth reversing for this.
class NotificationController extends GetxController {
  final unreadCount = 0.obs;
  final notifications = <NotificationModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMoreNotifications = false.obs;
  int _notificationsPage = 1;
  // Bumped on every loadNotifications() call — a pull-to-refresh racing an in-flight
  // loadMoreNotifications() (or vice versa) would otherwise let whichever response lands second
  // silently corrupt the list (e.g. a late page-N append landing after a fresh reset). Only the
  // response matching the latest request id is applied.
  int _requestId = 0;

  NotificationRepository get _repo => Get.find<NotificationRepository>();

  @override
  void onInit() {
    super.onInit();
    loadUnreadCount();
  }

  Future<void> loadUnreadCount() async {
    try {
      unreadCount.value = await _repo.getUnreadCount();
    } catch (_) {
      // Best-effort — a network hiccup just means the badge stays at its last-known count.
    }
  }

  Future<void> loadNotifications({bool reset = true}) async {
    final requestId = ++_requestId;
    if (reset) {
      _notificationsPage = 1;
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }
    try {
      final result = await _repo.getNotifications(page: _notificationsPage);
      // A newer loadNotifications() call (refresh or load-more) superseded this one — discard
      // this response rather than letting it corrupt whatever the newer call already applied.
      if (requestId != _requestId) return;
      if (reset) {
        notifications.value = result.items;
      } else {
        notifications.addAll(result.items);
      }
      hasMoreNotifications.value = result.hasMore;
    } catch (_) {
      // Silent — the screen's own empty/error state handles this via isLoading + an empty list.
    } finally {
      if (requestId == _requestId) {
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> loadMoreNotifications() async {
    if (!hasMoreNotifications.value || isLoadingMore.value) return;
    _notificationsPage++;
    await loadNotifications(reset: false);
  }

  Future<void> markRead(String id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || notifications[idx].isRead) return;

    // Optimistic — flip locally and decrement the badge immediately, matching
    // AgentController.updateLeadStatus's shape; the API call is fire-and-forget best-effort
    // since MarkNotificationRead is idempotent server-side regardless of retry/failure.
    notifications[idx] = notifications[idx].copyWith(isRead: true);
    if (unreadCount.value > 0) unreadCount.value--;

    try {
      await _repo.markRead(id);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final hadUnread = notifications.any((n) => !n.isRead);
    if (!hadUnread) return;

    notifications.value = notifications.map((n) => n.copyWith(isRead: true)).toList();
    unreadCount.value = 0;

    try {
      await _repo.markAllRead();
    } catch (_) {}
  }
}
