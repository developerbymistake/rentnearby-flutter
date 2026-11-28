import 'dart:async';

import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/c/chat/dm_hub_bridge.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/open_room_tracker.dart';
import 'package:bakhli/features/social/c/chat/room_controller.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'chat_fakes.dart';
import 'plus_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatApi api;
  late FakeTransport hub;
  var clock = DateTime.utc(2026, 11, 26, 10);
  var ids = 0;

  setUp(() {
    api = FakeChatApi();
    hub = FakeTransport();
    clock = DateTime.utc(2026, 11, 26, 10);
    ids = 0;
  });
  tearDown(() {
    OpenRoomTracker.clear();
    Get.reset();
  });

  Future<RoomController> open({String? roomId = 'r1', String? userId, String? tripId, bool Function()? foreground}) async {
    final c = Get.put(RoomController(
        roomId: roomId, userId: userId, tripId: tripId, api: api, transport: hub, myId: () => myId, now: () => clock, newId: () => 'cid${ids++}', foreground: foreground ?? () => true));
    await settle();
    return c;
  }

  test('optimistic send shows the bubble at once, then the hub ack confirms it', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1)], lastSeq: 1));
    final c = await open();
    hub.hubReplies.add({'ok': true, 'message': messageJson(2, sender: myId, text: 'Hello', cid: 'cid0')});
    final f = c.send('  Hello  ');
    expect(c.messages.last.isLocal, isTrue);
    expect(c.messages.last.sending, isTrue);
    expect(c.messages.last.text, 'Hello');
    await f;
    expect(c.messages.map((m) => m.seq), [1, 2]);
    expect(c.messages.any((m) => m.isLocal), isFalse);
    expect(c.lastSeq, 2);
  });

  test('failed send keeps the bubble and retry uses the same client id', () async {
    final c = await open();
    await c.send('Hello');
    expect(c.messages.single.failed, isTrue);
    expect(hub.hubIds, ['cid0']);
    expect(api.sentIds, ['cid0']);
    api.sendResults.add(BuddyOk(msgOf(1, sender: myId, text: 'Hello', cid: 'cid0')));
    await c.retry('cid0');
    expect(api.sentIds, ['cid0', 'cid0']);
    expect(c.messages.single.seq, 1);
    expect(c.messages.single.failed, isFalse);
  });

  test('a gap in seq is filled with afterSeq', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1), msgOf(2)], lastSeq: 2));
    final c = await open();
    api.afterResult = BuddyOk(MessagesPage(items: [msgOf(3), msgOf(4), msgOf(5)], lastSeq: 5));
    hub.controller.add(DmMessageEvent(roomId: 'r1', kind: 'D', roomStatus: 'Active', message: msgOf(5)));
    await settle();
    expect(api.afterCalls, [2]);
    expect(c.messages.map((m) => m.seq), [1, 2, 3, 4, 5]);
  });

  test('a duplicate or old seq is dropped', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1), msgOf(2)], lastSeq: 2));
    final c = await open();
    await c.applyIncoming(msgOf(2, text: 'again'));
    await c.applyIncoming(msgOf(1, text: 'older'));
    expect(c.messages, hasLength(2));
    await c.applyIncoming(msgOf(3));
    expect(c.messages.map((m) => m.seq), [1, 2, 3]);
  });

  test('events of another room are ignored', () async {
    final c = await open();
    hub.controller.add(DmMessageEvent(roomId: 'other', kind: 'D', roomStatus: 'Active', message: msgOf(1)));
    await settle();
    expect(c.messages, isEmpty);
  });

  test('expired messages are removed at expiresAt', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, expires: '2026-11-27T09:00:00Z'), msgOf(2, expires: '2026-11-27T11:00:00Z')], lastSeq: 2));
    final c = await open();
    clock = DateTime.utc(2026, 11, 27, 10);
    c.removeExpired();
    expect(c.messages.map((m) => m.seq), [2]);
  });

  test('read pointer only moves forward', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1), msgOf(2)], lastSeq: 2));
    final c = await open();
    expect(hub.reads, [('r1', 2)]);
    c.markRead();
    expect(hub.reads, hasLength(1));
    await c.applyIncoming(msgOf(3));
    expect(hub.reads.last, ('r1', 3));
    hub.controller.add(const DmReadEvent(roomId: 'r1', userId: peerId, seq: 3));
    await settle();
    hub.controller.add(const DmReadEvent(roomId: 'r1', userId: peerId, seq: 1));
    await settle();
    expect(c.peerLastReadSeq.value, 3);
  });

  test('awaiting reply locks the composer and gives the text back', () async {
    api.roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true));
    final c = await open();
    expect(c.canSend, isTrue);
    hub.hubReplies.add({'ok': false, 'type': 'AwaitingReply', 'message': 'Wait for a reply before you send more.'});
    await c.send('Second');
    expect(c.lock, RoomLock.awaitingReply);
    expect(c.canSend, isFalse);
    expect(c.messages, isEmpty);
    expect(c.bounced.value, 'Second');
  });

  test('room changed event unlocks after the reply', () async {
    api.roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true, lock: 'awaitingReply', canSend: false));
    final c = await open();
    expect(c.canSend, isFalse);
    hub.controller.add(const DmRoomChangedEvent(roomId: 'r1', status: 'Active', lock: 'none'));
    await settle();
    expect(c.canSend, isTrue);
  });

  test('the receiver reply activates the room; a Free receiver then gets the Plus lock from the server', () async {
    api.roomResult = BuddyOk(roomOf(status: 'Request', iStarted: false));
    final c = await open();
    api.roomResult = BuddyOk(roomOf(status: 'Active', iStarted: false, lock: RoomLock.plus, canSend: false));
    hub.hubReplies.add({'ok': true, 'message': messageJson(2, sender: myId, cid: 'cid0')});
    await c.send('Yes');
    await settle();
    expect(c.room.value?.status, RoomStatus.active);
    expect(c.repliedFree.value, isTrue);
    expect(c.plusLockShown, isTrue);
    expect(c.canSend, isFalse);
  });

  test('I-9 a Free sender in an active chat: composer before his message, Plus lock after it', () async {
    Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
    final c = await open();
    expect(c.canSend, isTrue);
    expect(c.plusLockShown, isFalse);
    api.roomResult = BuddyOk(roomOf(lock: RoomLock.plus, canSend: false));
    hub.hubReplies.add({'ok': true, 'message': messageJson(1, sender: myId, cid: 'cid0')});
    await c.send('Hello');
    await settle();
    expect(c.plusLockShown, isTrue);
    expect(c.canSend, isFalse);
  });

  test('I-9 a Plus sender keeps chatting: no room re-read after his message', () async {
    Get.put<SocialMeController>(FakeSocialMeController(plusLimits()));
    final c = await open();
    final before = api.roomCalls;
    hub.hubReplies.add({'ok': true, 'message': messageJson(1, sender: myId, cid: 'cid0')});
    await c.send('Hello');
    await settle();
    expect(api.roomCalls, before);
    expect(c.canSend, isTrue);
  });

  test('I-9 a PlusRequired refusal in a direct chat gives the text back and shows the Plus lock', () async {
    final c = await open();
    hub.hubReplies.add({'ok': false, 'type': 'PlusRequired', 'message': 'Get Plus to keep chatting.'});
    await c.send('Second');
    expect(c.bounced.value, 'Second');
    expect(c.plusLocked.value, isTrue);
    expect(c.canSend, isFalse);
  });

  test('new chat limit from a preflight chat sets the limit lock', () async {
    api.preflightResult = BuddyOk(ChatPreflight.fromJson({'room': null, 'peer': personJson(peerId, 'Kavya'), 'canMessage': true, 'lock': 'none', 'newChats': {'limit': 3, 'used': 2}}));
    api.startResult = const BuddyRefused(type: 'NewChatLimit', statusCode: 429);
    final c = await open(roomId: null, userId: peerId);
    expect(c.view.value, RoomView.ready);
    await c.send('Hi');
    expect(c.lock, RoomLock.limit);
    expect(c.refusal.value?.type, 'NewChatLimit');
  });

  test('a missing room shows gone', () async {
    api.roomResult = const BuddyRefused(type: 'RoomNotFound', statusCode: 404);
    final c = await open();
    expect(c.view.value, RoomView.gone);
  });

  List<ChatMessageModel> run(int from, int to) => [for (var i = from; i <= to; i++) msgOf(i)];

  test('a gap longer than one page is read page by page up to the head', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1)], lastSeq: 1));
    final c = await open();
    api.afterQueue
      ..add(BuddyOk(MessagesPage(items: run(2, 101), lastSeq: 160)))
      ..add(BuddyOk(MessagesPage(items: run(102, 160), lastSeq: 160)));
    hub.controller.add(DmMessageEvent(roomId: 'r1', kind: 'D', roomStatus: 'Active', message: msgOf(160)));
    await settle();
    expect(api.afterCalls, [1, 101]);
    expect(api.afterLimits, [RoomController.pageMax, RoomController.pageMax]);
    expect(c.messages.map((m) => m.seq), [for (var i = 1; i <= 160; i++) i]);
    expect(c.lastSeq, 160);
  });

  test('a failed page keeps lastSeq at the last message really read', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1)], lastSeq: 1));
    final c = await open();
    api.afterQueue
      ..add(BuddyOk(MessagesPage(items: run(2, 101), lastSeq: 160)))
      ..add(const BuddyOffline());
    hub.controller.add(DmMessageEvent(roomId: 'r1', kind: 'D', roomStatus: 'Active', message: msgOf(160)));
    await settle();
    expect(c.lastSeq, 101);
    expect(c.messages.any((m) => m.seq == 160), isFalse);
    api.afterQueue.add(BuddyOk(MessagesPage(items: run(102, 160), lastSeq: 160)));
    await c.fillGap();
    expect(c.messages.map((m) => m.seq).last, 160);
    expect(c.messages, hasLength(160));
  });

  test('a message that arrives while a fill runs waits for it and does not skip the gap', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1)], lastSeq: 1));
    final c = await open();
    final gate = Completer<void>();
    api.afterGate = gate;
    api.afterResult = BuddyOk(MessagesPage(items: run(2, 5), lastSeq: 5));
    final fill = c.fillGap();
    await c.applyIncoming(msgOf(6));
    expect(c.lastSeq, 1);
    expect(c.messages.map((m) => m.seq), [1]);
    gate.complete();
    await fill;
    expect(c.messages.map((m) => m.seq), [1, 2, 3, 4, 5, 6]);
    expect(c.lastSeq, 6);
  });

  test('older messages load above the newest page without moving the read pointer', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: run(51, 100), lastSeq: 100));
    final c = await open();
    expect(c.hasOlder.value, isTrue);
    final reads = hub.reads.length;
    api.beforeResult = BuddyOk(MessagesPage(items: run(11, 50), lastSeq: 100));
    await c.loadOlder();
    expect(api.beforeCalls, [51]);
    expect(c.messages.first.seq, 11);
    expect(c.messages, hasLength(90));
    expect(c.hasOlder.value, isFalse);
    expect(c.lastSeq, 100);
    expect(hub.reads, hasLength(reads));
    await c.loadOlder();
    expect(api.beforeCalls, [51]);
  });

  test('a message in the background is not marked read until the app resumes', () async {
    var fg = false;
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1)], lastSeq: 1));
    final c = await open(foreground: () => fg);
    expect(hub.reads, isEmpty);
    await c.applyIncoming(msgOf(2));
    expect(hub.reads, isEmpty);
    fg = true;
    c.markRead();
    expect(hub.reads, [('r1', 2)]);
  });

  test('a room hidden under another open room does not mark read', () async {
    api.messagesResult = BuddyOk(MessagesPage(items: [msgOf(1)], lastSeq: 1));
    OpenRoomTracker.open('r1');
    final c = await open();
    expect(hub.reads, [('r1', 1)]);
    OpenRoomTracker.open('r2');
    await c.applyIncoming(msgOf(2));
    expect(hub.reads, hasLength(1));
    OpenRoomTracker.close('r2');
    expect(OpenRoomTracker.current, 'r1');
    c.markRead();
    expect(hub.reads.last, ('r1', 2));
  });

  test('buying Plus re-reads the room and unlocks the composer', () async {
    final me = FakeSocialMeController(freeLimits());
    Get.put<SocialMeController>(me);
    api.roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true, lock: 'limit', canSend: false));
    final c = await open();
    expect(c.canSend, isFalse);
    api.roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true));
    me.me.value = SocialMe(limits: plusLimits());
    await settle();
    expect(c.canSend, isTrue);
  });

  test('refreshLock re-reads the preflight when there is no room yet', () async {
    api.preflightResult = BuddyOk(ChatPreflight.fromJson({'room': null, 'peer': personJson(peerId, 'Kavya'), 'canMessage': true, 'lock': 'limit', 'newChats': {'limit': 3, 'used': 3}}));
    final c = await open(roomId: null, userId: peerId);
    expect(c.canSend, isFalse);
    api.preflightResult = BuddyOk(ChatPreflight.fromJson({'room': null, 'peer': personJson(peerId, 'Kavya'), 'canMessage': true, 'lock': 'none', 'newChats': {'limit': 10, 'used': 3}}));
    await c.refreshLock();
    expect(api.withUserCalls, 2);
    expect(c.canSend, isTrue);
  });

  group('I-39 who can send messages', () {
    ChatRoomModel tripRoom({bool isOwner = false, bool only = false, String lock = 'none', bool canSend = true, String owner = 'Rahul'}) =>
        roomOf(kind: 'T', lock: lock, canSend: canSend, trip: tripJson(isOwner: isOwner, onlyOwnerSends: only, ownerName: owner));

    test('a member with Only me on cannot send and sees the owner-only notice', () async {
      api.roomResult = BuddyOk(tripRoom(only: true, lock: RoomLock.ownerOnly, canSend: false));
      final c = await open();
      expect(c.ownerOnlyShown, isTrue);
      expect(c.canSend, isFalse);
      expect(c.plusLockShown, isFalse);
    });

    test('the owner keeps sending with Only me on', () async {
      api.roomResult = BuddyOk(tripRoom(isOwner: true, only: true));
      final c = await open();
      expect(c.ownerOnlyShown, isFalse);
      expect(c.canSend, isTrue);
    });

    test('a member who left sees the left notice, not owner-only', () async {
      api.roomResult = BuddyOk(tripRoom(only: true, lock: RoomLock.left, canSend: false));
      final c = await open();
      expect(c.ownerOnlyShown, isFalse);
    });

    test('Everyone mode keeps the usual rules', () async {
      api.roomResult = BuddyOk(tripRoom());
      final c = await open();
      expect(c.ownerOnlyShown, isFalse);
      expect(c.canSend, isTrue);
    });

    test('an OnlyOwnerSends refusal gives the text back, sets the flag and re-reads the room', () async {
      api.roomResult = BuddyOk(tripRoom());
      final c = await open();
      final before = api.roomCalls;
      api.roomResult = BuddyOk(tripRoom(only: true, lock: RoomLock.ownerOnly, canSend: false, owner: 'Rahul'));
      hub.hubReplies.add({'ok': false, 'type': 'OnlyOwnerSends', 'message': 'Only the trip owner can send messages in this chat.'});
      await c.send('Hello');
      await settle();
      expect(c.messages.where((m) => m.isLocal), isEmpty);
      expect(c.bounced.value, 'Hello');
      expect(c.ownerOnlyShown, isTrue);
      expect(c.canSend, isFalse);
      expect(api.roomCalls, before + 1);
      expect(c.refusal.value?.type, 'OnlyOwnerSends');
    });

    test('DmRoomSettings applies the flag at once and re-reads the room', () async {
      api.roomResult = BuddyOk(tripRoom());
      final c = await open();
      final before = api.roomCalls;
      api.roomResult = BuddyOk(tripRoom(only: true, lock: RoomLock.ownerOnly, canSend: false, owner: 'Rahul'));
      hub.controller.add(const DmRoomSettingsEvent(roomId: 'r1', onlyOwnerSends: true, ownerName: 'Rahul'));
      await Future<void>.delayed(Duration.zero);
      expect(c.room.value?.trip?.onlyOwnerSends, isTrue);
      expect(c.ownerOnlyShown, isTrue);
      await settle();
      expect(api.roomCalls, before + 1);
      expect(c.lock, RoomLock.ownerOnly);
    });

    test('DmRoomSettings back to Everyone unlocks after the re-read', () async {
      api.roomResult = BuddyOk(tripRoom(only: true, lock: RoomLock.ownerOnly, canSend: false));
      final c = await open();
      api.roomResult = BuddyOk(tripRoom());
      hub.controller.add(const DmRoomSettingsEvent(roomId: 'r1', onlyOwnerSends: false, ownerName: 'Rahul'));
      await settle();
      expect(c.ownerOnlyShown, isFalse);
      expect(c.canSend, isTrue);
    });

    test('DmRoomSettings of another room is ignored', () async {
      api.roomResult = BuddyOk(tripRoom());
      final c = await open();
      final before = api.roomCalls;
      hub.controller.add(const DmRoomSettingsEvent(roomId: 'other', onlyOwnerSends: true, ownerName: 'Rahul'));
      await settle();
      expect(api.roomCalls, before);
      expect(c.ownerOnlyShown, isFalse);
    });

    test('a reconnect re-reads a trip room, not a direct room', () async {
      api.roomResult = BuddyOk(tripRoom());
      await open();
      final before = api.roomCalls;
      hub.controller.add(const DmReconnectedEvent());
      await settle();
      expect(api.roomCalls, before + 1);
    });

    test('a reconnect does not re-read a direct room', () async {
      await open();
      final before = api.roomCalls;
      hub.controller.add(const DmReconnectedEvent());
      await settle();
      expect(api.roomCalls, before);
    });

    test('setSendMode sends the pick and takes the returned room', () async {
      api.roomResult = BuddyOk(tripRoom(isOwner: true));
      final c = await open();
      api.sendModeResult = BuddyOk(tripRoom(isOwner: true, only: true));
      final r = await c.setSendMode(true);
      expect(r.isOk, isTrue);
      expect(api.sendModes, [true]);
      expect(c.room.value?.trip?.onlyOwnerSends, isTrue);
      expect(c.canSend, isTrue);
    });
  });
}
