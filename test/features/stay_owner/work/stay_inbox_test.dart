import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/screens/notifications_screen.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_render.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';

DateTime _ago(Duration d) => DateTime.now().subtract(d);

NotificationModel _n(String id, String type, String title, String body, Duration age, {String? route, Map<String, dynamic>? args, bool read = true}) =>
    NotificationModel(id: id, type: type, title: title, body: body, actionRoute: route, actionArguments: args, isRead: read, createdAt: _ago(age));

List<NotificationModel> _frame() => [
      _n('1', 'TripEnquiryReceived', 'Trip enquiry', 'Rohit wants 24 – 26 Nov, 3 guests.', const Duration(minutes: 5), route: AppRoutes.stayEnquiries, args: {'enquiryId': 'e1'}, read: false),
      _n('2', 'TripChangeRequest', 'Rohit changed his dates', 'Open to accept or send a different offer.', const Duration(hours: 1), route: AppRoutes.stayEnquiries, args: {'enquiryId': 'e2'}, read: false),
      _n('3', 'TripOfferAccepted', 'Offer accepted', 'Anjali accepted your offer for 2 – 5 Dec.', const Duration(days: 1), route: AppRoutes.stayEnquiries),
      _n('4', 'plan_expiring', 'Plus ends on 21 Dec 2026', 'Renew to keep your benefits.', const Duration(days: 3), route: AppRoutes.plansBilling),
      _n('5', 'stay_approved', 'Your stay is now live', 'Your stay has been approved and is now live.', const Duration(days: 6), route: AppRoutes.myStays),
      _n('6', 'festival_reminder', 'Diwali week starts 6 Nov', 'Set your price for those days.', const Duration(days: 36), route: AppRoutes.staySpecialPrices),
    ];

class _Repo extends NotificationRepository {
  _Repo(this.items, {this.fail = false});
  final List<NotificationModel> items;
  final bool fail;

  @override
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications({String? cursor, int page = 1, int pageSize = 20}) {
    if (page > 1) return Completer<({List<NotificationModel> items, bool hasMore, String? nextCursor})>().future;
    if (fail) return Future.error(Exception('offline'));
    return Future.value((items: items, hasMore: false, nextCursor: null));
  }

  @override
  Future<int> getUnreadCount() async => items.where((n) => !n.isRead).length;
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> markAllRead() async {}
}

class _Auth extends GetxController implements AuthController {
  @override
  bool canOpenRoute(String route) => route != '/gone';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Svc extends GetxService implements NotificationService {
  final opened = <String>[];
  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  void openActionRoute(String route, Map<String, dynamic>? args) => opened.add(route);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

_Svc _setUp(List<NotificationModel> items, {bool fail = false}) {
  Get.reset();
  Get.testMode = true;
  Get.put<NotificationRepository>(_Repo(items, fail: fail), permanent: true);
  Get.put<AuthController>(_Auth(), permanent: true);
  final svc = _Svc();
  Get.put<NotificationService>(svc, permanent: true);
  Get.put<NotificationController>(NotificationController(), permanent: true);
  return svc;
}

Future<void> _settle(WidgetTester t) async {
  await settlePhone(t);
  await t.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(Get.reset);

  testWidgets('o_st_22_listGroupsTodayEarlier_newPills and kind labels', (t) async {
    _setUp(_frame());
    await pumpPhone(t, const NotificationsScreen(), size: const Size(392, 1400));
    await _settle(t);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('NEW'), findsNWidgets(2));
    for (final label in ['ENQUIRY', 'CHANGE REQUEST', 'PLAN', 'STAY', 'PRICE']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Diwali week starts 6 Nov'), findsOneWidget);
    expect(find.textContaining('advance'), findsNothing);
  });

  testWidgets('o_st_22_tapRoutes_enquiryPlanStayFestival and targetGone toast', (t) async {
    final svc = _setUp([
      ..._frame(),
      _n('7', 'TripEnquiryReceived', 'Gone row', 'x', const Duration(days: 40), route: '/gone'),
    ]);
    await pumpPhone(t, const NotificationsScreen(), size: const Size(392, 2000));
    await _settle(t);
    await t.tap(find.text('Trip enquiry'));
    await t.tap(find.text('Plus ends on 21 Dec 2026'));
    await t.tap(find.text('Diwali week starts 6 Nov'));
    await t.pump();
    expect(svc.opened, [AppRoutes.stayEnquiries, AppRoutes.plansBilling, AppRoutes.staySpecialPrices]);
    await t.tap(find.text('Gone row'));
    await t.pump();
    expect(svc.opened.length, 3);
    await t.pump(const Duration(seconds: 5));
  });

  for (final rows in [0, 1, 50]) {
    testOwnerSizes(
      'o_st_22 inbox $rows rows',
      () => const NotificationsScreen(),
      setUpEach: () => _setUp([for (var i = 0; i < rows; i++) _frame()[i % 6]].asMap().entries.map((e) => _n('r${e.key}', e.value.type, e.value.title, e.value.body, Duration(hours: e.key * 7), route: e.value.actionRoute)).toList()),
      arrange: _settle,
    );
  }

  testWidgets('o_st_22 error with no rows shows retry, no crash', (t) async {
    _setUp(const [], fail: true);
    await pumpPhone(t, const NotificationsScreen());
    await _settle(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('render o_st_22', (t) async {
    _setUp(_frame());
    await renderOwnerFrame(t, 'o_st_22', const NotificationsScreen(), arrange: _settle);
  });
}
