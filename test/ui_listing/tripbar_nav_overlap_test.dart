import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/template_nav.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/widgets/trip_bar.dart';
import 'package:bakhli/navigation/app_bottom_dock.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';
import '../trip_flow/slice3/overlay_support.dart' show OverlayTrips;

const _rootKey = ValueKey('tripbar_nav_root');

class _Shell extends StatelessWidget {
  const _Shell({required this.taps});

  final List<int> taps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: const SizedBox.expand(),
      bottomNavigationBar: AppBottomDock(
        banner: const TripBar(),
        nav: TemplateBottomBar(
          bottomInset: MediaQuery.of(context).viewPadding.bottom,
          selectedIndex: 0,
          onTap: taps.add,
          items: const [
            TemplateNavItem(index: 0, label: 'Home', image: 'assets/images/design/travel3d/compass.png'),
            TemplateNavItem(index: 1, label: 'Stays', image: ListingArt.stay),
            TemplateNavItem(index: 2, label: 'Trips', image: 'assets/images/design/travel3d/luggage.png', center: true),
            TemplateNavItem(index: 3, label: 'Taxi', image: 'assets/images/design/travel3d/taxi.png'),
            TemplateNavItem(index: 4, label: 'Profile', image: 'assets/images/design/travel3d/backpack.png'),
          ],
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester t, List<int> taps, Size size, double scale, {required bool animate}) async {
  await loadRealFonts();
  const dpr = 3.0;
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = Size(size.width * dpr, size.height * dpr);
  t.view.padding = const FakeViewPadding(top: phoneTopInset * dpr, bottom: phoneBottomInset * dpr);
  t.view.viewPadding = t.view.padding;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.view.resetPadding();
    t.view.resetViewPadding();
  });
  Get.put<MyTripsController>(OverlayTrips(), permanent: true);
  await t.pumpWidget(RepaintBoundary(
    key: _rootKey,
    child: GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: !animate),
        child: c!,
      ),
      home: _Shell(taps: taps),
    ),
  ));
}

Future<void> _shot(WidgetTester t, String name) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_rootKey));
  final file = File('$shotsDir/$name.png');
  await t.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Rect _rect(WidgetTester t, Finder f) {
  final b = t.renderObject<RenderBox>(f);
  return MatrixUtils.transformRect(b.getTransformTo(null), Offset.zero & b.size);
}

bool _under(RenderObject? o, RenderObject ancestor) {
  while (o != null) {
    if (identical(o, ancestor)) return true;
    o = o.parent;
  }
  return false;
}

bool _hits(WidgetTester t, Offset p, RenderObject target) {
  final r = HitTestResult();
  t.binding.hitTestInView(r, p, t.view.viewId);
  return r.path.any((e) => e.target is RenderObject && _under(e.target as RenderObject, target));
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  const sizes = {'360x800': Size(360, 800), '300x640': Size(300, 640)};
  const scales = [1.0, 1.3];
  final slots = {0: 'nav_tab_0', 1: 'nav_tab_1', 3: 'nav_tab_3', 4: 'nav_tab_4'};

  for (final e in sizes.entries) {
    for (final s in scales) {
      for (final animate in [false, true]) {
        final name = '${e.key}_s${s == 1.0 ? '10' : '13'}_${animate ? 'entrance' : 'settled'}';
        testWidgets('trip bar never takes nav taps $name', (t) async {
          debugDisableShadows = false;
          shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\small_fix_profile_tripbar';
          final taps = <int>[];
          await _pump(t, taps, e.value, s, animate: animate);
          await t.pump(Duration(milliseconds: animate ? 60 : 1600));
          if (!animate) await settlePhone(t);

          final barBox = find.descendant(of: find.byType(TripBar), matching: find.byType(InkWell)).first;
          final bar = _rect(t, barBox);
          final barObj = t.renderObject(find.byType(TripBar));
          final nav = _rect(t, find.byType(TemplateBottomBar));
          final shape = _rect(t, find.descendant(of: find.byType(TemplateBottomBar), matching: find.byType(PhysicalShape)).first);
          if (!animate) expect(bar.bottom, lessThanOrEqualTo(nav.top + 0.5));
          // ignore: avoid_print
          print('$name bar $bar nav $nav overlap ${(bar.bottom - nav.top).toStringAsFixed(1)} shapeTop ${shape.top}');
          await _shot(t, 'overlap_$name');

          final keys = {...slots, 2: 'nav_2'};
          final pickers = <Offset Function(Rect)>[
            (r) => r.center,
            (r) => Offset(r.center.dx, r.top + 2),
            (r) => Offset(r.left + 4, r.top + 2),
            (r) => Offset(r.right - 4, r.top + 2),
          ];
          for (final k in keys.entries) {
            for (final pick in k.key == 2 ? pickers.take(2) : pickers) {
              final r = _rect(t, find.byKey(ValueKey(k.value)));
              final o = k.key == 2 && pick != pickers.first ? Offset(r.center.dx, r.top + r.height * 0.3) : pick(r);
              final mid = _rect(t, barBox);
              expect(_hits(t, o, barObj), isFalse, reason: 'nav $name slot ${k.key} at $o (bar now $mid, nav $nav, shape $shape)');
              taps.clear();
              await t.tapAt(o);
              await t.pump(const Duration(milliseconds: 16));
              expect(taps, [k.key], reason: 'tap $name slot ${k.key} at $o');
            }
          }
          await t.pump(const Duration(seconds: 2));
          expect(t.takeException(), isNull);
          debugDisableShadows = true;
        });
      }
    }
  }
}
