import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'real_phone.dart';

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



void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  testWidgets('real phone: trips tab', (t) async {
    final cities = [_city(1, 'Nainital', 'Uttarakhand'), _city(2, 'Rishikesh', 'Uttarakhand'), _city(3, 'Manali', 'Himachal Pradesh')];
    Get.put<TripCityCatalog>(_Catalog(cities), permanent: true);
    Get.put<MyTripsController>(_Trips(), permanent: true);
    await pumpPhone(t, const TripsDiscoveryScreen());
    await settlePhone(t);
    final f = await shot(t, 'proof_trips_tab');
    expect(f.lengthSync(), greaterThan(10000));
  });

  testWidgets('real phone: guide card', (t) async {
    final sl = TripShortlistController(repo: _Repo(const []), tripId: () async => 't1', offline: () => false, warn: (_) {});
    Get.put<TripShortlistController>(sl);
    final c = TripPlanController();
    c.plan.value = _plan();
    await pumpPhone(t, Scaffold(body: SafeArea(child: TripGuideView(controller: c, shortlist: sl))));
    await settlePhone(t);
    final f = await shot(t, 'proof_guide_card');
    expect(f.lengthSync(), greaterThan(10000));
    c.onClose();
  });
}
