import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/screens/notifications_screen.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/design/design.dart';

class _Repo extends NotificationRepository {
  @override
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications(
      {String? cursor, int page = 1, int pageSize = 20}) async {
    return (
      items: List.generate(
          12,
          (i) => NotificationModel(
              id: '$i', type: 'x', title: 'Title $i', body: 'Body $i',
              actionRoute: null, actionArguments: null, isRead: false, createdAt: DateTime.now())),
      hasMore: false,
      nextCursor: null
    );
  }
  @override
  Future<int> getUnreadCount() async => 12;
  @override
  Future<void> markRead(String id) async {}
}

void main() {
  testWidgets('push/pop under TemplateTransition', (t) async {
    Get.testMode = true;
    Get.put<NotificationRepository>(_Repo());
    Get.put(NotificationController());
    final errors = <Object>[];
    FlutterError.onError = (d) => errors.add(d.exception);
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.theme,
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
      initialRoute: '/n',
      getPages: [
        GetPage(name: '/n', page: () => const NotificationsScreen(), customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration),
        GetPage(name: '/d', page: () => const Scaffold(body: Center(child: Text('DETAIL'))), customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration),
      ],
    ));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    final card = find.text('Title 0');
    final s0 = t.getSize(find.ancestor(of: card, matching: find.byType(InkWell)).first);
    Get.toNamed('/d');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    Get.back();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    final s1 = t.getSize(find.ancestor(of: card, matching: find.byType(InkWell)).first);
    await t.tap(card);
    await t.pump(const Duration(seconds: 1));
    final s2 = t.getSize(find.ancestor(of: card, matching: find.byType(InkWell)).first);
    expect(s1, s0);
    expect(s2, s0);
  });
}
