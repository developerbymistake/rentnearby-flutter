import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/screens/notifications_screen.dart';
import 'package:bakhli/services/notification_service.dart';

class _Repo extends NotificationRepository {
  @override
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications(
      {String? cursor, int page = 1, int pageSize = 20}) async {
    return (
      items: List.generate(
          10,
          (i) => NotificationModel(
              id: '$i',
              type: 'x',
              title: 'Title $i',
              body: 'Body text number $i for notification',
              actionRoute: i == 0 ? '/d' : null,
              actionArguments: null,
              isRead: false,
              createdAt: DateTime.now())),
      hasMore: false,
      nextCursor: null
    );
  }

  @override
  Future<int> getUnreadCount() async => 10;
  @override
  Future<void> markRead(String id) async {}
}

class _Auth extends GetxController implements AuthController {
  @override
  bool canOpenRoute(String route) => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Svc extends GetxService implements NotificationService {
  @override
  Future<void> onInit() async {
    super.onInit();
  }
  @override
  void openActionRoute(String route, Map<String, dynamic>? args) => Get.toNamed(route, arguments: args);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('row keeps size and visible text through tap, push and pop', (t) async {
    Get.testMode = true;
    Get.put<NotificationRepository>(_Repo());
    Get.put(NotificationController());
    Get.put<AuthController>(_Auth());
    Get.put<NotificationService>(_Svc());
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
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
    await t.pump(const Duration(seconds: 1));

    Size rowSize(int i) => t.getSize(find.ancestor(of: find.text('Title $i'), matching: find.byType(InkWell)).first);
    double opacityOf(Finder f) {
      var o = 1.0;
      for (final w in t.widgetList<FadeTransition>(find.ancestor(of: f, matching: find.byType(FadeTransition)))) {
        o *= w.opacity.value;
      }
      return o;
    }

    void expectVisible(int i) {
      for (final s in ['Title $i', 'Body text number $i for notification']) {
        expect(find.text(s), findsOneWidget);
        expect(opacityOf(find.text(s)), 1.0, reason: s);
      }
    }

    final s0 = rowSize(0);
    final s1 = rowSize(1);
    expectVisible(0);
    expectVisible(1);

    await t.tap(find.text('Title 1'));
    await t.pump();
    expect(rowSize(1), s1);
    await t.pump(const Duration(seconds: 1));
    expect(rowSize(1), s1);
    expectVisible(1);

    await t.tap(find.text('Title 0'));
    await t.pump();
    for (var k = 0; k < 4; k++) {
      await t.pump(const Duration(milliseconds: 60));
      expect(rowSize(0), s0, reason: 'during push');
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.text('DETAIL'), findsOneWidget);

    Get.back();
    await t.pump();
    for (var k = 0; k < 8; k++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.text('DETAIL'), findsNothing);
    expect(rowSize(0), s0);
    expect(rowSize(1), s1);
    expectVisible(0);
    expectVisible(1);
    expect(t.takeException(), isNull);
  });
}
