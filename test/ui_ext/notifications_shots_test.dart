import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/ext_notifications.dart';
import 'package:bakhli/design/extra/page_header_3d.dart';
import 'package:bakhli/design/extra/state_card_3d.dart';
import 'package:bakhli/design/extra/toast_3d.dart';
import 'package:bakhli/features/stay/stay_strings_fin_c1.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/screens/notifications_screen.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/widgets/notification_off_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import '../support/real_phone.dart';

DateTime _at(int daysAgo, int h, int m) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, h, m);
}

NotificationModel _n(String id, String title, String body, DateTime at, {String type = 'trip_update', String? route = '/trip-replies', bool read = true}) =>
    NotificationModel(id: id, type: type, title: title, body: body, actionRoute: route, actionArguments: null, isRead: read, createdAt: at);

List<NotificationModel> _seeker({bool unread = true}) => [
      _n('s1', 'Pine Ridge Stay sent an offer', 'Rs 4,800 for 13 Nov to 15 Nov. Valid 24 h.', _at(0, 10, 42), read: !unread),
      _n('s2', 'Rakesh Singh replied Rs 2,600', 'Listed Rs 2,400. Call to settle, then tap I booked.', _at(0, 8, 2), read: !unread),
      _n('s3', 'Lakeside Rooms is no longer on Bakhli', 'Pick another stay for 13 Nov.', _at(1, 22, 15), route: '/gone'),
      _n('s4', 'No reply from Deodar Cottage', 'Ask another stay or call.', _at(1, 21, 48)),
      _n('s5', 'Hill View Homestay offer expired', 'Ask again or call.', _at(4, 18, 10)),
    ];

List<NotificationModel> _owner() => [
      _n('o1', 'New trip enquiry', 'Anita Rao · 13 Nov to 15 Nov · 2 adults.', _at(0, 11, 20), read: false),
      _n('o2', 'Offer accepted', 'Anita Rao accepted Rs 4,800 for 13 Nov to 15 Nov.', _at(0, 9, 5), read: false),
      _n('o3', 'Your stay is now live', 'Your stay has been approved and is now live.', _at(1, 16, 15), type: 'stay_approved', route: AppRoutes.myStays),
      _n('o4', 'Your stay was not approved', 'Your stay was rejected. Reason: Room photos are not clear.', _at(1, 10, 30), type: 'stay_rejected', route: AppRoutes.myStays),
    ];

List<NotificationModel> _driver() => [
      _n('t1', 'New trip lead', 'Anita Rao · 13 Nov to 15 Nov · 2 adults · Pickup Haldwani.', _at(0, 10, 12), read: false),
      _n('t2', 'Anita Rao booked you', '13 Nov to 15 Nov. Confirm in Trip leads.', _at(0, 8, 40), read: false),
      _n('t3', 'Your taxi is now live', 'Your taxi has been approved and is now live.', _at(1, 17, 30), type: 'taxi_approved', route: AppRoutes.myTaxi),
      _n('t4', 'Your taxi was taken down', 'Your taxi was taken down: Same taxi listed twice.', _at(4, 11, 5), type: 'taxi_rejected', route: AppRoutes.myTaxi),
      _n('t5', 'Your taxi was not approved', 'Your taxi was rejected. Reason: Vehicle photo is not clear.', _at(4, 6, 30), type: 'taxi_rejected', route: AppRoutes.myTaxi),
    ];

enum _Mode { list, loading, error }

class _Repo extends NotificationRepository {
  _Repo(this.items, {this.mode = _Mode.list, this.hasMore = false});
  final List<NotificationModel> items;
  final _Mode mode;
  final bool hasMore;

  @override
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications({String? cursor, int page = 1, int pageSize = 20}) {
    if (mode == _Mode.loading || page > 1) return Completer<({List<NotificationModel> items, bool hasMore, String? nextCursor})>().future;
    if (mode == _Mode.error) return Future.error(Exception('offline'));
    return Future.value((items: items, hasMore: hasMore, nextCursor: hasMore ? 'c' : null));
  }

  @override
  Future<int> getUnreadCount() async => 0;
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

const _dir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\notifications';

Future<NotificationController> _setup(_Repo repo) async {
  Get.reset();
  Get.testMode = true;
  Get.put<NotificationRepository>(repo, permanent: true);
  Get.put<AuthController>(_Auth(), permanent: true);
  Get.put<NotificationService>(_Svc(), permanent: true);
  return Get.put<NotificationController>(NotificationController(), permanent: true);
}

Future<void> _open(WidgetTester t, _Repo repo, {Size size = const Size(390, 844), double scale = 1.0, Widget? page}) async {
  shotsDir = _dir;
  await _setup(repo);
  debugDisableShadows = false;
  await pumpPhone(t, page ?? const NotificationsScreen(), size: size, devicePixelRatio: 1.5, textScale: scale);
  await settlePhone(t);
  await t.pump(const Duration(seconds: 1));
}

Future<void> _snap(WidgetTester t, String name) async {
  await settlePhone(t);
  await shot(t, name);
  final e = t.takeException();
  debugDisableShadows = true;
  expect(e, isNull);
}

Widget _banner() => NotificationOffBanner(isDenied: () async => true, openSettings: () async {});

Widget _stayPage() {
  final tone = ListingTone.forest;
  return Scaffold(
    backgroundColor: ListingPalette.forest.page,
    body: SafeArea(
      bottom: false,
      child: Column(children: [
        PageHeader3D(tone: tone, title: StayFinStrings.myStays, subtitle: StayFinStrings.manageListings, art: ListingArt.hotel, onBack: () {}),
        _banner(),
        Expanded(
          child: Center(
            child: StateCard3D(
              tone: tone,
              layout: StateLayout.tall,
              art: ListingArt.hotel,
              title: StayFinStrings.noStayYet,
              message: StayFinStrings.listStaySteps,
              actionLabel: StayFinStrings.setUpStay,
              onAction: () {},
              actionBelow: true,
            ),
          ),
        ),
      ]),
    ),
  );
}

class _BellToast extends StatelessWidget {
  const _BellToast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x24000000), offset: Offset(0, 6), blurRadius: 16)],
          ),
          child: Row(children: [
            Art3D(asset: NotificationLook.bell, size: 44, halo: 46, haloColor: NotificationLook.of('').color.withValues(alpha: 0.12)),
            const SizedBox(width: 10),
            Expanded(child: Text(message, maxLines: 3, style: Ink3D.text(13, FontWeight.w700, NotificationLook.of('').color, height: 1.3))),
          ]),
        ),
      );
}

void main() {
  tearDown(Get.reset);

  for (final (w, s, tag) in [(390.0, 1.0, '390'), (360.0, 1.3, '360_13'), (300.0, 1.0, '300')]) {
    final size = Size(w, w == 390 ? 844 : 800);

    testWidgets('inbox $tag', (t) async {
      await _open(t, _Repo(_seeker()), size: size, scale: s);
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.text('NEW'), findsNWidgets(2));
      expect(find.text('TODAY'), findsOneWidget);
      await _snap(t, 'inbox_$tag');
    });

    testWidgets('allread $tag', (t) async {
      await _open(t, _Repo(_seeker(unread: false)), size: size, scale: s);
      expect(find.text('Mark all read'), findsNothing);
      expect(find.text('NEW'), findsNothing);
      await _snap(t, 'allread_$tag');
    });

    testWidgets('more $tag', (t) async {
      await _open(t, _Repo(_driver(), hasMore: true), size: size, scale: s);
      final list = find.byType(ListView);
      t.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position.jumpTo(5000);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final pos = t.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position;
      pos.jumpTo(pos.maxScrollExtent);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('TAXI'), findsWidgets);
      expect(find.byType(NotificationMoreSpinner), findsOneWidget);
      await _snap(t, 'more_$tag');
    });

    testWidgets('loading $tag', (t) async {
      await _open(t, _Repo(const [], mode: _Mode.loading), size: size, scale: s);
      expect(find.byType(NotificationCardSkeleton), findsWidgets);
      await _snap(t, 'loading_$tag');
    });

    testWidgets('empty $tag', (t) async {
      await _open(t, _Repo(const []), size: size, scale: s);
      expect(find.text('No notifications yet'), findsOneWidget);
      await _snap(t, 'empty_$tag');
    });

    testWidgets('error $tag', (t) async {
      await _open(t, _Repo(const [], mode: _Mode.error), size: size, scale: s);
      expect(find.text("Couldn't load"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await _snap(t, 'error_$tag');
    });

    testWidgets('banner_stay $tag', (t) async {
      await _open(t, _Repo(const []), size: size, scale: s, page: _stayPage());
      expect(find.text('Turn on notifications'), findsOneWidget);
      expect(find.text('Set up your stay'), findsOneWidget);
      await _snap(t, 'banner_stay_$tag');
    });

  }

  testWidgets('refresh 390', (t) async {
    await _open(t, _Repo(_owner()), scale: 1.0);
    expect(find.text('STAY'), findsNWidgets(2));
    final g = await t.startGesture(t.getCenter(find.text('New trip enquiry')));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, 30));
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.pump(const Duration(milliseconds: 100));
    await shot(t, 'refresh_390');
    await g.up();
    await t.pump(const Duration(seconds: 2));
    debugDisableShadows = true;
  });

  testWidgets('toast and taps 390', (t) async {
    final toast = ValueNotifier<Rect?>(null);
    await _open(
      t,
      _Repo(_seeker()),
      page: Builder(
        builder: (c) => Stack(children: [
          const Positioned.fill(child: NotificationsScreen()),
          ValueListenableBuilder<Rect?>(
            valueListenable: toast,
            builder: (_, ring, __) => ring == null
                ? const SizedBox.shrink()
                : Stack(children: [
                    Positioned.fromRect(
                      rect: ring.inflate(3),
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2.5),
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), topRight: Radius.circular(47), bottomLeft: Radius.circular(11), bottomRight: Radius.circular(11)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(left: 14, top: ToastLane.topOffset(c), width: 228, child: const _BellToast(message: 'This is no longer available.')),
                  ]),
          ),
        ]),
      ),
    );
    final svc = Get.find<NotificationService>() as _Svc;
    await t.tap(find.text('Pine Ridge Stay sent an offer'));
    await t.pump();
    expect(svc.opened, ['/trip-replies']);
    await t.tap(find.text('Mark all read'));
    await t.pump();
    expect(find.text('Mark all read'), findsNothing);
    final gone = find.text('Lakeside Rooms is no longer on Bakhli');
    await t.tap(gone);
    await t.pump(const Duration(milliseconds: 600));
    expect(svc.opened, ['/trip-replies']);
    await t.pump();
    await settlePhone(t);
    await settlePhone(t);
    expect(find.text('This is no longer available.'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await settlePhone(t);
    toast.value = t.getRect(find.ancestor(of: gone, matching: find.byType(InkWell)).first);
    await t.pump();
    await settlePhone(t);
    expect(find.text('This is no longer available.'), findsOneWidget);
    await shot(t, 'toast_390');
    await t.pump(const Duration(seconds: 5));
    debugDisableShadows = true;
  });

  testWidgets('banner taps open settings', (t) async {
    var opened = 0;
    await _open(t, _Repo(const []), page: Scaffold(body: SafeArea(child: NotificationOffBanner(isDenied: () async => true, openSettings: () async => opened++))));
    await t.tap(find.text('Open settings'));
    await t.pump();
    expect(opened, 1);
    debugDisableShadows = true;
  });
}
