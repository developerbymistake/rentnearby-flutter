import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../utils/keyset_page.dart';

/// Thin wrapper around the consumer-facing notification inbox endpoints (/notifications) —
/// deliberately uncached. Separate from NotificationService, which owns
/// only FCM/local-notification plumbing (device-token register/unregister, tap routing) — this
/// class owns the persisted inbox itself.
class NotificationRepository {
  // cursor = the previous page's nextCursor (keyset); page is only the fallback for a server without cursors.
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications(
      {String? cursor, int page = 1, int pageSize = 20}) async {
    final res = await ApiService.get('/notifications', params: paramsFor(cursor: cursor, page: page, pageSize: pageSize));
    final p = KeysetPage.parse(res['data'], NotificationModel.fromJson);
    return (items: p.items, hasMore: p.hasMoreAfter(pageSize), nextCursor: p.nextCursor);
  }

  static Map<String, dynamic> paramsFor({String? cursor, int page = 1, int pageSize = 20}) =>
      cursor != null ? {'cursor': cursor, 'pageSize': pageSize} : {'page': page, 'pageSize': pageSize};

  Future<int> getUnreadCount() async {
    final res = await ApiService.get('/notifications/unread-count');
    return (res['data']?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    await ApiService.put('/notifications/$id/read', {});
  }

  Future<void> markAllRead() async {
    await ApiService.put('/notifications/read-all', {});
  }
}
