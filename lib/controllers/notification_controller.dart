import 'package:get/get.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

/// Owns the Home-screen bell's unread badge and the notification inbox list. [unreadCount] is
/// fetched once per session at onInit() (mirrors AgentController.checkAgentStatus's own
/// onInit()-fetches-once pattern) and again on app resume (see main_screen.dart) — that REST
/// anchor alone already covers cold-start/reopen-after-close correctly and is unchanged.
/// [applyLiveNotification] is the separate foreground-live path: EnquiryHubService's
/// session-wide "NotificationReceived" push now reaches this controller unconditionally for
/// every event (not just Agent lead-assignment), so the badge/list update immediately instead
/// of waiting for the next resume or a manual pull-to-refresh.
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

  /// Driven by EnquiryHubService's live "NotificationReceived" push — called unconditionally for
  /// every event regardless of [Map] `type` (see EnquiryHubService's own comment on why this
  /// differs from AgentController.applyLeadAssigned's type-gated call from the same handler).
  /// unreadCount is incremented unconditionally — the badge should always reflect a genuinely
  /// new push — but the row is only prepended into [notifications] when the list is both already
  /// loaded AND fully paginated (`!hasMoreNotifications`). Unlike myLeads (unpaginated), this
  /// list is page-cursor-based (`_notificationsPage`), so inserting locally while further pages
  /// are still unfetched would desync the in-memory list from the next loadMoreNotifications()
  /// page fetch (a duplicate or skipped row) — safe only once every page is already in memory,
  /// same as this codebase's other server-anchored counts falling back to "next real fetch picks
  /// up the true value" rather than guessing at a local patch it can't fully reconcile.
  void applyLiveNotification(Map<String, dynamic> data) {
    unreadCount.value++;
    if (notifications.isEmpty || hasMoreNotifications.value) return;
    try {
      notifications.insert(
        0,
        NotificationModel(
          id: data['id'] as String,
          type: data['type'] as String? ?? '',
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          actionRoute: data['actionRoute'] as String?,
          actionArguments: (data['actionArguments'] as Map?)?.cast<String, dynamic>(),
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Malformed/missing id — the unreadCount increment above still stands (a real push landed
      // server-side regardless); the row itself just won't appear until the next loadNotifications().
    }
  }
}
