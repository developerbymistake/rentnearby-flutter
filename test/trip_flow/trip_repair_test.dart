import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/widgets/trip_city_art.dart';
import 'package:bakhli/features/trip/widgets/trip_city_tile.dart';
import 'package:bakhli/features/trip/trip_strings_guide.dart';
import 'package:bakhli/features/trip/trip_strings_shortlist.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_options.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../journeys/fake_api.dart';

const _shots = 'F:/Dhasu/UI_Template_resume/Repair/shots';

class _Repo implements TripShortlistRepository {
  @override
  Future<TripShortlist> list(String tripId) async => const TripShortlist(items: []);
  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];
  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {}
  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}
  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async =>
      const MarkBookedResult(closedEnquiries: 0, closedShortlist: 0);
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Future<TripPlanController> _rig({TripGuide? guide, List<int> legs = const [3]}) async {
  Get.reset();
  final sl = TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {});
  Get.put<TripShortlistController>(sl);
  Get.put<TripEnquiryController>(TripEnquiryController());
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c);
  final p = journeyPlan(legs, start: DateTime.now().add(const Duration(days: 10)));
  c.plan.value = guide == null ? p : p.withGuide(guide);
  await sl.load(force: true);
  return c;
}

final _boundary = GlobalKey();

Widget _app(Widget home, double scale) => RepaintBoundary(
      key: _boundary,
      child: GetMaterialApp(
        getPages: [
          GetPage(name: AppRoutes.tripMap, page: () => const Scaffold(body: Text('map-stub'))),
          GetPage(name: AppRoutes.tripStay, page: () => const Scaffold(body: Text('stay-stub'))),
          GetPage(name: AppRoutes.tripSummary, page: () => const Scaffold(body: Text('summary-stub'))),
        ],
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: child!,
        ),
        home: home,
      ),
    );

void _size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final b = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_shots/$name.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  for (final w in [300.0, 360.0, 412.0]) {
    for (final s in [1.0, 1.3, 2.0]) {
      testWidgets('S2 guide options never overlap and the card clears the bar at $w dp scale $s', (t) async {
        final c = await _rig();
        _size(t, w, 800);
        await t.pumpWidget(_app(const TripPlanScreen(), s));
        c.planStep.value = 2;
        await _settle(t);
        expect(c.guideState.on.value, isTrue);
        final opts = find.byType(TripGuideOption);
        expect(opts, findsNWidgets(3));
        final scroll = find.byType(SingleChildScrollView).first;
        await t.drag(scroll, const Offset(0, -3000));
        await t.pump();
        final rects = [for (var i = 0; i < 3; i++) t.getRect(opts.at(i))];
        for (var i = 0; i < 2; i++) {
          expect(rects[i].bottom, lessThanOrEqualTo(rects[i + 1].top), reason: 'option $i overlaps the next');
        }
        final bar = t.getRect(find.text(TripStringsGuide.next).last);
        expect(rects.last.bottom, lessThanOrEqualTo(bar.top));
        expect(t.takeException(), isNull);
        if (w == 360 && s == 1.3) {
          await t.drag(scroll, const Offset(0, 3000));
          await t.pump();
          await _shot(t, 'trips_guide_360_s13');
        }
      });
    }
  }

  testWidgets('S1 shortlist bar docks at the bottom with the list above it', (t) async {
    await _rig();
    _size(t, 360, 700);
    await t.pumpWidget(_app(
      Scaffold(
        body: ListView(children: [for (var i = 0; i < 30; i++) ListTile(title: Text('Row $i'))]),
        bottomNavigationBar: TripShortlistBar(step: 'stay:1', onDone: () {}),
      ),
      1.3,
    ));
    await _settle(t);
    final bar = t.getRect(find.byType(TripShortlistBar));
    expect(bar.bottom, closeTo(700, 0.5));
    expect(bar.height, lessThan(120));
    expect(find.text('Row 0'), findsOneWidget);
    expect(find.text(TripStringsShortlist.done), findsOneWidget);
    await _shot(t, 'trips_shortlist_bar_360_s13');
  });

  testWidgets('S3 plan header keeps its size and position while scrolling', (t) async {
    final c = await _rig(legs: [4]);
    _size(t, 360, 740);
    await t.pumpWidget(_app(const TripPlanScreen(), 1.3));
    c.planStep.value = 1;
    await _settle(t);
    final head = find.byType(TripPlanHeader);
    final r0 = t.getRect(head);
    expect(r0.top, 0);
    await _shot(t, 'trips_plan_header_scroll0');
    final list = find.byType(ListView).first;
    for (final dy in [-150.0, -400.0, -1500.0]) {
      await t.drag(list, Offset(0, dy));
      await t.pump();
      expect(t.getRect(head), r0);
      expect(t.takeException(), isNull);
    }
    await _shot(t, 'trips_plan_header_scroll_end');
    final title = t.getRect(find.text(c.title).first);
    final map = t.getRect(find.byTooltip('Map'));
    expect(title.right, lessThanOrEqualTo(map.left + 0.5));
  });

  testWidgets('S4 every control on the Plan and guide screens does something', (t) async {
    final c = await _rig();
    _size(t, 412, 900);
    await t.pumpWidget(_app(const TripPlanScreen(), 1.0));
    c.planStep.value = 2;
    await _settle(t);

    await t.tap(find.byTooltip('Map'));
    await _settle(t);
    expect(find.text('map-stub'), findsOneWidget);
    Get.back();
    await _settle(t);

    await t.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(t);
    expect(find.byType(PopupMenuItem<TripPlanMenu>), findsWidgets);
    t.takeException();
    await t.tapAt(const Offset(5, 880));
    await _settle(t);

    await t.tap(find.text(c.settings.isRelaxed ? 'Relaxed' : 'Normal').first);
    await _settle(t);
    expect(find.byType(BottomSheet), findsOneWidget);
    await t.tapAt(const Offset(5, 5));
    await _settle(t);

    expect(find.byType(TripGuideView), findsOneWidget);
    c.guideJumpTo('stay:1');
    await _settle(t);
    await t.tap(find.text(TripStringsGuide.optFind));
    await _settle(t);
    expect(find.text('stay-stub'), findsOneWidget);
    Get.back();
    await _settle(t);
    expect(c.guideState.current.value, TripGuideChoice.find);
    await t.tap(find.text(TripStringsGuide.optOwn));
    await _settle(t);
    expect(c.guideState.current.value, TripGuideChoice.own);
    await t.tap(find.text(TripStringsGuide.optSkip));
    await _settle(t);
    expect(c.guideState.current.value, TripGuideChoice.skip);

    final before = c.guideState.index.value;
    await t.tap(find.text(TripStringsGuide.next));
    await _settle(t);
    expect(c.guideState.index.value, before + 1);
    await t.tap(find.text(TripStringsGuide.previous));
    await _settle(t);
    expect(c.guideState.index.value, before);

    await t.tap(find.text(TripStringsGuide.overview));
    await _settle(t);
    expect(find.text(TripStringsGuide.overviewTitle), findsOneWidget);
    await _shot(t, 'trips_overview_sheet_412');
    expect(find.text(TripStringsGuide.backToSteps), findsNothing);
    await t.tapAt(const Offset(5, 5));
    await _settle(t);
    expect(find.text(TripStringsGuide.overviewTitle), findsNothing);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('city tiles without a photo draw their own art, one look per city', (t) async {
    _size(t, 360, 800);
    final cities = [
      for (var i = 0; i < 6; i++)
        TripCityModel(cityKey: 210000001 + i, name: 'City $i', districtName: 'District', latitude: 29, longitude: 79, spotCount: 4 + i),
    ];
    var tapped = 0;
    await t.pumpWidget(_app(
      Scaffold(
        body: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: TripCityTile.aspect,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [for (final c in cities) TripCityTile(city: c, onTap: () => tapped++)],
        ),
      ),
      1.3,
    ));
    await _settle(t);
    expect(find.byType(TripCityArt), findsNWidgets(6));
    final tones = {for (var i = 0; i < 6; i++) TripCityArt.toneOf(210000001 + i)};
    expect(tones.length, greaterThan(3));
    await t.tap(find.byType(TripCityTile).first);
    expect(tapped, 1);
    expect(t.takeException(), isNull);
    await _shot(t, 'trips_city_tiles_360_s13');
  });
}
