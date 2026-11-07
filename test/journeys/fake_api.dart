import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';

// One canned answer: method + path ({id} matches one segment) -> the envelope {status, code, data} (or error).
class FakeRoute {
  final String method;
  final String path;
  final int code;
  final Object? Function(RequestOptions request) data;
  final String? errorType;
  final Map<String, String> headers;

  FakeRoute(this.method, this.path, Object? Function(RequestOptions request) data,
      {this.code = 200, this.errorType, this.headers = const {}})
      : data = data;

  FakeRoute.value(String method, String path, Object? value,
      {int code = 200, String? errorType, Map<String, String> headers = const {}})
      : this(method, path, (_) => value, code: code, errorType: errorType, headers: headers);

  bool matches(RequestOptions o) {
    if (o.method.toUpperCase() != method.toUpperCase()) return false;
    final want = path.split('/');
    final got = o.path.split('/');
    if (want.length != got.length) return false;
    for (var i = 0; i < want.length; i++) {
      if (!want[i].startsWith('{') && want[i] != got[i]) return false;
    }
    return true;
  }
}

// No network: every request is answered from the route list; an unknown route is a 404 so a missing stub is loud.
class FakeTripAdapter implements HttpClientAdapter {
  final List<FakeRoute> routes;
  final List<RequestOptions> seen = [];

  FakeTripAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final route = routes.where((r) => r.matches(options)).firstOrNull;
    if (route == null) return _body(404, {'status': '404', 'code': 404, 'error': {'message': 'No stub', 'type': 'NoStub'}}, const {});
    final error = route.errorType == null ? null : {'message': route.errorType, 'type': route.errorType};
    final envelope = {
      'status': '${route.code}',
      'code': route.code,
      'data': route.data(options),
      'error': ?error,
    };
    return _body(route.code, envelope, route.headers);
  }

  ResponseBody _body(int code, Map<String, Object?> envelope, Map<String, String> headers) => ResponseBody.fromString(
        jsonEncode(envelope),
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          for (final e in headers.entries) e.key: [e.value],
        },
      );

  List<RequestOptions> calls(String method, String path) =>
      [for (final o in seen) if (o.method.toUpperCase() == method.toUpperCase() && o.path == path) o];

  @override
  void close({bool force = false}) {}
}

// Installs the adapter on the app's single Dio (ApiService.init builds it; no token, no network).
FakeTripAdapter installFakeApi(List<FakeRoute> routes) {
  ApiService.init();
  final adapter = FakeTripAdapter(routes);
  ApiService.dio.httpClientAdapter = adapter;
  return adapter;
}

// ---------- shared builders ----------

TripSpotRef journeySpot(String id) =>
    TripSpotRef(id: id, name: 'Place $id', latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

DateTime journeyStart() => TripClock.today().add(const Duration(days: 10));

// legs: days per city, in order; one place a day; start date ten days from today.
TripPlan journeyPlan(List<int> legDays, {DateTime? start}) {
  final legs = <TripCityLeg>[];
  final days = <TripDay>[];
  var day = 1;
  for (var i = 0; i < legDays.length; i++) {
    legs.add(TripCityLeg.fromCity(i + 1, TripCityModel(cityKey: 210000001 + i, name: 'City ${i + 1}', latitude: 29.4 + i, longitude: 79.4)));
    for (var n = 0; n < legDays[i]; n++, day++) {
      days.add(TripDay(day: day, leg: i + 1, spots: [journeySpot('s$day')]));
    }
  }
  return TripPlan(legs: legs, days: days, settings: TripSettings(startDate: start ?? journeyStart(), adults: 2, kids: 0));
}

String journeyDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// The server's enquiry JSON (only what the app reads). Days/nights count from `start`.
Map<String, Object?> enquiryJson({
  required String id,
  required String kind,
  required String status,
  required DateTime start,
  int day = 1,
  int nights = 1,
  List<int>? days,
  int? cityLeg,
  String tripId = 't1',
  String displayStatus = 'asked',
  int? agreedTotal,
  List<String> contextSpots = const [],
}) {
  final taxi = kind == TripEnquiryKinds.taxi;
  final first = taxi ? (days ?? [day]).reduce((a, b) => a < b ? a : b) : day;
  final last = taxi ? (days ?? [day]).reduce((a, b) => a > b ? a : b) : day + nights - 1;
  final checkIn = start.add(Duration(days: first - 1));
  final checkOut = start.add(Duration(days: last));
  return {
    'id': id,
    'tripId': tripId,
    'kind': kind,
    'listingId': 'listing-$id',
    'listingName': taxi ? 'Driver $id' : 'Stay $id',
    if (!taxi) 'day': day,
    if (taxi) 'days': days ?? [day],
    'cityLeg': ?cityLeg,
    'checkIn': journeyDate(checkIn),
    'checkOut': journeyDate(checkOut),
    'nights': taxi ? (days ?? [day]).length : nights,
    'status': status,
    'displayStatus': displayStatus,
    'agreedTotal': ?agreedTotal,
    'isSegment': false,
    'context': {
      'days': [
        for (var d = first; d <= last; d++) {'day': d, 'spots': contextSpots},
      ],
    },
  };
}
