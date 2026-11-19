import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/navigation/tour_keys.dart';
import 'package:bakhli/widgets/tab_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Notif extends NotificationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Chat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

const _sizes = [Size(320, 568), Size(360, 640), Size(360, 800), Size(411, 891), Size(600, 960)];

Widget _frame({String title = 'Stays', String subtitle = 'Find stays near you', double textScale = 1, Key? iconsKey}) => GetMaterialApp(
      getPages: [
        GetPage(name: '/', page: () => const SizedBox()),
        GetPage(name: AppRoutes.notifications, page: () => const Scaffold(body: Text('notifications page'))),
        GetPage(name: AppRoutes.chatsList, page: () => const Scaffold(body: Text('chats page'))),
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: TabHeaderFrame(
          title: title,
          subtitle: subtitle,
          color: Colors.white,
          iconsKey: iconsKey,
          child: ListView(children: [for (var i = 0; i < 60; i++) SizedBox(height: 40, child: Text('row $i'))]),
        ),
      ),
    );

Future<void> _pump(WidgetTester t, Widget w, {Size size = const Size(360, 800)}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = const FakeViewPadding(top: 28, bottom: 24);
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
  await t.pump();
}

Finder _badge(String text) => find.text(text);

void main() {
  tearDown(Get.reset);

  testWidgets('shows title, subtitle and both icons', (t) async {
    await _pump(t, _frame());
    expect(find.text('Stays'), findsOneWidget);
    expect(find.text('Find stays near you'), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    expect(find.bySemanticsLabel('Chats'), findsOneWidget);
  });

  testWidgets('bell opens notifications, chat icon opens chats', (t) async {
    await _pump(t, _frame());
    await t.tap(find.bySemanticsLabel('Notifications'));
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.notifications);
    Get.back();
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Chats'));
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.chatsList);
  });

  testWidgets('badges follow the unread counts', (t) async {
    final n = Get.put<NotificationController>(_Notif());
    final c = Get.put<ChatController>(_Chat());
    await _pump(t, _frame());
    expect(find.byType(Text), findsWidgets);
    expect(_badge('0'), findsNothing);
    n.unreadCount.value = 5;
    c.unreadCount.value = 120;
    await t.pump();
    expect(_badge('5'), findsOneWidget);
    expect(_badge('99+'), findsOneWidget);
    n.unreadCount.value = 0;
    c.unreadCount.value = 3;
    await t.pump();
    expect(_badge('5'), findsNothing);
    expect(_badge('99+'), findsNothing);
    expect(_badge('3'), findsOneWidget);
  });

  testWidgets('no controllers registered: no badge, no throw', (t) async {
    await _pump(t, _frame());
    expect(t.takeException(), isNull);
    expect(_badge('99+'), findsNothing);
  });

  testWidgets('header stays fixed while the body scrolls', (t) async {
    await _pump(t, _frame());
    final top = t.getTopLeft(find.byType(TabHeader));
    await t.drag(find.byType(ListView), const Offset(0, -600));
    await t.pump();
    expect(t.getTopLeft(find.byType(TabHeader)), top);
    expect(find.text('row 0'), findsNothing);
    expect(t.hitTestOnBinding(t.getCenter(find.bySemanticsLabel('Chats'))).path.isNotEmpty, isTrue);
  });

  testWidgets('safe top is paid by the header, not by the body', (t) async {
    await _pump(t, _frame());
    expect(t.getTopLeft(find.byType(TabHeader)).dy, 0);
    final headerBottom = t.getBottomLeft(find.byType(TabHeader)).dy;
    expect(t.getTopLeft(find.text('row 0')).dy, headerBottom);
  });

  testWidgets('five tabs in one IndexedStack: only Home carries the tour key', (t) async {
    await _pump(
      t,
      MaterialApp(
        home: Scaffold(
          body: IndexedStack(children: [
            for (var i = 0; i < 5; i++)
              TabHeaderFrame(
                title: 'Tab $i',
                subtitle: 'Sub $i',
                color: Colors.white,
                iconsKey: i == 0 ? TourKeys.homeActionMenu : null,
                child: const SizedBox.expand(),
              ),
          ]),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.byKey(TourKeys.homeActionMenu), findsOneWidget);
  });

  for (final size in _sizes) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()} text x$scale', (t) async {
        await _pump(
          t,
          _frame(title: 'Stays and homestays near the hills', subtitle: 'Find the nearest stays around your current place today', textScale: scale),
          size: size,
        );
        expect(t.takeException(), isNull);
        final header = t.getRect(find.byType(TabHeader));
        expect(header.width, size.width);
        expect(header.height, lessThan(size.height / 2));
        expect(t.getRect(find.bySemanticsLabel('Chats')).right, lessThanOrEqualTo(size.width));
      });
    }
  }
}
