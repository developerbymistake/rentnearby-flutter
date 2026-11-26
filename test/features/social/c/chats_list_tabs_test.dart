import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/rooms_controller.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/c/widgets/icon_title_header.dart';
import 'package:bakhli/models/conversation_model.dart';
import 'package:bakhli/screens/chats_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'chat_fakes.dart';
import 'social_c_test_kit.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeChat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> loadConversations({bool forceRefresh = false}) async {
    conversations.value = [
      ConversationModel(
        id: 'c1',
        listingType: 'Stay',
        listingId: 'l1',
        listingTitle: 'Deodar Cottage',
        otherPartyId: 'o1',
        otherPartyName: 'Meera Joshi',
        isOwner: false,
        status: 'Active',
        lastMessageAt: DateTime.utc(2026, 11, 26, 8),
        lastMessagePreview: 'Yes, dates are free',
        unreadCount: 0,
      ),
    ];
  }
}

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  void seeker(ShellKind shell, String role) {
    final auth = Get.put<AuthController>(_Auth());
    auth.shellKind.value = shell;
    auth.roleKey.value = role;
    Get.put<ChatController>(_FakeChat());
  }

  RoomsController rooms() {
    final api = FakeChatApi()
      ..pages[RoomBucket.people] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'p1', preview: 'See you at 7 near ISBT')]))
      ..pages[RoomBucket.trips] = BuddyOk(RoomsPage(items: [roomOf(roomId: 't1', kind: 'T', preview: 'Rohan: Booked the cab', trip: {'tripId': 'x', 'title': 'Manali', 'memberCount': 4})]))
      ..pages[RoomBucket.requests] = BuddyOk(RoomsPage(items: [roomOf(roomId: 'q1', status: 'Request', iStarted: false, preview: 'Are you also going to Auli?')]));
    return Get.put(RoomsController(api: api, transport: FakeTransport(), myId: () => myId), permanent: true);
  }

  for (final w in socialWidths) {
    for (final s in socialScales) {
      testWidgets('seeker chats list has People, Trips, Requests (${w.toInt()} x$s)', (t) async {
        seeker(ShellKind.seeker, UserRoleKeys.seeker);
        rooms();
        await pumpSocial(t, const ChatsListScreen(), width: w, scale: s);
        expect(find.byKey(const ValueKey('social_rooms_tabs')), findsOneWidget);
        expect(find.text('See you at 7 near ISBT'), findsOneWidget);
        expect(find.text('Yes, dates are free'), findsOneWidget);
        await t.tap(find.text(SocialStringsC.trips));
        await t.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('social_trip_room_t1')), findsOneWidget);
        await t.tap(find.text(SocialStringsC.requests));
        await t.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('social_request_q1')), findsOneWidget);
        expect(find.text(SocialStringsC.reply), findsOneWidget);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }
  }

  for (final w in socialWidths) {
    for (final s in socialScales) {
      testWidgets('Messages header: back, title and a small chat icon in one row, search on the right (${w.toInt()} x$s)', (t) async {
        seeker(ShellKind.seeker, UserRoleKeys.seeker);
        rooms();
        await pumpSocial(t, const ChatsListScreen(), width: w, scale: s);
        expect(find.byType(IconTitleHeader), findsOneWidget);
        expect(find.byType(ModuleTitleBar), findsNothing);
        final back = t.getRect(find.byTooltip('Back'));
        final title = t.getRect(find.text('Messages'));
        final icon = t.getRect(find.byKey(const ValueKey('icon_title_art')));
        final search = t.getRect(find.byTooltip('Search'));
        expect(t.widget<RoundIconButton3D>(find.byKey(const ValueKey('icon_title_art'))).asset, ListingArt.speechBalloon);
        expect(icon.height, closeTo(search.height, 0.5));
        expect(title.center.dy, closeTo(back.center.dy, 1));
        expect(icon.center.dy, closeTo(back.center.dy, 1));
        expect(title.left, greaterThan(back.right));
        expect(icon.left, greaterThanOrEqualTo(title.right));
        expect(search.left, greaterThanOrEqualTo(icon.right));
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }
  }

  testWidgets('people rows show short names', (t) async {
    seeker(ShellKind.seeker, UserRoleKeys.seeker);
    rooms();
    await pumpSocial(t, const ChatsListScreen());
    expect(find.descendant(of: find.byKey(const ValueKey('social_room_p1')), matching: find.text('Kavya S.')), findsOneWidget);
    expect(find.text('Kavya Sharma'), findsNothing);
    await t.tap(find.text(SocialStringsC.requests));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.descendant(of: find.byKey(const ValueKey('social_request_q1')), matching: find.text('Kavya S.')), findsOneWidget);
    await disposeSocial(t);
  });

  testWidgets('owner shell keeps the old list without tabs', (t) async {
    seeker(ShellKind.stayOwner, UserRoleKeys.stayOwner);
    rooms();
    await pumpSocial(t, const ChatsListScreen());
    expect(find.byKey(const ValueKey('social_rooms_tabs')), findsNothing);
    expect(find.text('Yes, dates are free'), findsOneWidget);
    expect(find.text('See you at 7 near ISBT'), findsNothing);
    await disposeSocial(t);
  });

  testWidgets('people cards carry no sticker and use the person colour', (t) async {
    seeker(ShellKind.seeker, UserRoleKeys.seeker);
    rooms();
    await pumpSocial(t, const ChatsListScreen());
    final card = t.widget<ChatThreadCard>(find.byKey(const ValueKey('social_room_p1')));
    expect(card.sticker, isNull);
    expect(card.compactTop, isTrue);
    expect(card.avatarGradient, BuddyLook.avatarGradient(peerId));
    await disposeSocial(t);
  });

  testWidgets('trip row members line starts with the title when there are no faces', (t) async {
    seeker(ShellKind.seeker, UserRoleKeys.seeker);
    rooms();
    await pumpSocial(t, const ChatsListScreen());
    await t.tap(find.text(SocialStringsC.trips));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.getTopLeft(find.text(SocialStringsC.members(4))).dx, t.getTopLeft(find.text('Manali').last).dx);
    await disposeSocial(t);
  });

  testWidgets('trip row shows member initials when there are no photos', (t) async {
    seeker(ShellKind.seeker, UserRoleKeys.seeker);
    final api = FakeChatApi()
      ..pages[RoomBucket.trips] = BuddyOk(RoomsPage(items: [roomOf(roomId: 't2', kind: 'T', trip: {'tripId': 'y', 'title': 'Auli', 'memberCount': 4, 'memberInitials': ['R', 'M', 'A']})]));
    Get.put(RoomsController(api: api, transport: FakeTransport(), myId: () => myId), permanent: true);
    await pumpSocial(t, const ChatsListScreen());
    await t.tap(find.text(SocialStringsC.trips));
    await t.pump(const Duration(milliseconds: 400));
    final row = find.byKey(const ValueKey('social_trip_room_t2'));
    for (final i in ['R', 'M', 'A']) {
      expect(find.descendant(of: row, matching: find.text(i)), findsOneWidget);
    }
    final card = t
        .widgetList<Container>(find.descendant(of: row, matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.boxShadow != null);
    expect(card.borderRadius, DS.br(CardRadius.card));
    await disposeSocial(t);
  });

  testWidgets('request actions are small pills on one row', (t) async {
    seeker(ShellKind.seeker, UserRoleKeys.seeker);
    rooms();
    await pumpSocial(t, const ChatsListScreen());
    await t.tap(find.text(SocialStringsC.requests));
    await t.pump(const Duration(milliseconds: 400));
    final card = t.getSize(find.byKey(const ValueKey('social_request_q1')));
    final reply = find.ancestor(of: find.text(SocialStringsC.reply), matching: find.byType(Container)).first;
    final delete = find.ancestor(of: find.text(SocialStringsC.delete), matching: find.byType(Container)).first;
    expect(t.getSize(reply).width, lessThan(card.width / 2));
    expect(t.getTopLeft(reply).dy, t.getTopLeft(delete).dy);
    await disposeSocial(t);
  });

  testWidgets('an empty Requests tab says replying is free only once', (t) async {
    seeker(ShellKind.seeker, UserRoleKeys.seeker);
    final api = FakeChatApi();
    Get.put(RoomsController(api: api, transport: FakeTransport(), myId: () => myId), permanent: true);
    await pumpSocial(t, const ChatsListScreen());
    await t.tap(find.text(SocialStringsC.requests));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(SocialStringsC.noRequests), findsOneWidget);
    expect(find.text(SocialStringsC.repliesFree), findsOneWidget);
    await disposeSocial(t);
  });
}
