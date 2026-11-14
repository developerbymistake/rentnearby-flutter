import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_day_card.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_hero.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_stats.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_todo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../ui_golden/golden_support.dart';

TripCityModel _city(int k, String name, String state) => TripCityModel(
      cityKey: k,
      name: name,
      districtName: 'District',
      stateName: state,
      latitude: 1,
      longitude: 1,
      spotCount: 8 + k,
      status: TripCityStatus.ready,
    );

class _Catalog extends TripCityCatalog {
  _Catalog(this.list);
  final List<TripCityModel> list;
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => list;
  @override
  List<TripCityModel> search(String q) => TripCitySearch.filter(list, q);
  @override
  List<TripCityModel> ready(String q, {String? stateName}) => [
        for (final c in q.trim().isEmpty ? list : search(q))
          if (c.isReady && (stateName == null || c.stateName == stateName)) c,
      ];
  @override
  List<String> liveStates() => ({for (final c in list) c.stateName}.toList())..sort();
}

class _Trips extends MyTripsController {
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {}
  @override
  List<TripSummaryModel> get continueTrips {
    active.length;
    return [TripSummaryModel(
      id: 't1',
      title: 'Nainital and Almora',
      status: 'draft',
      cityName: 'Nainital',
      dayCount: 4,
      spotCount: 9,
      category: 'trip',
      updatedAt: DateTime(2030, 1, 1),
      progress: const TripProgress(total: 5, done: 3, percent: 60),
    )];
  }

}

class _Repo implements TripShortlistRepository {
  _Repo(this.items);
  final List<ShortlistItem> items;
  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: items);
  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];
  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {}
  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}
  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async =>
      const MarkBookedResult(closedEnquiries: 1, closedShortlist: 1);
}

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

TripPlan _plan({TripGuide? guide}) => TripPlan(
      legs: [
        for (var k = 1; k <= 2; k++)
          TripCityLeg(index: k, cityKey: k, cityName: k == 1 ? 'Nainital' : 'Almora', latitude: 29.4 + k / 10, longitude: 79.4),
      ],
      days: [for (var k = 1; k <= 2; k++) TripDay(day: k, leg: k, spots: [_spot('s$k')])],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      guide: guide,
    );

ShortlistItem _item(String step, String name) => ShortlistItem(
      stepKey: step,
      kind: ShortlistKinds.stay,
      listingId: 'id-$name',
      name: name,
      state: ShortlistStates.active,
    );

Widget _host(double w, double h, Widget child) => GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: MediaQueryData(size: Size(w, h), textScaler: TextScaler.noScaling, disableAnimations: true),
        child: Scaffold(backgroundColor: goldenBg, body: RepaintBoundary(key: const ValueKey('golden_root'), child: child)),
      ),
    );

Future<void> _guide(WidgetTester t, double w, String name, TripPlan plan, List<ShortlistItem> items) async {
  final sl = TripShortlistController(repo: _Repo(items), tripId: () async => 't1', offline: () => false, warn: (_) {});
  Get.put<TripShortlistController>(sl);
  final c = TripPlanController();
  c.plan.value = plan;
  setGoldenView(t, Size(w, 760));
  await t.pumpWidget(_host(
    w,
    760,
    Column(children: [
      Container(height: 96, color: ListingTone.indigo.g2),
      Expanded(child: TripGuideView(controller: c, shortlist: sl)),
    ]),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await t.pump(const Duration(milliseconds: 100));
  await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/$name-${w.toInt()}.png'));
  c.onClose();
}

TripSummaryRecord _record() => TripSummaryRecord.fromJson({
      'tripId': 't1',
      'title': 'Nainital and Almora',
      'city': 'Nainital',
      'startDate': '2026-12-12',
      'endDate': '2026-12-15',
      'adults': 2,
      'kids': 0,
      'agreedTotal': 0,
      'days': [
        {'day': 1, 'spots': ['Naini Lake', 'Snow View', 'Mall Road'], 'minutes': 200},
        {'day': 2, 'spots': ['Bhimtal', 'Sattal']},
        {'day': 3, 'spots': ['Kasar Devi', 'Chitai Temple']},
      ],
      'nights': [
        {'night': 1, 'listingName': 'Hill View', 'displayStatus': 'confirmedByBoth'},
      ],
      'arrangements': [
        {'key': 'gettingThere', 'title': 'Getting there', 'state': 'confirmed'},
        {'key': 'stay:1', 'title': 'Stay in Nainital', 'state': 'confirmed'},
        {'key': 'taxi', 'title': 'Local taxi', 'state': 'asked'},
        {'key': 'stay:2', 'title': 'Stay in Almora', 'state': 'todo'},
      ],
    });

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  for (final w in [300.0, 360.0, 560.0]) {
    testWidgets('golden trips tab @${w.toInt()}', (t) async {
      final cities = [
        _city(1, 'Nainital', 'Uttarakhand'),
        _city(2, 'Rishikesh', 'Uttarakhand'),
        _city(3, 'Manali', 'Himachal Pradesh'),
        _city(4, 'Shimla', 'Himachal Pradesh'),
      ];
      Get.put<TripCityCatalog>(_Catalog(cities), permanent: true);
      Get.put<MyTripsController>(_Trips(), permanent: true);
      setGoldenView(t, Size(w, 760));
      await t.pumpWidget(_host(w, 760, const TripsDiscoveryScreen()));
      await t.pump();
      for (var i = 0; i < 3; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await t.pump(const Duration(milliseconds: 300));
      }
      await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/trips_tab-${w.toInt()}.png'));
    });

    testWidgets('golden guided step @${w.toInt()}', (t) async {
      await _guide(t, w, 'guide_step', _plan(), const []);
    });

    testWidgets('golden after shortlist @${w.toInt()}', (t) async {
      await _guide(
        t,
        w,
        'guide_review',
        _plan(guide: const TripGuide(step: 'stay:1', choices: {'gettingThere': TripGuideChoice.skip, 'stay:1': TripGuideChoice.find})),
        [_item('stay:1', 'Hill View'), _item('stay:1', 'Lake Inn')],
      );
    });

    testWidgets('golden summary @${w.toInt()}', (t) async {
      final r = _record();
      setGoldenView(t, Size(w, 900));
      await t.pumpWidget(_host(
        w,
        900,
        SingleChildScrollView(
          child: Column(children: [
            TripSummaryHero(record: r),
            TripSummaryStats(record: r),
            TripSummaryTodo(record: r, onOpen: (_) {}),
            for (final d in r.days) TripSummaryDayCard(day: d, stay: TripDayChips.stay(r, d), taxi: TripDayChips.taxi(r, d)),
          ]),
        ),
      ));
      await t.pump(const Duration(milliseconds: 800));
      await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/summary-${w.toInt()}.png'));
    });
  }
}
