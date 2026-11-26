import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/c/chat/dm_hub_bridge.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/open_room_tracker.dart';
import 'package:bakhli/features/social/c/chat/rooms_controller.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'chat_fakes.dart';
import 'plus_fakes.dart';

void main() {
  late FakeChatApi api;
  late FakeTransport hub;

  setUp(() {
    api = FakeChatApi();
    hub = FakeTransport();
    OpenRoomTracker.clear();
  });
  tearDown(Get.reset);

  RoomsController make() => Get.put(RoomsController(api: api, transport: hub, myId: () => myId));

  test('each bucket loads its own list and the unread counts', () async {
    const unread = ChatUnread(people: 2, trips: 1, requests: 1, total: 4);
    api.pages[RoomBucket.people] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'p1'), roomOf(roomId: 'p2')], unread: unread));
    api.pages[RoomBucket.trips] = BuddyOk(RoomsPage(items: [roomOf(roomId: 't1', kind: 'T', trip: {'tripId': 'x', 'title': 'Manali'})], unread: unread));
    api.pages[RoomBucket.requests] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'q1', status: 'Request', iStarted: false)], unread: unread));
    final c = make();
    await c.reloadAll();
    expect(c.people.items.map((r) => r.roomId), ['p1', 'p2']);
    expect(c.trips.items.single.isTrip, isTrue);
    expect(c.requests.items.single.isIncomingRequest, isTrue);
    expect(c.people.state.value, RoomsLoad.ready);
    expect(c.unread.value.total, 4);
  });

  test('an offline first load shows offline', () async {
    api.pages[RoomBucket.people] = const BuddyOffline();
    final c = make();
    await c.load(RoomBucket.people);
    expect(c.people.state.value, RoomsLoad.offline);
  });

  test('unread from the hub replaces the counts', () async {
    final c = make();
    hub.controller.add(const DmUnreadEvent(ChatUnread(people: 3, trips: 0, requests: 1, total: 4)));
    await settle();
    expect(c.unread.value.people, 3);
    expect(c.unread.value.total, 4);
  });

  test('a new message moves the room to the top and counts it unread', () async {
    api.pages[RoomBucket.people] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'p1'), roomOf(roomId: 'p2')]));
    final c = make();
    await c.load(RoomBucket.people);
    hub.controller.add(DmMessageEvent(roomId: 'p2', kind: 'D', roomStatus: 'Active', message: msgOf(7, text: 'See you at 7')));
    await settle();
    expect(c.people.items.first.roomId, 'p2');
    expect(c.people.items.first.unread, 1);
    expect(c.people.items.first.preview, 'See you at 7');
  });

  test('my own message and the open room do not add unread', () async {
    api.pages[RoomBucket.people] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'p1')]));
    final c = make();
    await c.load(RoomBucket.people);
    hub.controller.add(DmMessageEvent(roomId: 'p1', kind: 'D', roomStatus: 'Active', message: msgOf(2, sender: myId)));
    await settle();
    expect(c.people.items.first.unread, 0);
    OpenRoomTracker.open('p1');
    hub.controller.add(DmMessageEvent(roomId: 'p1', kind: 'D', roomStatus: 'Active', message: msgOf(3)));
    await settle();
    expect(c.people.items.first.unread, 0);
  });

  test('trip rooms show the sender name in the preview', () async {
    api.pages[RoomBucket.trips] = BuddyOk(RoomsPage(items: [roomOf(roomId: 't1', kind: 'T', trip: {'tripId': 'x', 'title': 'Manali'})]));
    final c = make();
    await c.load(RoomBucket.trips);
    hub.controller.add(DmMessageEvent(roomId: 't1', kind: 'T', roomStatus: 'Active', message: msgOf(4, text: 'Booked the cab', senderName: 'Rohan M.')));
    await settle();
    expect(c.trips.items.first.preview, 'Rohan M.: Booked the cab');
  });

  test('a request that becomes active leaves the Requests list', () async {
    api.pages[RoomBucket.requests] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'q1', status: 'Request', iStarted: false)]));
    final c = make();
    await c.load(RoomBucket.requests);
    hub.controller.add(const DmRoomChangedEvent(roomId: 'q1', status: 'Active', lock: 'none'));
    await settle();
    expect(c.requests.items, isEmpty);
  });

  test('delete removes the room from every list', () async {
    api.pages[RoomBucket.requests] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'q1', status: 'Request', iStarted: false)]));
    final c = make();
    await c.load(RoomBucket.requests);
    expect(await c.deleteRoom('q1'), isTrue);
    expect(api.deleted, ['q1']);
    expect(c.requests.items, isEmpty);
  });

  test('unread starts from the social me counts so the header badge is right before the chats list opens', () async {
    const counts = ChatUnread(people: 1, trips: 2, requests: 0, total: 3);
    final me = Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
    me.me.value = SocialMe(limits: freeLimits(), chatUnread: counts);
    final c = make();
    expect(c.unread.value.total, 3);
    me.applyUnread(const ChatUnread(people: 0, trips: 1, requests: 0, total: 1));
    expect(c.unread.value.total, 1);
  });

  test('session end clears everything', () async {
    api.pages[RoomBucket.people] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'p1')]));
    final c = make();
    await c.load(RoomBucket.people);
    hub.controller.add(const DmSessionEndedEvent('logout'));
    await settle();
    expect(c.people.items, isEmpty);
    expect(c.unread.value.total, 0);
  });
}
