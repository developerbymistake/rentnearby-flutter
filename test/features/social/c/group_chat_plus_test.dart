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

const _trip = {'tripId': 't1', 'title': 'Manali', 'memberCount': 4, 'photoUrls': <String>[]};

SocialLimits _limits({required bool groupChat}) => SocialLimits(
      isPlus: groupChat,
      canUpgrade: true,
      activeTrips: const LimitUse(limit: 1, used: 0),
      publicTrips: const LimitUse(limit: 1, used: 0),
      joinRequests: const LimitUse(limit: 1, used: 0),
      newChats: const LimitUse(limit: 3, used: 0),
      genderOnlyTrips: false,
      nearMe: false,
      groupChat: groupChat,
    );

FakeChatApi _tripApi({String lock = 'none', bool canSend = true}) => FakeChatApi()
  ..roomResult = BuddyOk(roomOf(kind: 'T', lock: lock, canSend: canSend, trip: _trip))
  ..messagesResult = BuddyOk(MessagesPage(items: [
    msgOf(1, system: 'joined', text: 'Meera joined the trip'),
    msgOf(2, sender: 'u-rohan', senderName: 'Rohan M.', text: 'Booked the cab for 6 AM.'),
  ], lastSeq: 2));

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  RoomController controller(FakeChatApi api, [FakeTransport? hub]) => RoomController(roomId: 'r1', api: api, transport: hub ?? FakeTransport(), myId: () => myId);

  group('controller', () {
    test('UC33 Free member (no group chat entitlement): the trip room cannot send', () async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: false)), permanent: true);
      final c = Get.put(controller(_tripApi()));
      await settle();
      expect(c.isTrip, isTrue);
      expect(c.groupChatLocked, isTrue);
      expect(c.canSend, isFalse);
    });

    test('UC35/37 Plus member, or payment OFF (entitlement on for everyone), sends freely', () async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: true)), permanent: true);
      final c = Get.put(controller(_tripApi()));
      await settle();
      expect(c.groupChatLocked, isFalse);
      expect(c.canSend, isTrue);
    });

    test('an older answer without groupChat never locks: the server decides', () async {
      final c = Get.put(controller(_tripApi()));
      await settle();
      expect(c.groupChatLocked, isFalse);
    });

    test('UC34/36 a PlusRequired refusal (hub) stores nothing, gives the text back and locks the room', () async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: true)), permanent: true);
      final hub = FakeTransport()..hubReplies.add({'ok': false, 'type': 'PlusRequired', 'message': 'This is a Bakhli Plus feature.'});
      final c = Get.put(controller(_tripApi(), hub));
      await settle();
      await c.send('Hello group');
      await settle();
      expect(c.messages.any((m) => m.isLocal), isFalse);
      expect(c.messages.map((m) => m.seq), [1, 2], reason: 'history kept');
      expect(c.bounced.value, 'Hello group');
      expect(c.plusLocked.value, isTrue);
      expect(c.canSend, isFalse);
    });

    test('UC34 a PlusRequired refusal over REST behaves the same', () async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: true)), permanent: true);
      final api = _tripApi()..sendResults.add(const BuddyRefused(type: 'PlusRequired', statusCode: 403));
      final c = Get.put(controller(api));
      await settle();
      await c.send('Hello group');
      await settle();
      expect(c.messages.any((m) => m.isLocal), isFalse);
      expect(c.plusLocked.value, isTrue);
    });

    test('re-subscribing restores sending: refreshLock clears the local lock', () async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: true)), permanent: true);
      final api = _tripApi()..sendResults.add(const BuddyRefused(type: 'PlusRequired', statusCode: 403));
      final c = Get.put(controller(api));
      await settle();
      await c.send('Hello group');
      await settle();
      expect(c.canSend, isFalse);
      await c.refreshLock();
      expect(c.plusLocked.value, isFalse);
      expect(c.canSend, isTrue);
    });

    test('a server lock plus on the room locks it too', () async {
      final c = Get.put(controller(_tripApi(lock: RoomLock.plus, canSend: false)));
      await settle();
      expect(c.groupChatLocked, isTrue);
    });

    test('1-to-1 chats never use the group chat lock', () async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: false)), permanent: true);
      final c = Get.put(controller(FakeChatApi()));
      await settle();
      expect(c.isTrip, isFalse);
      expect(c.groupChatLocked, isFalse);
    });
  });

  group('screen', () {
    testWidgets('UC33/38 Free member opens the trip room: history and the joined line show, a calm Plus panel in place of the composer', (t) async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: false)), permanent: true);
      await pumpSocial(t, DmRoomScreen(controller: controller(_tripApi())));
      expect(find.text('Meera joined the trip'), findsOneWidget);
      expect(find.text('Booked the cab for 6 AM.'), findsOneWidget);
      expect(find.byKey(const ValueKey('dm_composer')), findsNothing);
      expect(find.byKey(const ValueKey('dm_lock_group_plus')), findsOneWidget);
      expect(find.text(SocialStringsC.groupChatPlusTitle), findsOneWidget);
      expect(find.text(SocialStringsC.groupChatPlusLine), findsOneWidget);
      expect(find.text(SocialStringsC.seePlus), findsOneWidget);
      expect(t.takeException(), isNull);
      await disposeSocial(t);
    });

    testWidgets('UC35 Plus member sees the composer', (t) async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: true)), permanent: true);
      await pumpSocial(t, DmRoomScreen(controller: controller(_tripApi())));
      expect(find.byKey(const ValueKey('dm_composer')), findsOneWidget);
      expect(find.byKey(const ValueKey('dm_lock_group_plus')), findsNothing);
      await disposeSocial(t);
    });

    testWidgets('UC36 Plus lapses mid-chat: the PlusRequired send shows the Plus sheet and the calm panel replaces the composer', (t) async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: true)), permanent: true);
      final api = _tripApi()..sendResults.add(const BuddyRefused(type: 'PlusRequired', statusCode: 403));
      await pumpSocial(t, DmRoomScreen(controller: controller(api)));
      await t.enterText(find.byKey(const ValueKey('dm_composer')), 'Hello group');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('dm_send')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
      expect(find.text(SocialStringsC.groupChatPlusTitle), findsWidgets);
      expect(find.text('Hello group'), findsNothing, reason: 'nothing stored in the chat');
      expect(find.byKey(const ValueKey('dm_lock_group_plus')), findsOneWidget);
      expect(find.byKey(const ValueKey('dm_composer')), findsNothing);
      expect(t.takeException(), isNull);
      await disposeSocial(t);
    });

    testWidgets('a removed member keeps the left notice, not the Plus panel', (t) async {
      Get.put<SocialMeController>(FakeSocialMeController(_limits(groupChat: false)), permanent: true);
      await pumpSocial(t, DmRoomScreen(controller: controller(_tripApi(lock: 'left', canSend: false))));
      expect(find.byKey(const ValueKey('dm_notice')), findsOneWidget);
      expect(find.byKey(const ValueKey('dm_lock_group_plus')), findsNothing);
      await disposeSocial(t);
    });
  });
}
