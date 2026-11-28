import 'dart:async';

import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/c/chat/data/social_chat_api.dart';
import 'package:bakhli/features/social/c/chat/dm_hub_bridge.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/shared/social_models.dart';

const String myId = 'u-me';
const String peerId = 'u-peer';

Map<String, dynamic> personJson(String id, String name, {String? gender}) => {'userId': id, 'name': name, 'username': 'Bakhli#1', 'initial': name[0], 'gender': ?gender};

Map<String, dynamic> roomJson({
  String roomId = 'r1',
  String kind = 'D',
  String status = 'Active',
  bool iStarted = true,
  String lock = 'none',
  bool canSend = true,
  int lastSeq = 0,
  int unread = 0,
  String? preview,
  Map<String, dynamic>? trip,
  String? peerGender,
}) =>
    {
      'roomId': roomId,
      'kind': kind,
      'status': status,
      'iStarted': iStarted,
      'peer': kind == 'D' ? personJson(peerId, 'Kavya Sharma', gender: peerGender) : null,
      'trip': trip,
      'peerFollowsMe': false,
      'iFollowPeer': false,
      'lastSeq': lastSeq,
      'lastReadSeq': 0,
      'unread': unread,
      'lastMessageAt': '2026-11-26T09:32:00Z',
      'preview': preview,
      'canSend': canSend,
      'lock': lock,
    };

Map<String, dynamic> messageJson(int seq, {String sender = peerId, String text = 'Hi', String? cid, bool masked = false, String? system, String? senderName, String expires = '2099-01-01T00:00:00Z'}) => {
      'seq': seq,
      'senderId': system == null ? sender : null,
      'senderName': senderName,
      'text': text,
      'masked': masked,
      'system': system,
      'createdAt': '2026-11-26T09:32:00Z',
      'expiresAt': expires,
      'clientMessageId': cid,
    };

Map<String, dynamic> tripJson({String tripId = 't1', String title = 'Goa trip', bool isOwner = false, String ownerName = 'Rahul', bool onlyOwnerSends = false, int memberCount = 3}) => {
      'tripId': tripId,
      'title': title,
      'memberCount': memberCount,
      'isOwner': isOwner,
      'ownerName': ownerName,
      'onlyOwnerSends': onlyOwnerSends,
    };

ChatRoomModel roomOf({String roomId = 'r1', String kind = 'D', String status = 'Active', bool iStarted = true, String lock = 'none', bool canSend = true, Map<String, dynamic>? trip, int unread = 0, String? preview, String? peerGender}) =>
    ChatRoomModel.fromJson(roomJson(roomId: roomId, kind: kind, status: status, iStarted: iStarted, lock: lock, canSend: canSend, trip: trip, unread: unread, preview: preview, peerGender: peerGender));

ChatMessageModel msgOf(int seq, {String sender = peerId, String text = 'Hi', String? cid, bool masked = false, String? system, String? senderName, String expires = '2099-01-01T00:00:00Z'}) =>
    ChatMessageModel.fromJson(messageJson(seq, sender: sender, text: text, cid: cid, masked: masked, system: system, senderName: senderName, expires: expires));

class FakeChatApi extends SocialChatApi {
  FakeChatApi();

  BuddyResult<ChatRoomModel> roomResult = BuddyOk(roomOf());
  BuddyResult<ChatRoomModel>? tripResult;
  BuddyResult<ChatPreflight>? preflightResult;
  BuddyResult<MessagesPage> messagesResult = const BuddyOk(MessagesPage(items: []));
  BuddyResult<MessagesPage>? afterResult;
  final List<BuddyResult<ChatMessageModel>> sendResults = [];
  BuddyResult<StartedChat>? startResult;
  final Map<String, BuddyResult<RoomsPage>> pages = {};
  final List<int?> afterCalls = [];
  final List<String> sentIds = [];
  final List<String> deleted = [];

  @override
  Future<BuddyResult<ChatRoomModel>> room(String roomId) async {
    roomCalls++;
    return roomResult;
  }

  @override
  Future<BuddyResult<ChatRoomModel>> tripRoom(String tripId) async => tripResult ?? roomResult;

  @override
  Future<BuddyResult<ChatPreflight>> withUser(String userId) async {
    withUserCalls++;
    return preflightResult!;
  }

  final List<BuddyResult<MessagesPage>> afterQueue = [];
  BuddyResult<MessagesPage>? beforeResult;
  final List<int> beforeCalls = [];
  final List<int> afterLimits = [];
  int roomCalls = 0;
  int withUserCalls = 0;
  Completer<void>? afterGate;

  @override
  Future<BuddyResult<MessagesPage>> messages(String roomId, {int? beforeSeq, int? afterSeq, int limit = 50}) async {
    if (afterSeq != null) {
      afterCalls.add(afterSeq);
      afterLimits.add(limit);
      final gate = afterGate;
      if (gate != null) await gate.future;
      if (afterQueue.isNotEmpty) return afterQueue.removeAt(0);
      return afterResult ?? messagesResult;
    }
    if (beforeSeq != null) {
      beforeCalls.add(beforeSeq);
      return beforeResult ?? const BuddyOk(MessagesPage(items: []));
    }
    return messagesResult;
  }

  @override
  Future<BuddyResult<ChatMessageModel>> send(String roomId, {required String clientMessageId, required String text}) async {
    sentIds.add(clientMessageId);
    return sendResults.isEmpty ? const BuddyOffline() : sendResults.removeAt(0);
  }

  @override
  Future<BuddyResult<StartedChat>> start({required String toUserId, required String clientMessageId, required String text}) async {
    sentIds.add(clientMessageId);
    return startResult!;
  }

  @override
  Future<BuddyResult<RoomsPage>> rooms(String bucket, {String? cursor}) async => pages[bucket] ?? const BuddyOk(RoomsPage(items: []));

  @override
  Future<BuddyResult<ChatUnread>> read(String roomId, int seq) async => const BuddyOk(ChatUnread.zero);

  final List<bool> sendModes = [];
  BuddyResult<ChatRoomModel>? sendModeResult;

  @override
  Future<BuddyResult<ChatRoomModel>> setSendMode(String roomId, {required bool onlyOwnerSends}) async {
    sendModes.add(onlyOwnerSends);
    return sendModeResult ?? roomResult;
  }

  @override
  Future<BuddyResult<void>> deleteRoom(String roomId) async {
    deleted.add(roomId);
    return const BuddyOk(null);
  }
}

class FakeTransport implements DmTransport {
  final controller = StreamController<DmEvent>.broadcast();
  final List<(String, int)> reads = [];
  final List<Map<String, dynamic>?> hubReplies = [];
  final List<String> hubIds = [];

  @override
  Stream<DmEvent> get events => controller.stream;

  @override
  Future<Map<String, dynamic>?> send(String roomId, String clientMessageId, String text) async {
    hubIds.add(clientMessageId);
    return hubReplies.isEmpty ? null : hubReplies.removeAt(0);
  }

  @override
  void read(String roomId, int seq) => reads.add((roomId, seq));
}

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
