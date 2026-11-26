import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/c/chat/dm_room_screen.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/room_controller.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'chat_fakes.dart';
import 'plus_fakes.dart';
import 'social_c_test_kit.dart';

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  RoomController controller(FakeChatApi api) => RoomController(roomId: 'r1', api: api, transport: FakeTransport(), myId: () => myId);

  for (final w in socialWidths) {
    for (final s in socialScales) {
      final at = '${w.toInt()} x$s';

      testWidgets('sender after the first message sees the lock and Chat more with Plus ($at)', (t) async {
        final api = FakeChatApi()
          ..roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true, lock: 'awaitingReply', canSend: false))
          ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, sender: myId, text: 'Hi Kavya, are you going in mid Dec too?')], lastSeq: 1));
        await pumpSocial(t, DmRoomScreen(controller: controller(api)), width: w, scale: s);
        expect(find.text(SocialStringsC.firstMessageTitle), findsOneWidget);
        expect(find.byKey(const ValueKey('dm_chat_more_plus')), findsOneWidget);
        expect(find.byKey(const ValueKey('dm_composer')), findsNothing);
        expect(find.text(SocialStringsC.safety), findsOneWidget);
        expect(find.descendant(of: find.byType(ListView), matching: find.text(SocialStringsC.safety)), findsNothing);
        expect(t.widget<GradientPillButton>(find.byKey(const ValueKey('dm_chat_more_plus'))).tone, same(ListingTone.cF));
        expect(find.text(SocialStringsC.disappear), findsOneWidget);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });

      testWidgets('receiver of a request replies free and has Delete, Report, Block ($at)', (t) async {
        final api = FakeChatApi()
          ..roomResult = BuddyOk(roomOf(status: 'Request', iStarted: false))
          ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, text: 'Hi, I saw your Rishikesh plan.')], lastSeq: 1));
        await pumpSocial(t, DmRoomScreen(controller: controller(api)), width: w, scale: s);
        expect(find.text(SocialStringsC.replyFree), findsOneWidget);
        expect(find.byKey(const ValueKey('dm_receiver_delete')), findsOneWidget);
        expect(find.byKey(const ValueKey('dm_receiver_report')), findsOneWidget);
        expect(find.byKey(const ValueKey('dm_receiver_block')), findsOneWidget);
        expect(find.descendant(of: find.byType(ListView), matching: find.byKey(const ValueKey('dm_receiver_delete'))), findsNothing);
        expect(t.getTopLeft(find.byKey(const ValueKey('dm_receiver_delete'))).dy, greaterThan(t.getTopLeft(find.text(SocialStringsC.safety)).dy));
        expect(find.text(SocialStringsC.receiverInfo('Kavya')), findsOneWidget);
        expect(find.text(SocialStringsC.firstMessageTitle), findsNothing);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });

      testWidgets('trip room shows names on bubbles and the join line ($at)', (t) async {
        final trip = roomOf(kind: 'T', trip: {'tripId': 't1', 'title': 'Manali', 'memberCount': 4, 'photoUrls': []});
        final api = FakeChatApi()
          ..roomResult = BuddyOk(trip)
          ..messagesResult = BuddyOk(MessagesPage(items: [
            msgOf(1, system: 'joined', text: 'Meera joined the trip'),
            msgOf(2, sender: 'u-rohan', senderName: 'Rohan M.', text: 'Booked the cab for 6 AM from Delhi.'),
          ], lastSeq: 2));
        await pumpSocial(t, DmRoomScreen(controller: controller(api)), width: w, scale: s);
        expect(find.text('Manali'), findsOneWidget);
        expect(find.text(SocialStringsC.members(4)), findsOneWidget);
        expect(find.text('Meera joined the trip'), findsOneWidget);
        expect(find.descendant(of: find.byType(ChatBubble3D), matching: find.text('Rohan M.')), findsOneWidget);
        expect(t.widget<ChatSystemNote>(find.ancestor(of: find.text('Meera joined the trip'), matching: find.byType(ChatSystemNote))).colors, BuddyLook.note[NoteToneColor.teal]);
        expect(find.byKey(const ValueKey('dm_trip_art')), findsOneWidget);
        expect(find.text('Booked the cab for 6 AM from Delhi.'), findsOneWidget);
        expect(find.text(SocialStringsC.safety), findsNothing);
        expect(find.byKey(const ValueKey('dm_composer')), findsOneWidget);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });

      testWidgets('my masked message shows the safety note ($at)', (t) async {
        final api = FakeChatApi()
          ..roomResult = BuddyOk(roomOf())
          ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, sender: myId, masked: true, text: 'Call me on •••• hidden')], lastSeq: 1));
        await pumpSocial(t, DmRoomScreen(controller: controller(api)), width: w, scale: s);
        expect(find.textContaining('Call me on'), findsOneWidget);
        expect(find.descendant(of: find.byType(ChatBubble3D), matching: find.text(SocialStringsC.maskToken)), findsOneWidget);
        expect(find.text(SocialStringsC.masked), findsOneWidget);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }
  }

  testWidgets('a left trip member sees no composer', (t) async {
    final api = FakeChatApi()..roomResult = BuddyOk(roomOf(kind: 'T', lock: 'left', canSend: false, trip: {'tripId': 't1', 'title': 'Manali'}));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    expect(find.text(SocialStringsC.leftTrip), findsOneWidget);
    expect(find.byKey(const ValueKey('dm_composer')), findsNothing);
    await disposeSocial(t);
  });

  testWidgets('a missing room shows the gone state', (t) async {
    final api = FakeChatApi()..roomResult = const BuddyRefused(type: 'RoomNotFound', statusCode: 404);
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    expect(find.byKey(const ValueKey('dm_composer')), findsNothing);
    expect(t.takeException(), isNull);
    await disposeSocial(t);
  });

  testWidgets('a left trip member gets the pinned notice panel', (t) async {
    final api = FakeChatApi()..roomResult = BuddyOk(roomOf(kind: 'T', lock: 'left', canSend: false, trip: {'tripId': 't1', 'title': 'Manali'}));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    expect(find.byKey(const ValueKey('dm_notice')), findsOneWidget);
    expect(find.byType(ChatNoticePanel3D), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeSocial(t);
  });

  testWidgets('the send button is faded and has no glow while the text is empty', (t) async {
    final api = FakeChatApi()..roomResult = BuddyOk(roomOf());
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    Opacity sendOpacity() => t.widget<Opacity>(find.descendant(of: find.byKey(const ValueKey('dm_send')), matching: find.byType(Opacity)).first);
    expect(sendOpacity().opacity, Alpha.v45);
    await t.enterText(find.byKey(const ValueKey('dm_composer')), 'Hello');
    await t.pump();
    expect(sendOpacity().opacity, Alpha.full);
    await disposeSocial(t);
  });

  testWidgets('a locked room opens the composer once Plus turns on', (t) async {
    final me = Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
    final api = FakeChatApi()..roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true, lock: 'limit', canSend: false));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    expect(find.byKey(const ValueKey('dm_lock_limit')), findsOneWidget);
    expect(find.byKey(const ValueKey('dm_composer')), findsNothing);
    api.roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true));
    me.me.value = SocialMe(limits: plusLimits());
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('dm_lock_limit')), findsNothing);
    expect(t.widget<TextField>(find.byKey(const ValueKey('dm_composer'))).enabled, isTrue);
    await disposeSocial(t);
  });

  testWidgets('scrolling to the top loads older messages', (t) async {
    final api = FakeChatApi()
      ..roomResult = BuddyOk(roomOf())
      ..messagesResult = BuddyOk(MessagesPage(items: [for (var i = 51; i <= 100; i++) msgOf(i, text: 'Message $i')], lastSeq: 100))
      ..beforeResult = BuddyOk(MessagesPage(items: [for (var i = 41; i <= 50; i++) msgOf(i, text: 'Message $i')], lastSeq: 100));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    await t.drag(find.byType(ListView).first, const Offset(0, 20000));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(api.beforeCalls, [51]);
    expect(t.takeException(), isNull);
    await disposeSocial(t);
  });
}
