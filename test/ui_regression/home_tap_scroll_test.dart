import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/home_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/screens/home_screen.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Home extends HomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> reloadDistrict() async {}
}

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

class _Plan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Loc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  setUp(() {
    Get.reset();
    Get.put<TabConfigController>(_Tabs());
    Get.put<AuthController>(_Auth());
    Get.put<LocationController>(_Loc());
    Get.put<HomeController>(_Home());
    Get.put<NotificationController>(_Notif());
    Get.put<ChatController>(_Chat());
    Get.put<PlanController>(_Plan());
  });

  testWidgets('home top bar is compact, does not block taps, content scrolls', (t) async {
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.theme, home: const HomeScreen()));
    await t.pump(const Duration(seconds: 1));

    final scrollable = find.byType(SingleChildScrollView).first;
    expect(scrollable, findsOneWidget);

    final bar = find.ancestor(
      of: find.text('Where to next?'),
      matching: find.byType(ColoredBox),
    );
    expect(t.getSize(bar.first).height, lessThan(140));

    final result = HitTestResult();
    t.binding.hitTestInView(result, const Offset(400, 600), t.view.viewId);
    final hitBar = result.path.any((e) => e.target is RenderBox && bar.evaluate().first.renderObject == e.target);
    expect(hitBar, isFalse);

    final state = t.state<ScrollableState>(find.descendant(of: scrollable, matching: find.byType(Scrollable)).first);
    final before = state.position.pixels;
    await t.drag(scrollable, const Offset(0, -300));
    await t.pump(const Duration(milliseconds: 500));
    expect(state.position.pixels, greaterThan(before));
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox());
    t.takeException();
  });
}
