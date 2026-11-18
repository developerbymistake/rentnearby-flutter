import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

TripSpotRef engineSpot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

DateTime daysFromToday(int n) {
  final t = TripClock.today();
  return DateTime(t.year, t.month, t.day + n);
}

const _cities = [
  (key: 1, name: 'Nainital', lat: 29.4, lon: 79.4),
  (key: 2, name: 'Almora', lat: 29.6, lon: 79.6),
  (key: 3, name: 'Kausani', lat: 29.8, lon: 79.6),
];

// perLeg[k][i] = places on day i of city k+1. Spot ids are L{city}d{day}s{n}, day counted inside the city.
TripPlan enginePlan(List<List<int>> perLeg, {DateTime? start, Set<int> restDays = const {}}) {
  final legs = <TripCityLeg>[];
  final days = <TripDay>[];
  var day = 1;
  for (var k = 0; k < perLeg.length; k++) {
    final c = _cities[k];
    legs.add(TripCityLeg(index: k + 1, cityKey: c.key, cityName: c.name, latitude: c.lat, longitude: c.lon));
    for (var i = 0; i < perLeg[k].length; i++, day++) {
      days.add(TripDay(
        day: day,
        leg: k + 1,
        restDay: restDays.contains(day) && perLeg[k][i] == 0,
        spots: [for (var n = 0; n < perLeg[k][i]; n++) engineSpot('L${k + 1}d${i + 1}s$n')],
      ));
    }
  }
  return TripPlan(legs: legs, days: days, settings: TripSettings(startDate: start ?? DateTime(2030, 11, 1)));
}

Map<String, dynamic> engineTripJson(TripPlan plan, {Map<String, dynamic> extra = const {}}) => {
      'id': 't1',
      'title': 'Uttarakhand Hills Trip',
      'status': TripStatuses.planned,
      'cityKey': plan.legs.isEmpty ? 1 : plan.legs.first.cityKey,
      'cityName': plan.legs.isEmpty ? 'Nainital' : plan.legs.first.cityName,
      'cityLatitude': 29.4,
      'cityLongitude': 79.4,
      'dayCount': plan.days.length,
      'spotCount': plan.spotCount,
      'plan': plan.toJson(),
      'createdAt': '2026-11-01T00:00:00Z',
      'updatedAt': '2026-11-01T00:00:00Z',
      ...extra,
    };

TripModel engineTrip(TripPlan plan, {TripPlanLock lock = TripPlanLock.none, String status = TripStatuses.planned}) =>
    TripModel(
      id: 't1',
      title: 'Uttarakhand Hills Trip',
      status: status,
      cityKey: 1,
      cityName: 'Nainital',
      cityLatitude: 29.4,
      cityLongitude: 79.4,
      dayCount: plan.days.length,
      spotCount: plan.spotCount,
      plan: plan,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
      planLock: lock,
    );

const lockedByRequest = TripPlanLock(
  locked: true,
  reason: TripPlanLockReasons.taxiRequestActive,
  requestId: '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101',
);

TripPlanController engineRig(
  TripPlan plan, {
  TripPlanLock lock = TripPlanLock.none,
  List<TripEnquiryModel> rows = const [],
  String status = TripStatuses.planned,
}) {
  final c = TripPlanController();
  addTearDown(c.onClose);
  c.plan.value = plan;
  c.trip.value = engineTrip(plan, lock: lock, status: status);
  c.enquiryList.assignAll(rows);
  return c;
}

List<String> legSignature(TripPlan p, int legIndex) =>
    [for (final d in p.daysOf(legIndex)) '${d.restDay ? 'R' : ''}:${d.spots.map((s) => s.id).join(',')}'];

Map<String, dynamic> contractSample(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

String contractSampleText(String name) => File('test/features/taxi_request/samples/$name').readAsStringSync();
