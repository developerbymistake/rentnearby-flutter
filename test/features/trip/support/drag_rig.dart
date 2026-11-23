import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/widgets/drag/trip_spot_drag_scope.dart';
import 'package:bakhli/features/trip/widgets/trip_day_spot_list.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/real_phone.dart';
import 'engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Future<TripPlanController> pumpDragPlan(
  WidgetTester t,
  TripPlan plan, {
  Size size = const Size(360, 2400),
  bool reduceMotion = false,
  bool edit = true,
  TripPlanLock lock = TripPlanLock.none,
  bool toasts = false,
}) async {
  Get.put<TabConfigController>(_Tabs());
  TripCityCatalog.to.seedForTest(const [
    TripCityModel(cityKey: 1, name: 'Nainital', stateName: 'Uttarakhand', latitude: 29.4, longitude: 79.4),
    TripCityModel(cityKey: 2, name: 'Almora', stateName: 'Uttarakhand', latitude: 29.6, longitude: 79.6),
  ]);
  final c = TripPlanController();
  c.plan.value = plan;
  c.trip.value = engineTrip(plan, lock: lock);
  Get.put<TripPlanController>(c, permanent: true);
  await loadRealFonts();
  final view = t.view;
  view.devicePixelRatio = 3;
  view.physicalSize = Size(size.width * 3, size.height * 3);
  view.padding = FakeViewPadding(top: phoneTopInset * 3, bottom: phoneBottomInset * 3);
  view.viewPadding = view.padding;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetPadding();
    view.resetViewPadding();
  });
  await t.pumpWidget(GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    scrollBehavior: const AppScrollBehavior(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: toasts ? Stack(fit: StackFit.expand, children: [Positioned.fill(child: child!), Overlay(key: AppToast.overlayKey)]) : child!,
    ),
    home: const TripPlanScreen(),
  ));
  await t.pump(const Duration(milliseconds: 300));
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await t.pump(const Duration(milliseconds: 500));
  if (edit) {
    c.editMode.value = true;
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }
  return c;
}

Future<void> drainDrag(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(minutes: 2));
}

List<String> dayIds(TripPlanController c, int day) => [for (final s in c.plan.value!.dayAt(day)!.spots) s.id];

Finder get dragScope => find.byType(TripSpotDragScope);

// Rows inside the page (the lifted copy in the Overlay is not under the scope).
Finder row(String id) => find.descendant(of: dragScope, matching: find.byKey(ValueKey(id)));

Finder handleOf(String id) => find.descendant(of: row(id), matching: find.byKey(TripDaySpotList.handleKey));

Finder get pageScrollable => find.descendant(of: dragScope, matching: find.byType(Scrollable)).first;

double pageOffset(WidgetTester t) => t.state<ScrollableState>(pageScrollable).position.pixels;

bool isRow(Widget w) => w.runtimeType.toString() == '_StopItem';

Finder get badges => find.byWidgetPredicate((w) => w is ValueListenableBuilder<TripDragState?>);

List<String> pageBadgeTexts(WidgetTester t, int day) {
  final inDay = find.descendant(of: find.byKey(ValueKey('trip-day-$day')), matching: badges);
  double y(Element e) => (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy;
  final els = inDay.evaluate().toList()..sort((a, b) => y(a).compareTo(y(b)));
  return [for (final e in els) badgeText(e)];
}

String badgeText(Element e) {
  String? out;
  void visit(Element x) {
    if (out != null) return;
    if (x.widget is Text) {
      out = (x.widget as Text).data;
      return;
    }
    x.visitChildren(visit);
  }

  e.visitChildren(visit);
  return out ?? '';
}

List<String> proxyBadgeTexts() => [
      for (final e in badges.evaluate())
        if (!_underScope(e)) badgeText(e),
    ];

bool _underScope(Element e) {
  var under = false;
  e.visitAncestorElements((a) {
    if (a.widget is TripSpotDragScope) {
      under = true;
      return false;
    }
    return true;
  });
  return under;
}

Finder get proxyRows => find.byElementPredicate((e) => isRow(e.widget) && !_underScope(e));

List<String> captureHaptics(WidgetTester t) {
  final calls = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

const selectionClick = 'HapticFeedbackType.selectionClick';
const lightImpact = 'HapticFeedbackType.lightImpact';

// Moves in small steps like a finger; returns the gesture still down.
Future<TestGesture> pressAndMove(WidgetTester t, Offset from, double dy, {Duration hold = Duration.zero, int steps = 8}) async {
  final g = await t.startGesture(from);
  if (hold > Duration.zero) await t.pump(hold);
  for (var i = 0; i < steps; i++) {
    await g.moveBy(Offset(0, dy / steps));
    await t.pump(const Duration(milliseconds: 16));
  }
  return g;
}

// A ticker takes its start time on its first frame, so the settle needs two pumps.
Future<void> settleDrop(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

double rowHeight(WidgetTester t, String id) => t.getSize(row(id)).height;

double get dsHandle => DS.s(44, scaled: false);
