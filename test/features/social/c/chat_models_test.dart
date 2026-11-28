import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fakes.dart';

void main() {
  test('room parses every field of the contract', () {
    final r = ChatRoomModel.fromJson(roomJson(status: 'Request', iStarted: false, lock: 'awaitingReply', canSend: false, lastSeq: 4, unread: 2, preview: 'Hi'));
    expect(r.roomId, 'r1');
    expect(r.kind, RoomKind.direct);
    expect(r.isRequest, isTrue);
    expect(r.isIncomingRequest, isTrue);
    expect(r.peer?.name, 'Kavya Sharma');
    expect(r.lastSeq, 4);
    expect(r.unread, 2);
    expect(r.lock, RoomLock.awaitingReply);
    expect(r.canSend, isFalse);
    expect(r.lastMessageAt, isNotNull);
  });

  test('trip room reads the trip block', () {
    final r = ChatRoomModel.fromJson(roomJson(kind: 'T', trip: {'tripId': 't1', 'title': 'Manali', 'memberCount': 4, 'photoUrls': ['a'], 'memberInitials': ['R', 'M', 'A'], 'cityKey': 42}));
    expect(r.isTrip, isTrue);
    expect(r.trip?.cityKey, 42);
    expect(r.trip?.initials, ['R', 'M', 'A']);
    expect(r.peer, isNull);
    expect(r.trip?.title, 'Manali');
    expect(r.trip?.memberCount, 4);
    expect(r.title, 'Manali');
  });

  test('room is defensive on an empty map', () {
    final r = ChatRoomModel.fromJson(const {});
    expect(r.roomId, '');
    expect(r.kind, RoomKind.direct);
    expect(r.status, RoomStatus.active);
    expect(r.lock, RoomLock.none);
    expect(r.canSend, isTrue);
    expect(r.peerLastReadSeq, isNull);
  });

  test('message parses system lines and ignores unknown system kinds', () {
    final joined = ChatMessageModel.fromJson(messageJson(3, system: 'joined', text: 'Meera joined the trip'));
    expect(joined.isSystem, isTrue);
    expect(joined.senderId, isNull);
    final odd = ChatMessageModel.fromJson({...messageJson(4), 'system': 'typing'});
    expect(odd.isSystem, isFalse);
    final masked = ChatMessageModel.fromJson(messageJson(5, masked: true, text: 'Call •••• hidden', cid: 'c1'));
    expect(masked.masked, isTrue);
    expect(masked.clientMessageId, 'c1');
    expect(masked.expiresAt, isNotNull);
    expect(masked.isLocal, isFalse);
  });

  test('message is defensive on nulls', () {
    final m = ChatMessageModel.fromJson(const {'seq': null, 'text': null});
    expect(m.seq, 0);
    expect(m.text, '');
    expect(m.isLocal, isTrue);
    expect(m.createdAt, isNull);
  });

  test('preflight, started chat, pages', () {
    final p = ChatPreflight.fromJson({'room': null, 'peer': personJson(peerId, 'Kavya'), 'canMessage': true, 'lock': 'limit', 'newChats': {'limit': 3, 'used': 3}, 'isFree': false});
    expect(p.room, isNull);
    expect(p.canMessage, isTrue);
    expect(p.lock, RoomLock.limit);
    expect(p.newChats.reached, isTrue);
    final s = StartedChat.fromJson({'room': roomJson(), 'message': messageJson(1, sender: myId)});
    expect(s.message.seq, 1);
    final rp = RoomsPage.fromJson({'items': [roomJson()], 'nextCursor': 'x', 'unread': {'people': 1, 'trips': 2, 'requests': 3, 'total': 6}});
    expect(rp.items, hasLength(1));
    expect(rp.unread.total, 6);
    final mp = MessagesPage.fromJson({'items': [messageJson(1), messageJson(2)], 'lastSeq': 2, 'peerLastReadSeq': 1});
    expect(mp.lastSeq, 2);
    expect(mp.peerLastReadSeq, 1);
  });

  test('I-39 trip block reads owner fields and copyWith keeps the rest', () {
    final r = ChatRoomModel.fromJson(roomJson(kind: 'T', lock: 'ownerOnly', canSend: false, trip: tripJson(isOwner: false, ownerName: 'Rahul', onlyOwnerSends: true)));
    expect(r.lock, RoomLock.ownerOnly);
    expect(r.trip?.isOwner, isFalse);
    expect(r.trip?.ownerName, 'Rahul');
    expect(r.trip?.onlyOwnerSends, isTrue);
    final off = r.copyWith(trip: r.trip!.copyWith(onlyOwnerSends: false));
    expect(off.trip?.onlyOwnerSends, isFalse);
    expect(off.trip?.ownerName, 'Rahul');
    expect(off.trip?.title, 'Goa trip');
    expect(off.lock, RoomLock.ownerOnly);
    expect(r.copyWith(unread: 2).trip?.onlyOwnerSends, isTrue);
  });

  test('I-39 trip block defaults when the owner fields are missing', () {
    final t = RoomTrip.fromJson(const {'tripId': 't1', 'title': 'Goa'});
    expect(t.isOwner, isFalse);
    expect(t.ownerName, '');
    expect(t.onlyOwnerSends, isFalse);
  });

  test('I-39 the sendmode line is a system line', () {
    final m = ChatMessageModel.fromJson(messageJson(6, system: 'sendmode', text: 'Rahul changed who can send messages'));
    expect(m.isSystem, isTrue);
    expect(m.system, ChatMessageModel.sendMode);
    expect(m.senderId, isNull);
  });
}
