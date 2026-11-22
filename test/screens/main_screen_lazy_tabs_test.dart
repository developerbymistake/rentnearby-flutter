import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/navigation/tab_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/owner_fakes.dart';

class _Auth extends FakeAuth {
  @override
  // ignore: must_call_super
  void onInit() {
    ever<int>(tabIndex, markVisited);
  }
}

void main() {
  late List<int> built;

  setUp(() {
    Get.reset();
    built = [];
    TabNavigator.debugRoot = (id) {
      built.add(id);
      return Text('root $id');
    };
    Get.put<TabConfigController>(FakeTabs());
  });

  tearDown(() {
    TabNavigator.debugRoot = null;
    Get.reset();
  });

  Future<_Auth> pump(WidgetTester t) async {
    final auth = _Auth();
    Get.put<AuthController>(auth);
    await t.pumpWidget(MaterialApp(
      home: Obx(() => IndexedStack(
            index: auth.tabIndex.value,
            children: const [
              TabNavigator(tabId: AppTabs.home),
              TabNavigator(tabId: AppTabs.stays),
              TabNavigator(tabId: AppTabs.trips),
              TabNavigator(tabId: AppTabs.taxi),
              TabNavigator(tabId: AppTabs.profile),
            ],
          )),
    ));
    return auth;
  }

  testWidgets('FX-06 only Home is built on the first frame; a tab is built on its first visit and kept', (t) async {
    final auth = await pump(t);
    expect(built.toSet(), {AppTabs.home});
    auth.switchToTab(AppTabs.profile);
    await t.pump();
    expect(built.toSet(), {AppTabs.home, AppTabs.profile});
    auth.switchToTab(AppTabs.home);
    await t.pump();
    expect(find.text('root ${AppTabs.profile}', skipOffstage: false), findsOneWidget, reason: 'a visited tab stays built');
    expect(find.text('root ${AppTabs.trips}', skipOffstage: false), findsNothing);
  });

  testWidgets('a direct tabIndex change (bottom nav, back press) counts as a visit', (t) async {
    final auth = await pump(t);
    auth.tabIndex.value = AppTabs.trips;
    await t.pump();
    expect(built, contains(AppTabs.trips));
  });

  testWidgets('a tab intent set before the first visit is still taken by the root', (t) async {
    final auth = await pump(t);
    auth.openTab(AppTabs.profile, intent: {'route': '/x'});
    await t.pump();
    expect(built, contains(AppTabs.profile));
    expect(auth.takeIntent(AppTabs.profile)?.args['route'], '/x');
  });

  testWidgets('a shell reset leaves only Home visited', (t) async {
    final auth = await pump(t);
    auth.switchToTab(AppTabs.profile);
    await t.pump();
    auth.switchToTab(AppTabs.home);
    auth.resetVisitedTabs();
    await t.pump();
    expect(auth.visitedTabs.toSet(), {AppTabs.home});
    expect(find.text('root ${AppTabs.profile}', skipOffstage: false), findsNothing);
  });
}
