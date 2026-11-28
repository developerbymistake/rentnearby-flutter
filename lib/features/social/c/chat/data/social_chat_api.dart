import '../../../../../services/api_service.dart';
import '../../../../buddy/shared/buddy_api_base.dart';
import '../../../../buddy/shared/buddy_json.dart';
import '../../../../buddy/shared/buddy_result.dart';
import '../../../shared/social_models.dart';
import '../models/chat_models.dart';

class SocialChatApi {
  const SocialChatApi();

  static const String _base = '/social/chat';

  Future<BuddyResult<RoomsPage>> rooms(String bucket, {String? cursor}) => BuddyApiBase.run(() async => RoomsPage.fromJson(BuddyApiBase.dataOf(
      await BuddyApiBase.read(() => ApiService.get('$_base/rooms', params: BuddyApiBase.query({'bucket': bucket, 'cursor': cursor}))))));

  Future<BuddyResult<ChatPreflight>> withUser(String userId) => BuddyApiBase.run(
      () async => ChatPreflight.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('$_base/with/$userId')))));

  Future<BuddyResult<ChatRoomModel>> tripRoom(String tripId) => BuddyApiBase.run(
      () async => ChatRoomModel.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('$_base/trip/$tripId')))));

  Future<BuddyResult<ChatRoomModel>> setSendMode(String roomId, {required bool onlyOwnerSends}) => BuddyApiBase.run(() async =>
      ChatRoomModel.fromJson(BuddyApiBase.dataOf(await ApiService.put('$_base/rooms/$roomId/send-mode', {'onlyOwnerSends': onlyOwnerSends}))));

  Future<BuddyResult<ChatRoomModel>> room(String roomId) => BuddyApiBase.run(
      () async => ChatRoomModel.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('$_base/rooms/$roomId')))));

  Future<BuddyResult<StartedChat>> start({required String toUserId, required String clientMessageId, required String text}) => BuddyApiBase.run(
      () async => StartedChat.fromJson(BuddyApiBase.dataOf(
          await ApiService.post('$_base/rooms', {'toUserId': toUserId, 'clientMessageId': clientMessageId, 'text': text}))));

  Future<BuddyResult<MessagesPage>> messages(String roomId, {int? beforeSeq, int? afterSeq, int limit = 50}) => BuddyApiBase.run(() async =>
      MessagesPage.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('$_base/rooms/$roomId/messages',
          params: BuddyApiBase.query({'beforeSeq': beforeSeq, 'afterSeq': afterSeq, 'limit': limit}))))));

  Future<BuddyResult<ChatMessageModel>> send(String roomId, {required String clientMessageId, required String text}) => BuddyApiBase.run(
      () async => ChatMessageModel.fromJson(BuddyApiBase.dataOf(
          await ApiService.post('$_base/rooms/$roomId/messages', {'clientMessageId': clientMessageId, 'text': text}))));

  Future<BuddyResult<ChatUnread>> read(String roomId, int seq) => BuddyApiBase.run(() async => ChatUnread.fromJson(
      BuddyJson.mapOrNull(BuddyApiBase.dataOf(await ApiService.post('$_base/rooms/$roomId/read', {'seq': seq}))['unread'])));

  Future<BuddyResult<void>> deleteRoom(String roomId) => BuddyApiBase.run(() async => ApiService.deleteJson('$_base/rooms/$roomId'));
}
