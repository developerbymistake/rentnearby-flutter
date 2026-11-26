import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/c/chat/dm_hub_bridge.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/rooms_controller.dart';
import 'package:bakhli/features/social/c/chat/trip_chat_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'chat_fakes.dart';
import 'social_c_test_kit.dart';

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  testWidgets('the trip chat icon shows the unread count of that trip room and follows new messages', (t) async {
    final hub = FakeTransport();
    final api = FakeChatApi()..pages[RoomBucket.trips] = BuddyOk(RoomsPage(items: [roomOf(roomId: 't1', kind: 'T', unread: 2, trip: {'tripId': 'x', 'title': 'Manali'})]));
    Get.put(RoomsController(api: api, transport: hub, myId: () => myId), permanent: true);
    await pumpSocial(t, const Center(child: TripChatBadge(tripId: 'x', child: SizedBox(width: 44, height: 44))));
    expect(find.descendant(of: find.byKey(const ValueKey('trip_chat_unread')), matching: find.text('2')), findsOneWidget);
    hub.controller.add(DmMessageEvent(roomId: 't1', kind: 'T', roomStatus: 'Active', message: msgOf(9, senderName: 'Rohan M.')));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.descendant(of: find.byKey(const ValueKey('trip_chat_unread')), matching: find.text('3')), findsOneWidget);
    await disposeSocial(t);
  });

  testWidgets('another trip or no unread shows no badge', (t) async {
    final api = FakeChatApi()..pages[RoomBucket.trips] = BuddyOk(RoomsPage(items: [roomOf(roomId: 't1', kind: 'T', unread: 2, trip: {'tripId': 'x', 'title': 'Manali'})]));
    Get.put(RoomsController(api: api, transport: FakeTransport(), myId: () => myId), permanent: true);
    await pumpSocial(t, const Center(child: TripChatBadge(tripId: 'y', child: SizedBox(width: 44, height: 44))));
    expect(find.byKey(const ValueKey('trip_chat_unread')), findsNothing);
    await disposeSocial(t);
  });
}
