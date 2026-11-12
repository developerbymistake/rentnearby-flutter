import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/screens/notifications_screen.dart';
import 'package:bakhli/config/app_theme.dart';

class _Repo extends NotificationRepository {
  @override
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications(
      {String? cursor, int page = 1, int pageSize = 20}) async {
    return (
      items: List.generate(
          12,
          (i) => NotificationModel(
              id: '$i',
              type: 'x',
              title: 'Title $i',
              body: 'Body text number $i for notification',
              actionRoute: null,
              actionArguments: null,
              isRead: false,
              createdAt: DateTime.now())),
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
  testWidgets('notification tap keeps card size', (t) async {
    Get.testMode = true;
    Get.put<NotificationRepository>(_Repo());
    Get.put(NotificationController());
    final errors = <Object>[];
    FlutterError.onError = (d) => errors.add(d.exception);
    t.view.physicalSize = const Size(1080, 1920); t.view.devicePixelRatio = 3.0; t.platformDispatcher.textScaleFactorTestValue = 1.4; addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: AppTheme.theme, home: const NotificationsScreen()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    final card = find.text('Title 0');
    expect(card, findsOneWidget);
    final before = t.getSize(find.ancestor(of: card, matching: find.byType(ListRow)).first);
    final rowFinder = find.ancestor(of: card, matching: find.byType(InkWell)).first;
    final rb = t.getSize(rowFinder);
    await t.tap(card);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    final ra = t.getSize(rowFinder);
    expect(t.getSize(find.ancestor(of: card, matching: find.byType(ListRow)).first), before);
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pump();
    expect(ra, rb);
    expect(errors, isEmpty);
  });
}
