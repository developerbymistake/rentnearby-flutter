import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/models/conversation_model.dart';
import 'package:bakhli/screens/chats_list_screen.dart';

class _FakeChat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadConversations({bool forceRefresh = false}) async {
    conversations.value = [
      for (var i = 0; i < 3; i++)
        ConversationModel(id: '$i', listingType: 'Stay', listingId: 'l$i', listingTitle: 'Stay $i', otherPartyId: 'o', otherPartyName: 'Name $i', isOwner: false, status: 'Active', lastMessageAt: DateTime.now(), lastMessagePreview: 'Preview $i', unreadCount: 2),
    ];
  }
}

void main() {
  testWidgets('chats list: tap row, card stays sized, no exception', (t) async {
    Get.put<ChatController>(_FakeChat());
    await t.pumpWidget(GetMaterialApp(
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
      initialRoute: '/start',
      getPages: [
        GetPage(name: '/start', page: () => const ChatsListScreen(), customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration),
        GetPage(name: AppRoutes.chatConversation, page: () => Scaffold(body: Card(child: SizedBox(height: 100, child: Text('DETAIL')))), customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration),
      ],
    ));
    await t.pumpAndSettle();
    final p = find.text('Preview 1');
    final before = t.getSize(p);
    await t.tap(p);
    for (var i = 0; i < 7; i++) {
      await t.pump(const Duration(milliseconds: 80));
      if (find.text('Preview 1').evaluate().isNotEmpty) expect(t.getSize(find.text('Preview 1')), before);
    }
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
