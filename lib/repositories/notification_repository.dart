import '../models/notification_model.dart';
import '../services/api_service.dart';

/// Thin wrapper around the consumer-facing notification inbox endpoints (/notifications) —
/// deliberately uncached, mirrors AgentRepository. Separate from NotificationService, which owns
/// only FCM/local-notification plumbing (device-token register/unregister, tap routing) — this
/// class owns the persisted inbox itself.
class NotificationRepository {
  Future<List<NotificationModel>> getNotifications({int page = 1, int pageSize = 20}) async {
    final res = await ApiService.get('/notifications', params: {'page': page, 'pageSize': pageSize});
    final items = (res['data']?['items'] as List?) ?? [];
    return items.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

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
