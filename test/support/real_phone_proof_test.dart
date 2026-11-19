import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
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

}
