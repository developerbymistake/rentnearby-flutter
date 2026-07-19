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

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      notifications.value = await _repo.getNotifications();
    } catch (_) {
      // Silent — the screen's own empty/error state handles this via isLoading + an empty list.
    } finally {
      isLoading.value = false;
    }
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
