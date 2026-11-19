import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/screens/notifications_screen.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Repo extends NotificationRepository {
  _Repo(this.route);
  final String route;

  @override
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications(
      {String? cursor, int page = 1, int pageSize = 20}) async {
    return (
      items: [
        NotificationModel(
          id: 'n1',
          type: 'TripTaxiFareSent',
          title: 'Driver replied',
          body: 'Open your plan',
          actionRoute: route,
          actionArguments: const {'tripId': 't9', 'day': 3, 'enquiryId': 'e9'},
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ],
      hasMore: false,
      nextCursor: null,
    );
  }

  @override
  Future<int> getUnreadCount() async => 1;
  @override
  Future<void> markRead(String id) async {}
}

class _Auth extends GetxController implements AuthController {
  final asked = <String>[];
  @override
  bool canOpenRoute(String route) {
    asked.add(route);
    return AppRoutes.isRegistered(route);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Svc extends NotificationService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
}

void main() {
  for (final old in AppRoutes.retiredTripTaxiRoutes) {
    testWidgets('inbox row with $old opens the trip plan', (t) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      Get.put<NotificationRepository>(_Repo(old));
      Get.put(NotificationController());
      final auth = Get.put<AuthController>(_Auth()) as _Auth;
      Get.put<NotificationService>(_Svc());
      Object? opened;
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.theme,
        initialRoute: '/n',
        getPages: [
          GetPage(name: '/n', page: () => const NotificationsScreen()),
          GetPage(
            name: AppRoutes.tripPlan,
            page: () {
              opened = Get.arguments;
              return const Scaffold(body: Text('plan'));
            },
          ),
        ],
      ));
      await t.pump();
      await t.pump(const Duration(seconds: 1));

      await t.tap(find.text('Driver replied'));
      await t.pumpAndSettle();

      expect(auth.asked, [AppRoutes.tripPlan]);
      expect(Get.currentRoute, AppRoutes.tripPlan);
      expect(find.text('plan'), findsOneWidget);
      expect(opened, {'tripId': 't9', 'fresh': true});
      expect(t.takeException(), isNull);
    });
  }
}
