import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/a/widgets/social_chips_a.dart';
import 'package:bakhli/features/social/c/chat/dm_room_screen.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/room_controller.dart';
import 'package:bakhli/features/social/c/chat/who_can_send_sheet.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/c/widgets/chat_room_header.dart';
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

      testWidgets('I-9 a Free sender after his one message sees the Plus lock and Chat more with Plus ($at)', (t) async {
        final api = FakeChatApi()
          ..roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true, lock: 'plus', canSend: false))
          ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, sender: myId, text: 'Hi Kavya, are you going in mid Dec too?')], lastSeq: 1));
        await pumpSocial(t, DmRoomScreen(controller: controller(api)), width: w, scale: s);
        expect(find.text(SocialStringsC.freeMessageUsedTitle), findsOneWidget);
        expect(find.text(SocialStringsC.freeMessageUsedLine), findsOneWidget);
        expect(find.byKey(const ValueKey('dm_lock_plus')), findsOneWidget);
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
        expect(find.text(SocialStringsC.freeMessageUsedTitle), findsNothing);
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
        expect(t.getTopLeft(find.text('Rohan M.')).dx, closeTo(t.getTopLeft(find.text('Booked the cab for 6 AM from Delhi.')).dx, 0.5));
        expect(t.widget<ChatSystemNote>(find.ancestor(of: find.text('Meera joined the trip'), matching: find.byType(ChatSystemNote))).colors, BuddyLook.note[NoteToneColor.teal]);
        expect(find.byKey(const ValueKey('dm_trip_art')), findsOneWidget);
        expect(find.text('Booked the cab for 6 AM from Delhi.'), findsOneWidget);
        expect(find.byKey(const ValueKey('dm_trip_safety')), findsOneWidget);
        expect(find.byKey(const ValueKey('dm_pinned_safety')), findsNothing);
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

  testWidgets('trip bubbles and the direct header show short names', (t) async {
    final trip = roomOf(kind: 'T', trip: {'tripId': 't1', 'title': 'Manali', 'memberCount': 4, 'photoUrls': []});
    final api = FakeChatApi()
      ..roomResult = BuddyOk(trip)
      ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, sender: 'u-meera', senderName: 'Meera Joshi', text: 'Hi all!')], lastSeq: 1));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    expect(find.descendant(of: find.byType(ChatBubble3D), matching: find.text('Meera J.')), findsOneWidget);
    expect(find.text('Meera Joshi'), findsNothing);
    await disposeSocial(t);

    final direct = FakeChatApi()
      ..roomResult = BuddyOk(roomOf())
      ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, text: 'Hi')], lastSeq: 1));
    await pumpSocial(t, DmRoomScreen(controller: controller(direct)));
    expect(find.descendant(of: find.byType(ChatRoomHeader), matching: find.text('Kavya S.')), findsOneWidget);
    expect(find.text('Kavya Sharma'), findsNothing);
    await disposeSocial(t);
  });

  void expectCompactRow(WidgetTester t, Finder avatar) {
    final header = find.byKey(const ValueKey('dm_room_header'));
    expect(header, findsOneWidget);
    expect(find.byType(ChatHeader3D), findsNothing);
    expect(find.descendant(of: header, matching: find.byType(Art3D)), findsNothing);
    expect(find.descendant(of: header, matching: find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == ListingArt.speechBalloon)), findsNothing);
    final back = find.descendant(of: header, matching: find.byIcon(Icons.chevron_left_rounded));
    final more = find.byKey(const ValueKey('dm_room_more'));
    final cy = t.getCenter(back).dy;
    expect(t.getCenter(avatar).dy, closeTo(cy, 1));
    expect(t.getCenter(more).dy, closeTo(cy, 1));
    expect(t.getCenter(back).dx, lessThan(t.getCenter(avatar).dx));
    expect(t.getCenter(avatar).dx, lessThan(t.getCenter(more).dx));
    expect(t.getSize(header).height, lessThan(DS.s(90)));
  }

  testWidgets('direct chat header is one compact row with no chat art', (t) async {
    final api = FakeChatApi()
      ..roomResult = BuddyOk(roomOf())
      ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, text: 'Hi')], lastSeq: 1));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    expectCompactRow(t, find.byKey(const ValueKey('chat_room_header_avatar')));
    expect(find.descendant(of: find.byKey(const ValueKey('dm_room_header')), matching: find.text('Kavya S.')), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeSocial(t);
  });

  testWidgets('direct chat header shows a visible coloured gender badge next to the name', (t) async {
    final api = FakeChatApi()
      ..roomResult = BuddyOk(roomOf(peerGender: 'Female'))
      ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, text: 'Hi')], lastSeq: 1));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    final glyph = find.descendant(of: find.byKey(const ValueKey('dm_room_header')), matching: find.byType(GenderGlyph));
    expect(glyph, findsOneWidget);
    final g = t.widget<GenderGlyph>(glyph);
    expect(g.badge, isTrue);
    expect(g.color, GenderGlyph.inkOf('Female'));
    expect(t.widget<Icon>(find.descendant(of: glyph, matching: find.byType(Icon))).color, GenderGlyph.inkOf('Female'));
    expect(t.takeException(), isNull);
    await disposeSocial(t);
  });

  testWidgets('receiver Delete is a visible pill, not the screen background colour', (t) async {
    final api = FakeChatApi()
      ..roomResult = BuddyOk(roomOf(status: 'Request', iStarted: false))
      ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, text: 'Hi')], lastSeq: 1));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    final box = t.widget<Container>(find.descendant(of: find.byKey(const ValueKey('dm_receiver_delete')), matching: find.byType(Container)).first);
    final bg = (box.decoration! as BoxDecoration).color;
    expect(bg, BuddyLook.subText.withValues(alpha: Alpha.v10));
    expect(bg, isNot(BuddyLook.closeBg));
    expect(t.takeException(), isNull);
    await disposeSocial(t);
  });

  testWidgets('trip chat header is one compact row with no decorative art', (t) async {
    final api = FakeChatApi()
      ..roomResult = BuddyOk(roomOf(kind: 'T', trip: {'tripId': 't1', 'title': 'Manali', 'memberCount': 4, 'photoUrls': []}))
      ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, text: 'Hi')], lastSeq: 1));
    await pumpSocial(t, DmRoomScreen(controller: controller(api)));
    expectCompactRow(t, find.byKey(const ValueKey('dm_trip_art')));
    expect(t.getSize(find.byKey(const ValueKey('dm_trip_art'))).width, closeTo(DS.s(ChatRoomHeader.avatar), 0.5));
    expect(find.descendant(of: find.byKey(const ValueKey('dm_room_header')), matching: find.text(SocialStringsC.members(4))), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeSocial(t);
  });

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

  group('I-38c / I-39 trip chat', () {
    ChatRoomModel tripRoom({bool isOwner = false, bool only = false, String lock = 'none', bool canSend = true}) =>
        roomOf(kind: 'T', lock: lock, canSend: canSend, trip: tripJson(isOwner: isOwner, onlyOwnerSends: only, ownerName: 'Rahul'));

    Future<void> pumps(WidgetTester t) async {
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> openMenu(WidgetTester t) async {
      await t.tap(find.byKey(const ValueKey('dm_room_more')));
      await pumps(t);
    }

    for (final owner in [true, false]) {
      testWidgets('the safety note is pinned at the top of the trip chat (owner: $owner)', (t) async {
        final api = FakeChatApi()
          ..roomResult = BuddyOk(tripRoom(isOwner: owner))
          ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, sender: 'u-rohan', senderName: 'Rohan M.', text: 'See you at 6')], lastSeq: 1));
        await pumpSocial(t, DmRoomScreen(controller: controller(api)));
        final note = find.byKey(const ValueKey('dm_trip_safety'));
        expect(note, findsOneWidget);
        expect(find.descendant(of: note, matching: find.text(SocialStringsC.safety)), findsOneWidget);
        expect(find.descendant(of: find.byType(ListView), matching: note), findsNothing);
        final headerBottom = t.getBottomLeft(find.byKey(const ValueKey('dm_room_header'))).dy;
        expect(t.getTopLeft(note).dy, greaterThanOrEqualTo(headerBottom - 0.5));
        expect(t.getTopLeft(note).dy, lessThan(t.getTopLeft(find.text('See you at 6')).dy));
        expect(find.byKey(const ValueKey('dm_pinned_safety')), findsNothing);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }

    testWidgets('a 1-to-1 chat keeps its bottom safety note and has no trip note', (t) async {
      final api = FakeChatApi()
        ..roomResult = BuddyOk(roomOf(status: 'Request', iStarted: true))
        ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, sender: myId, text: 'Hi')], lastSeq: 1));
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      expect(find.byKey(const ValueKey('dm_trip_safety')), findsNothing);
      expect(find.byKey(const ValueKey('dm_pinned_safety')), findsOneWidget);
      expect(find.text(SocialStringsC.safety), findsOneWidget);
      await disposeSocial(t);
    });

    testWidgets('the owner menu has Who can send messages after Members', (t) async {
      final api = FakeChatApi()..roomResult = BuddyOk(tripRoom(isOwner: true));
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      await openMenu(t);
      expect(find.text(SocialStringsC.membersItem), findsOneWidget);
      expect(find.text(SocialStringsC.whoCanSend), findsOneWidget);
      expect(t.getTopLeft(find.text(SocialStringsC.whoCanSend)).dy, greaterThan(t.getTopLeft(find.text(SocialStringsC.membersItem)).dy));
      expect(find.text(SocialStringsC.leaveTrip), findsOneWidget);
      await disposeSocial(t);
    });

    testWidgets('a member menu has no Who can send messages; Members and Leave stay', (t) async {
      final api = FakeChatApi()..roomResult = BuddyOk(tripRoom());
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      await openMenu(t);
      expect(find.text(SocialStringsC.whoCanSend), findsNothing);
      expect(find.text(SocialStringsC.membersItem), findsOneWidget);
      expect(find.text(SocialStringsC.leaveTrip), findsOneWidget);
      await disposeSocial(t);
    });

    testWidgets('picking Only me in the sheet calls the api', (t) async {
      final api = FakeChatApi()
        ..roomResult = BuddyOk(tripRoom(isOwner: true))
        ..sendModeResult = BuddyOk(tripRoom(isOwner: true, only: true));
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      await openMenu(t);
      await t.tap(find.text(SocialStringsC.whoCanSend));
      await pumps(t);
      expect(find.byKey(WhoCanSendSheet.everyoneKey), findsOneWidget);
      await t.tap(find.byKey(WhoCanSendSheet.onlyMeKey));
      await pumps(t);
      expect(api.sendModes, [true]);
      expect(find.byKey(const ValueKey('dm_composer')), findsOneWidget);
      expect(t.takeException(), isNull);
      await disposeSocial(t);
    });

    testWidgets('picking the current value sends nothing', (t) async {
      final api = FakeChatApi()..roomResult = BuddyOk(tripRoom(isOwner: true));
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      await openMenu(t);
      await t.tap(find.text(SocialStringsC.whoCanSend));
      await pumps(t);
      await t.tap(find.byKey(WhoCanSendSheet.everyoneKey));
      await pumps(t);
      expect(api.sendModes, isEmpty);
      await disposeSocial(t);
    });

    for (final w in socialWidths) {
      for (final s in socialScales) {
        testWidgets('a member with Only me on sees the owner-only line instead of the message box (${w.toInt()} x$s)', (t) async {
          final api = FakeChatApi()..roomResult = BuddyOk(tripRoom(only: true, lock: 'ownerOnly', canSend: false));
          await pumpSocial(t, DmRoomScreen(controller: controller(api)), width: w, scale: s);
          expect(find.byKey(const ValueKey('dm_owner_only')), findsOneWidget);
          expect(find.text('Only Rahul can send messages in this trip chat'), findsOneWidget);
          expect(find.byKey(const ValueKey('dm_composer')), findsNothing);
          expect(find.byKey(const ValueKey('dm_notice')), findsNothing);
          expect(t.takeException(), isNull);
          await disposeSocial(t);
        });
      }
    }

    test('the owner-only line never shows an empty name', () {
      expect(SocialStringsC.onlyOwnerSends(''), 'Only the trip owner can send messages in this trip chat');
      expect(SocialStringsC.onlyOwnerSends('Rahul'), 'Only Rahul can send messages in this trip chat');
    });

    testWidgets('the owner-only line beats the Plus bar', (t) async {
      final api = FakeChatApi()..roomResult = BuddyOk(tripRoom(only: true, lock: 'plus', canSend: false));
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      expect(find.byKey(const ValueKey('dm_owner_only')), findsOneWidget);
      expect(find.byKey(const ValueKey('dm_lock_plus')), findsNothing);
      await disposeSocial(t);
    });

    testWidgets('the owner keeps the message box with Only me on', (t) async {
      final api = FakeChatApi()..roomResult = BuddyOk(tripRoom(isOwner: true, only: true));
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      expect(find.byKey(const ValueKey('dm_owner_only')), findsNothing);
      expect(t.widget<TextField>(find.byKey(const ValueKey('dm_composer'))).enabled, isTrue);
      await disposeSocial(t);
    });

    testWidgets('the sendmode line renders as a system note', (t) async {
      final api = FakeChatApi()
        ..roomResult = BuddyOk(tripRoom())
        ..messagesResult = BuddyOk(MessagesPage(items: [msgOf(1, system: 'sendmode', text: 'Rahul changed who can send messages')], lastSeq: 1));
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      expect(find.ancestor(of: find.text('Rahul changed who can send messages'), matching: find.byType(ChatSystemNote)), findsOneWidget);
      expect(find.byType(ChatBubble3D), findsNothing);
      await disposeSocial(t);
    });
  });
}
