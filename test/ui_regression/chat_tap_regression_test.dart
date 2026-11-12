import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/screens/notifications_screen.dart';

class _FakeNotif extends NotificationController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadNotifications({bool reset = true}) async {
    notifications.value = [
      for (var i = 0; i < 4; i++)
        NotificationModel(id: '$i', type: 'x', title: 'Title $i', body: 'Body text $i', actionRoute: null, actionArguments: null, isRead: false, createdAt: DateTime.now()),
    ];
  }
  @override
  Future<void> markRead(String id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    notifications[idx] = notifications[idx].copyWith(isRead: true);
  }
}

void main() {
  testWidgets('notifications: tap keeps card size', (t) async {
    Get.put<NotificationController>(_FakeNotif());
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.theme,
      customTransition: TemplateTransition(),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.noScaling), child: Stack(fit: StackFit.expand, children: [Positioned.fill(child: child!)])),
      home: const NotificationsScreen(),
    ));
    await t.pumpAndSettle();
    final f = find.text('Body text 1');
    final before = t.getSize(find.ancestor(of: f, matching: find.byType(ListRow)).first);
    final tf = find.text('Title 1');
    final bodyBefore = t.getSize(f);
    await t.tap(tf);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
      expect(t.getSize(f), bodyBefore);
      expect(t.getSize(find.ancestor(of: f, matching: find.byType(ListRow)).first), before);
    }
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
