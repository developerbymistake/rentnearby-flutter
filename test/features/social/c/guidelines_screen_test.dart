import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/c/chat/dm_room_screen.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/room_controller.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/widgets/safety_guidelines_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'chat_fakes.dart';
import 'guidelines_gate_test.dart' show GateMe;
import 'social_c_test_kit.dart';

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  RoomController controller(FakeChatApi api, FakeTransport hub, {String? roomId = 'r1', String? tripId}) =>
      RoomController(roomId: roomId, tripId: tripId, api: api, transport: hub, myId: () => myId, newId: () => 'cid0');

  testWidgets('first Send: the sheet shows, closing keeps the text in the composer and sends nothing; Understood sends it', (t) async {
    final me = GateMe(accepted: false);
    Get.put<SocialMeController>(me);
    final api = FakeChatApi()..roomResult = BuddyOk(roomOf());
    final hub = FakeTransport();
    await pumpSocial(t, DmRoomScreen(controller: controller(api, hub)));
    await t.enterText(find.byKey(const ValueKey('dm_composer')), 'Hello Kavya');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('dm_send')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Keep it safe with Kavya'), findsOneWidget);

    await t.tapAt(const Offset(10, 10));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsNothing);
    expect(t.widget<TextField>(find.byKey(const ValueKey('dm_composer'))).controller!.text, 'Hello Kavya');
    expect(hub.hubIds, isEmpty);
    expect(api.sentIds, isEmpty);

    hub.hubReplies.add({'ok': true, 'message': messageJson(1, sender: myId, text: 'Hello Kavya', cid: 'cid0')});
    await t.tap(find.byKey(const ValueKey('dm_send')));
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(SafetyGuidelinesSheet.understoodKey));
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(me.accepts, 1);
    expect(hub.hubIds, ['cid0']);
    expect(find.text('Hello Kavya'), findsOneWidget);
    expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsNothing);
    await disposeSocial(t);
  });

  testWidgets('accepted: Send goes straight through, no sheet', (t) async {
    Get.put<SocialMeController>(GateMe(accepted: true));
    final api = FakeChatApi()..roomResult = BuddyOk(roomOf());
    final hub = FakeTransport()..hubReplies.add({'ok': true, 'message': messageJson(1, sender: myId, text: 'Hi', cid: 'cid0')});
    await pumpSocial(t, DmRoomScreen(controller: controller(api, hub)));
    await t.enterText(find.byKey(const ValueKey('dm_composer')), 'Hi');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('dm_send')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsNothing);
    expect(hub.hubIds, ['cid0']);
    await disposeSocial(t);
  });

  testWidgets('first entry to a trip chat shows the group sheet once', (t) async {
    final me = GateMe(accepted: false);
    Get.put<SocialMeController>(me);
    final trip = roomOf(kind: 'T', trip: {'tripId': 't1', 'title': 'Manali', 'memberCount': 3, 'photoUrls': []});
    final api = FakeChatApi()..roomResult = BuddyOk(trip);
    await pumpSocial(t, DmRoomScreen(tripId: 't1', controller: controller(api, FakeTransport(), roomId: null, tripId: 't1')));
    expect(find.text('Keep your trip chat safe'), findsOneWidget);
    await t.tap(find.byKey(SafetyGuidelinesSheet.understoodKey));
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    expect(me.accepts, 1);
    expect(find.text('Keep your trip chat safe'), findsNothing);
    await disposeSocial(t);
  });

  testWidgets('a person whose policy blocks me: the cannot-message notice shows and the composer is gone', (t) async {
    Get.put<SocialMeController>(GateMe(accepted: true));
    final api = FakeChatApi()
      ..preflightResult = BuddyOk(ChatPreflight.fromJson({'room': null, 'peer': personJson(peerId, 'Kavya Sharma'), 'canMessage': false, 'lock': 'none', 'newChats': {'limit': 3, 'used': 0}}));
    final c = RoomController(userId: peerId, roomId: null, api: api, transport: FakeTransport(), myId: () => myId);
    await pumpSocial(t, DmRoomScreen(userId: peerId, controller: c));
    expect(find.byKey(const ValueKey('dm_notice')), findsOneWidget);
    expect(find.byKey(const ValueKey('dm_composer')), findsNothing);
    await disposeSocial(t);
  });
}
