import 'package:bakhli/design/extra/template_nav.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/utils/trip_bar_rules.dart';
import 'package:bakhli/features/trip/widgets/trip_bar.dart';
import 'package:bakhli/navigation/app_bottom_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/real_phone.dart';

class OverlayTrips extends MyTripsController {
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {}
  @override
  TripBarPick? get barPick {
    active.length;
    return TripBarPick(
      TripSummaryModel(
        id: 't1',
        title: 'Nainital and Almora',
        status: 'draft',
        cityName: 'Nainital',
        dayCount: 4,
        spotCount: 9,
        category: 'trip',
        updatedAt: DateTime(2030, 1, 1),
        progress: const TripProgress(total: 5, done: 3, percent: 60),
      ),
      more: 2,
    );
  }
}

class OverlayShell extends StatelessWidget {
  const OverlayShell({super.key, required this.body, this.banner = true, this.index = 0});

  final Widget body;
  final bool banner;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: body,
      bottomNavigationBar: AppBottomDock(
        banner: banner ? const TripBar() : const SizedBox.shrink(),
        nav: TemplateBottomBar(
          bottomInset: MediaQuery.of(context).viewPadding.bottom,
          selectedIndex: index,
          onTap: (_) {},
          items: const [
            TemplateNavItem(index: 0, label: 'Home', image: 'assets/images/design/fitness_app/tab_1.png'),
            TemplateNavItem(index: 1, label: 'Stays', image: 'assets/images/design/travel3d/hotel.png'),
            TemplateNavItem(index: 2, label: 'Trips', image: 'assets/images/design/travel3d/compass.png', center: true),
            TemplateNavItem(index: 3, label: 'Taxi', image: 'assets/images/design/travel3d/taxi.png'),
            TemplateNavItem(index: 4, label: 'Profile', image: 'assets/images/design/fitness_app/tab_4.png'),
          ],
        ),
      ),
    );
  }
}

Rect _rect(RenderBox b) => b.localToGlobal(Offset.zero) & b.size;

double overlayTop(WidgetTester t, {Finder? pill}) {
  var top = double.infinity;
  for (final f in [find.byType(TemplateBottomBar), find.byType(TripBar), ?pill]) {
    if (f.evaluate().isEmpty) continue;
    final r = _rect(t.renderObject<RenderBox>(f.first));
    if (r.height > 0 && r.top < top) top = r.top;
  }
  return top;
}

double contentBottom(WidgetTester t, Finder scope) {
  final screenH = t.view.physicalSize.height / t.view.devicePixelRatio;
  final root = t.renderObject(scope.first);
  var bottom = -1.0;
  void visit(RenderObject o) {
    if (o is RenderBox && o.hasSize && (o is RenderParagraph || o is RenderImage)) {
      final r = _rect(o);
      if (r.height > 0 && r.bottom <= screenH && r.top >= 0) bottom = r.bottom > bottom ? r.bottom : bottom;
    }
    o.visitChildren(visit);
  }

  visit(root);
  return bottom;
}

Future<void> scrollToEnd(WidgetTester t, Finder scope) async {
  final s = find.descendant(of: scope, matching: find.byType(Scrollable));
  for (final e in s.evaluate()) {
    final pos = (e as StatefulElement).state as ScrollableState;
    if (pos.position.axis != Axis.vertical) continue;
    pos.position.jumpTo(pos.position.maxScrollExtent);
  }
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> pumpOverlay(WidgetTester t, Widget body, {Size size = phoneSize, double scale = 1.0, bool banner = true}) async {
  Get.put<MyTripsController>(OverlayTrips(), permanent: true);
  await pumpPhone(t, OverlayShell(body: body, banner: banner), size: size, textScale: scale);
  await settlePhone(t);
}

void overlayTest(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = true;
    }
  });
}
