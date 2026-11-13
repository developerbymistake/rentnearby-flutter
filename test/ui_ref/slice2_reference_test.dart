import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/design/template/design_course/popular_course_list_view.dart' as course;
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_bar.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_card.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_options.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_progress.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:bakhli/features/trip/widgets/trip_stay_row.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/models/browse_item.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:bakhli/models/home_feed_model.dart';
import 'package:bakhli/widgets/home_stay_rail_card.dart';
import 'package:bakhli/widgets/home_taxi_rail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

const _out = r'F:\Dhasu\UI_Template_resume\Slice2\shots';
final _log = StringBuffer();

class _Repo implements TripShortlistRepository {
  final items = <ShortlistItem>[];
  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: List.of(items), max: 3);
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

TripPlan _plan() => TripPlan(
      legs: [TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.4, longitude: 79.4)],
      days: [
        TripDay(day: 1, leg: 1, spots: [TripSpotRef(id: 's1', name: 'Naini Lake', latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60)]),
      ],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
    );

void _size(WidgetTester t, String label, Finder f) {
  if (f.evaluate().isEmpty) {
    _log.writeln('$label: NOT FOUND');
    return;
  }
  final r = t.getRect(f.first);
  _log.writeln('$label: ${r.width.toStringAsFixed(1)} x ${r.height.toStringAsFixed(1)} at (${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)})');
}

void _texts(WidgetTester t, String label, Finder scope) {
  for (final e in find.descendant(of: scope, matching: find.byType(Text)).evaluate()) {
    final w = e.widget as Text;
    final txt = w.data ?? w.textSpan?.toPlainText() ?? '';
    final style = w.style ?? DefaultTextStyle.of(e).style;
    final box = e.renderObject as RenderBox;
    _log.writeln('$label text "${txt.replaceAll('\n', ' ')}" size=${style.fontSize} weight=${style.fontWeight?.value} h=${box.size.height.toStringAsFixed(1)} w=${box.size.width.toStringAsFixed(1)}');
  }
}

void _buttons(WidgetTester t, String label) {
  for (final b in find.byType(TripButton).evaluate()) {
    final r = t.getRect(find.byWidget(b.widget));
    _log.writeln('$label TripButton ${r.width.toStringAsFixed(1)} x ${r.height.toStringAsFixed(1)}');
  }
}

Widget _page(Widget child) => Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: SafeArea(child: SingleChildScrollView(child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRealFonts();
    shotsDir = _out;

  });
  tearDownAll(() => File('$_out\\measure_log.txt').writeAsStringSync(_log.toString()));

  _tw('tpl hotel card', (t) async {
    final theme = HotelAppTheme.buildLightTheme();
    await pumpPhone(
      t,
      Theme(
        data: theme,
        child: Scaffold(
          body: SafeArea(
            child: ListView(children: [
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 16),
                child: Container(
                  key: const ValueKey('hotel'),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                    boxShadow: <BoxShadow>[BoxShadow(color: Colors.grey.withValues(alpha: 0.6), offset: const Offset(4, 4), blurRadius: 16)],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                    child: Column(children: [
                      AspectRatio(aspectRatio: 2, child: Image.asset('assets/images/design/hotel/hotel_1.png', fit: BoxFit.cover)),
                      Container(
                        color: theme.colorScheme.surface,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Grand Royal Hotel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
                                Row(children: [
                                  Text('Wembley, London', style: TextStyle(fontSize: 14, color: Colors.grey.withValues(alpha: 0.8))),
                                  const SizedBox(width: 4),
                                  Icon(Icons.location_on, size: 12, color: theme.primaryColor),
                                  Expanded(child: Text('2.0 km to city', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey.withValues(alpha: 0.8)))),
                                ]),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(children: [
                                    for (var i = 0; i < 5; i++) Icon(i < 4 ? Icons.star_rate_rounded : Icons.star_half_rounded, size: 24, color: theme.primaryColor),
                                    Text(' 80 Reviews', style: TextStyle(fontSize: 14, color: Colors.grey.withValues(alpha: 0.8))),
                                  ]),
                                ),
                              ]),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 16, top: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('\$180', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
                              Text('/per night', style: TextStyle(fontSize: 14, color: Colors.grey.withValues(alpha: 0.8))),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    await settlePhone(t);
    _size(t, 'tpl hotel card', find.byKey(const ValueKey('hotel')));
    await shot(t, 'ref_tpl_hotel_card');
  });

  _tw('tpl meals + course', (t) async {
    final a = AnimationController(vsync: t, duration: const Duration(milliseconds: 1))..value = 1;
    final anim = CurvedAnimation(parent: a, curve: Curves.linear);
    await pumpPhone(
      t,
      Scaffold(
        backgroundColor: FitnessAppTheme.background,
        body: SafeArea(
          child: ListView(children: [
            SizedBox(
              height: 216,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16, left: 16),
                children: [
                  for (final m in MealsListData.tabIconsList) MealsView(mealsListData: m, animation: anim, animationController: a),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: course.CategoryView(category: Category.categoryList[0], animation: anim, animationController: a)),
                const SizedBox(width: 16),
                Expanded(child: course.CategoryView(category: Category.categoryList[1], animation: anim, animationController: a)),
              ]),
            ),
          ]),
        ),
      ),
    );
    await settlePhone(t);
    _size(t, 'tpl meals card', find.byType(MealsView));
    _size(t, 'tpl course card', find.byType(course.CategoryView));
    await shot(t, 'ref_tpl_meals_course');
  });

  _tw('ours guide', (t) async {
    Get.testMode = true;
    final repo = _Repo();
    final sl = TripShortlistController(repo: repo, tripId: () async => 't1', offline: () => false, warn: (_) {});
    Get.put<TripShortlistController>(sl);
    Get.put<TabConfigController>(_Tabs());
    final c = TripPlanController();
    c.plan.value = _plan();
    Get.put<TripPlanController>(c);
    c.guideState.opener = (ctx, row, guide) async => true;
    await pumpPhone(t, Scaffold(body: SafeArea(bottom: false, child: TripGuideView(controller: c, shortlist: sl))));
    await settlePhone(t);
    await shot(t, 'ref_ours_guide_1_empty');
    _size(t, 'guide frame', find.byType(TripGuideFrame));
    _size(t, 'guide progress', find.byType(TripGuideProgress));
    _size(t, 'guide bar', find.byType(TripGuideBar));
    final opts = find.byType(TripGuideOption);
    for (var i = 0; i < opts.evaluate().length; i++) {
      _size(t, 'guide option $i', opts.at(i));
    }
    _texts(t, 'guide(empty)', find.byType(TripGuideView));
    _buttons(t, 'guide(empty)');
    await t.tap(find.text('Help me find'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, 'ref_ours_guide_2_find');
    _size(t, 'guide bar (find chosen)', find.byType(TripGuideBar));
    repo.items.addAll([
      for (var i = 1; i <= 2; i++)
        ShortlistItem(stepKey: 'gettingThere', kind: ShortlistKinds.car, listingId: 'c$i', name: i == 1 ? 'Ramesh Negi' : 'Suresh Bisht', state: ShortlistStates.active),
    ]);
    await sl.load(force: true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await shot(t, 'ref_ours_guide_3_review');
    _size(t, 'guide frame (review)', find.byType(TripGuideFrame));
    _size(t, 'guide bar (review)', find.byType(TripGuideBar));
    _buttons(t, 'review');
    c.onClose();
    Get.reset();
  });

  _tw('ours stay + taxi lists', (t) async {
    final stay = StayNearbyModel(
      id: 's1',
      name: 'Hotel Himalayan View',
      stayTypeName: 'Hotel',
      latitude: 29.4,
      longitude: 79.4,
      minPricePerNight: 2400,
      distanceKm: 1.2,
      isActive: true,
      maxGuests: 4,
      meals: 'breakfast',
      checkInTime: '12:00',
      roomCount: 6,
      cityName: 'Nainital',
      districtName: 'Nainital',
    );
    await pumpPhone(
      t,
      _page(Padding(
        padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
        child: TripStayRow(key: const ValueKey('tsr'), stay: stay, onOpen: () {}, onCall: () {}, onAsk: () {}),
      )),
    );
    await settlePhone(t);
    _size(t, 'ours trip stay row', find.byKey(const ValueKey('tsr')));
    _texts(t, 'tsr', find.byKey(const ValueKey('tsr')));
    await shot(t, 'ref_ours_stay_trip_row');

    await pumpPhone(
      t,
      Builder(
        builder: (context) => _page(Padding(
          padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 8, KitMetrics.gutter, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 2; i++) ...[
              if (i == 1) const SizedBox(width: RailCard.gridSpacing),
              Expanded(
                child: SizedBox(
                  height: StayGridCard.heightOf(context),
                  child: StayGridCard(
                    key: ValueKey('sgc$i'),
                    thumbnailUrl: null,
                    tagLabel: 'FOR STAY',
                    title: 'Hotel Himalayan View',
                    locationLabel: 'Nainital, Nainital',
                    facts: const [CardFact('Hotel'), CardFact('Breakfast')],
                    priceCaption: 'FROM',
                    priceValue: 'Rs 2,400',
                    priceUnit: '/night',
                    onViewDetails: () {},
                  ),
                ),
              ),
            ],
          ]),
        )),
      ),
    );
    await settlePhone(t);
    _size(t, 'ours stay grid card', find.byKey(const ValueKey('sgc0')));
    _texts(t, 'sgc', find.byKey(const ValueKey('sgc0')));
    await shot(t, 'ref_ours_stay_grid_card');

    final taxi = TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Negi',
      vehicleTypeName: 'Sedan',
      seats: 4,
      plateDisplay: 'UK 04 AB 1234',
      cityName: 'Nainital',
      routeCount: 3,
      matchedFare: 5200,
      matchedFromName: 'Delhi',
      matchedToName: 'Nainital',
      matchedTripType: 'OneWay',
      matchReversed: false,
      createdAt: DateTime(2030, 1, 1),
    );
    await pumpPhone(
      t,
      _page(Column(children: [
        TaxiCard(key: const ValueKey('tc'), item: taxi, onOpen: () {}, onSelect: () {}, onEnquire: () {}),
        TaxiCard(item: taxi, onOpen: () {}),
      ])),
    );
    await settlePhone(t);
    _size(t, 'ours taxi card (trip mode)', find.byKey(const ValueKey('tc')));
    _texts(t, 'tc', find.byKey(const ValueKey('tc')));
    for (final b in find.byType(PillAction).evaluate()) {
      final r = t.getRect(find.byWidget(b.widget));
      _log.writeln('taxi PillAction ${r.width.toStringAsFixed(1)} x ${r.height.toStringAsFixed(1)}');
    }
    await shot(t, 'ref_ours_taxi_card');
  });

  _tw('ours home rails', (t) async {
    final stay = HomeStayModel(
      districtName: 'Nainital',
      item: BrowseItem(
        id: 's1',
        userId: 'u',
        thumbnailUrl: null,
        tagLabel: 'FOR STAY',
        title: 'Hotel Himalayan View',
        locationLabel: 'Nainital, Nainital',
        facts: const [CardFact('Hotel'), CardFact('Breakfast')],
        priceCaption: 'FROM',
        priceValue: 'Rs 2,400',
        priceUnit: '/night',
      ),
    );
    final taxi = TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Negi',
      vehicleTypeName: 'Sedan',
      seats: 4,
      plateDisplay: 'UK 04 AB 1234',
      cityName: 'Nainital',
      routeCount: 3,
      minFare: 1800,
      matchReversed: false,
      createdAt: DateTime(2030, 1, 1),
    );
    await pumpPhone(
      t,
      _page(MealsRail(
        padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
        children: [
          HomeStayRailCard(key: const ValueKey('hsr'), stay: stay, onOpen: () {}),
          const SizedBox(width: 12),
          HomeTaxiRailCard(key: const ValueKey('htr'), taxi: taxi, onOpen: () {}),
        ],
      )),
    );
    await settlePhone(t);
    _size(t, 'ours home stay rail card', find.byKey(const ValueKey('hsr')));
    _size(t, 'ours home taxi rail card', find.byKey(const ValueKey('htr')));
    _texts(t, 'hsr', find.byKey(const ValueKey('hsr')));
    await shot(t, 'ref_ours_home_rails');
  });
}

void _tw(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = true;
    }
  });
}
