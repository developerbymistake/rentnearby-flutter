import '../../../../services/api_service.dart';
import '../../shared/buddy_api_base.dart';
import '../../shared/buddy_result.dart';
import '../models/notice_models.dart';

class NoticesApi {
  const NoticesApi();

  Future<BuddyResult<NoticePage>> list({String? cursor, int limit = 30}) => BuddyApiBase.run(() async => NoticePage.fromJson(BuddyApiBase.dataOf(
      await BuddyApiBase.read(() => ApiService.get('/notifications/notices', params: BuddyApiBase.query({'cursor': cursor, 'limit': limit}))))));

  Future<BuddyResult<void>> markRead(String id) => BuddyApiBase.run(() async => ApiService.put('/notifications/notices/$id/read', const {}));

  Future<BuddyResult<UnreadCount>> unreadCount() => BuddyApiBase.run(
      () async => UnreadCount.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/notifications/unread-count')))));
}
