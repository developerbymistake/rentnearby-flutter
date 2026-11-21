import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/notices/controllers/notices_controller.dart';
import 'package:bakhli/features/buddy/notices/data/notices_api.dart';
import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/screens/notifications_screen.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Repo extends NotificationRepository {
  _Repo({this.rows = const [], this.unread = 0});
  List<NotificationModel> rows;
  int unread;
  int markAll = 0;
  int unreadCalls = 0;

  @override
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications({String? cursor, int page = 1, int pageSize = 20}) async =>
      (items: rows, hasMore: false, nextCursor: null);

  @override
  Future<int> getUnreadCount() async {
    unreadCalls++;
    return unread;
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async => markAll++;
}

class _Api extends NoticesApi {
  _Api({this.items = const [], this.fail = false});
  List<Notice> items;
  bool fail;
  final read = <String>[];

  @override
  Future<BuddyResult<NoticePage>> list({String? cursor, int limit = 30}) async =>
      fail ? BuddyOffline<NoticePage>() : BuddyOk(NoticePage(items: items, unread: items.where((n) => !n.isRead).length));

  @override
  Future<BuddyResult<void>> markRead(String id) async {
    read.add(id);
    return const BuddyOk(null);
  }
}

class _Auth extends GetxController implements AuthController {
  final asked = <String>[];
  bool allow = true;

  @override
  bool canOpenRoute(String route) {
    asked.add(route);
    return allow && AppRoutes.isRegistered(route);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Svc extends NotificationService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
}

final _now = DateTime.now();

Notice _n(String kind, String id, {int minutesAgo = 1, int? amount, String? refId, bool read = false, int count = 1}) => Notice(
      id: id,
      kind: kind,
      tripId: 'trip-1',
      tripTitle: 'Goa Trip',
      actorName: 'Rahul',
      amount: amount,
      refId: refId,
      count: count,
      createdAt: _now.subtract(Duration(minutes: minutesAgo)),
      updatedAt: _now.subtract(Duration(minutes: minutesAgo)),
      isRead: read,
    );

NotificationModel _row(String id, String title, {int minutesAgo = 3}) => NotificationModel(
    id: id, type: 'x', title: title, body: 'old body', actionRoute: null, actionArguments: null, isRead: false, createdAt: _now.subtract(Duration(minutes: minutesAgo)));

Future<(_Repo, _Api, _Auth, List<Object?>)> _open(WidgetTester t, {List<NotificationModel> rows = const [], List<Notice> notices = const [], bool failNotices = false, int unread = 0}) async {
  Get.testMode = true;
  addTearDown(Get.reset);
  final repo = _Repo(rows: rows, unread: unread);
  final api = _Api(items: notices, fail: failNotices);
  Get.put<NotificationRepository>(repo);
  Get.put(NotificationController());
  Get.put(NoticesController(api: api));
  final auth = Get.put<AuthController>(_Auth()) as _Auth;
  Get.put<NotificationService>(_Svc());
  final opened = <Object?>[];
  GetPage page(String route) => GetPage(
        name: route,
        page: () {
          opened.add('$route ${Get.arguments}');
          return const Scaffold(body: Text('opened'));
        },
      );
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.theme,
    initialRoute: '/n',
    getPages: [
      GetPage(name: '/n', page: () => const NotificationsScreen()),
      page(AppRoutes.buddies),
      page(AppRoutes.tripInvite),
      page(AppRoutes.tripExpenses),
      page(AppRoutes.tripView),
      page(AppRoutes.tripTravellers),
    ],
  ));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  return (repo, api, auth, opened);
}

void main() {
  testWidgets('old rows and notice rows share one list; words come from the kind', (t) async {
    await _open(t, rows: [_row('o1', 'Old thing')], notices: [_n(NoticeKinds.settleReminder, 'a', amount: 11816, minutesAgo: 1), _n(NoticeKinds.buddyRequest, 'b', minutesAgo: 5)]);
    expect(find.text('Old thing'), findsOneWidget);
    expect(find.text('Time to settle up'), findsOneWidget);
    expect(find.text('You owe Rahul ₹11,816.'), findsOneWidget);
    expect(find.text('New buddy request'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    final y = [for (final s in ['Time to settle up', 'Old thing', 'New buddy request']) t.getTopLeft(find.text(s)).dy];
    expect(y[0] < y[1] && y[1] < y[2], isTrue);
    expect(find.text('NEW'), findsNWidgets(3));
    expect(find.text('EXPENSES'), findsOneWidget);
    expect(find.text('BUDDIES'), findsOneWidget);
  });

  testWidgets('unknown notice kind is skipped', (t) async {
    await _open(t, notices: [_n('FutureKind', 'z'), _n(NoticeKinds.tripInvite, 'a')]);
    expect(find.text('Trip invite'), findsOneWidget);
    expect(NoticesController.maybe!.notices.length, 1);
  });

  testWidgets('a failed notices call does not block the old rows', (t) async {
    await _open(t, rows: [_row('o1', 'Old thing')], failNotices: true);
    expect(find.text('Old thing'), findsOneWidget);
    expect(find.text('No notifications yet'), findsNothing);
  });

  testWidgets('empty only when both lists are empty', (t) async {
    await _open(t);
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('buddy request row marks read and opens My buddies requests', (t) async {
    final (_, api, auth, opened) = await _open(t, notices: [_n(NoticeKinds.buddyRequest, 'b')]);
    await t.tap(find.text('New buddy request'));
    await t.pumpAndSettle();
    expect(api.read, ['b']);
    expect(auth.asked, [AppRoutes.buddies]);
    expect(opened, ['/buddies {tab: requests}']);
  });

  testWidgets('trip invite row opens the join screen with the member id', (t) async {
    final (_, _, _, opened) = await _open(t, notices: [_n(NoticeKinds.tripInvite, 'a', refId: 'member-9')]);
    await t.tap(find.text('Trip invite'));
    await t.pumpAndSettle();
    expect(opened, ['/trip-invite {memberId: member-9}']);
  });

  testWidgets('money rows open the expenses; said paid opens balances', (t) async {
    final (_, _, _, opened) = await _open(t, notices: [_n(NoticeKinds.expensesChanged, 'a', count: 3)]);
    expect(find.text('3 updates on Goa Trip.'), findsOneWidget);
    await t.tap(find.text('Expenses updated'));
    await t.pumpAndSettle();
    expect(opened, ['/trip-expenses {tripId: trip-1}']);
  });

  testWidgets('said paid row adds the balances tab', (t) async {
    final (_, _, _, opened) = await _open(t, notices: [_n(NoticeKinds.paymentSaidPaid, 'a', amount: 700)]);
    await t.tap(find.text('Rahul says paid'));
    await t.pumpAndSettle();
    expect(opened, ['/trip-expenses {tripId: trip-1, tab: balances}']);
  });

  for (final (kind, title, route) in [
    (NoticeKinds.buddyAccepted, 'Request accepted', '/buddies {}'),
    (NoticeKinds.newBuddy, 'New buddy', '/buddies {}'),
    (NoticeKinds.tripJoined, 'Rahul joined your trip', '/trip-travellers {tripId: trip-1}'),
    (NoticeKinds.planUpdated, 'Plan updated', '/trip-view {tripId: trip-1}'),
    (NoticeKinds.expenseAdded, 'New expense', '/trip-expenses {tripId: trip-1}'),
    (NoticeKinds.shareChanged, 'Your share changed', '/trip-expenses {tripId: trip-1}'),
  ]) {
    testWidgets('$kind row opens $route', (t) async {
      final (_, _, _, opened) = await _open(t, notices: [_n(kind, 'a', amount: 500)]);
      await t.tap(find.text(title));
      await t.pumpAndSettle();
      expect(opened, [route]);
    });
  }

  testWidgets('trip deleted opens the trip view with deleted true', (t) async {
    final (_, _, _, opened) = await _open(t, notices: [_n(NoticeKinds.tripDeleted, 'a')]);
    await t.tap(find.text('Trip deleted'));
    await t.pumpAndSettle();
    expect(opened, ['/trip-view {tripId: trip-1, deleted: true}']);
  });

  testWidgets('a route that cannot open shows the toast and stays', (t) async {
    final (_, _, auth, opened) = await _open(t, notices: [_n(NoticeKinds.tripInvite, 'a')]);
    auth.allow = false;
    await t.tap(find.text('Trip invite'));
    await t.pump();
    expect(opened, isEmpty);
    expect(Get.currentRoute, '/n');
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping marks the row read locally and drops the NEW pill', (t) async {
    await _open(t, notices: [_n(NoticeKinds.tripInvite, 'a')]);
    expect(find.text('NEW'), findsOneWidget);
    expect(NoticesController.maybe!.unread.value, 1);
    NoticesController.maybe!.markRead('a');
    await t.pump();
    expect(find.text('NEW'), findsNothing);
    expect(NoticesController.maybe!.unread.value, 0);
  });

  testWidgets('tapping an unread notice row lowers the bell once', (t) async {
    await _open(t, notices: [_n(NoticeKinds.buddyRequest, 'b')], unread: 3);
    final c = Get.find<NotificationController>();
    expect(c.unreadCount.value, 3);
    await t.tap(find.text('New buddy request'));
    await t.pumpAndSettle();
    expect(c.unreadCount.value, 2);
  });

  testWidgets('Mark all read shows for notice-only unread, calls the server, marks notices read', (t) async {
    final (repo, _, _, _) = await _open(t, notices: [_n(NoticeKinds.tripInvite, 'a'), _n(NoticeKinds.buddyRequest, 'b')], unread: 2);
    expect(find.text('Mark all read'), findsOneWidget);
    await t.tap(find.text('Mark all read'));
    await t.pump();
    expect(repo.markAll, 1);
    expect(NoticesController.maybe!.notices.every((n) => n.isRead), isTrue);
    expect(Get.find<NotificationController>().unreadCount.value, 0);
    expect(find.text('NEW'), findsNothing);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('a buddy push never makes a row or bumps the bell by itself; it reloads the total', (t) async {
    final (repo, _, _, _) = await _open(t, rows: [_row('o1', 'Old thing')], unread: 1);
    final c = Get.find<NotificationController>();
    final calls = repo.unreadCalls;
    repo.unread = 2;
    c.applyLiveNotification({'id': 'p1', 'type': 'buddy_request_received', 'title': 'Push title', 'body': 'Push body'});
    await t.pump();
    expect(c.notifications.length, 1);
    expect(find.text('Push title'), findsNothing);
    expect(repo.unreadCalls, calls + 1);
    expect(c.unreadCount.value, 2);
  });

  testWidgets('a normal push still increments and prepends', (t) async {
    await _open(t, rows: [_row('o1', 'Old thing')], unread: 1);
    final c = Get.find<NotificationController>();
    c.applyLiveNotification({'id': 'p2', 'type': 'broadcast', 'title': 'Hello', 'body': 'World'});
    await t.pump();
    expect(c.notifications.length, 2);
    expect(c.unreadCount.value, 2);
  });

  testWidgets('bell total reads total and falls back to count', (t) async {
    expect(NotificationRepository.paramsFor(), isNotEmpty);
    await _open(t, notices: [_n(NoticeKinds.tripInvite, 'a')], unread: 4);
    expect(Get.find<NotificationController>().unreadCount.value, 4);
  });

  testWidgets('BuddyLive.notices tick reloads the notice list', (t) async {
    final (_, api, _, _) = await _open(t, notices: [_n(NoticeKinds.tripInvite, 'a')]);
    api.items = [_n(NoticeKinds.tripInvite, 'a'), _n(NoticeKinds.buddyRequest, 'b', minutesAgo: 20)];
    BuddyLive.notices.value++;
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('New buddy request'), findsOneWidget);
  });
}
