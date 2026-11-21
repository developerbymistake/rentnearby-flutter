import 'dart:async';

import 'package:bakhli/features/owner_core/calendar/calendar_api.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_controller.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_deps.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';

final DateTime calToday = DateTime(2026, 11, 21);

Map<String, dynamic> tripJson(
  String id, {
  String kind = 'Manual',
  required String from,
  String? to,
  String? time,
  String? fromPlace,
  String? toPlace,
  String label = '',
  int? finalAmount,
  int? received,
  bool paid = false,
  bool cancelled = false,
  String? note,
  int? guests,
  int? seats,
  List<String> places = const [],
  String? cancelledBy,
  String? cancelledOn,
  String? sourceId,
  bool? sourceAvailable,
  int version = 1,
}) =>
    {
      'id': id,
      'kind': kind,
      'sourceType': kind == 'Auto' ? 'TaxiBooking' : null,
      'sourceId': sourceId ?? (kind == 'Auto' ? 'bk-$id' : null),
      'sourceAvailable': sourceAvailable ?? (kind == 'Auto' ? true : null),
      'dateFrom': from,
      'dateTo': to ?? from,
      'timeOfDay': time,
      'fromPlace': fromPlace,
      'toPlace': toPlace,
      'label': label,
      'note': note,
      'finalAmount': finalAmount,
      'advanceReceived': received,
      'paidInFull': paid,
      'cancelled': cancelled,
      'version': version,
      'guests': guests,
      'seats': seats,
      'places': places,
      'cancelledBy': cancelledBy,
      'cancelledOn': cancelledOn,
    };

List<Map<String, dynamic>> novEntries({bool paidExtras = false}) => [
      tripJson('m03', from: '2026-11-03', time: '08:00', fromPlace: 'Haldwani', label: 'Bhowali drop', finalAmount: paidExtras ? 900 : null, paid: paidExtras),
      tripJson('m12', from: '2026-11-12', time: '14:00', fromPlace: 'Haldwani', toPlace: 'Nainital', label: 'Family trip, Nainital', finalAmount: paidExtras ? 1500 : null, paid: paidExtras),
      tripJson('a16', kind: 'Auto', from: '2026-11-16', fromPlace: 'Kathgodam', toPlace: 'Bhimtal', label: 'Rahul Das', finalAmount: paidExtras ? 2700 : null, paid: paidExtras),
      tripJson('m19', from: '2026-11-19', time: '06:00', fromPlace: 'Haldwani', label: 'Corbett day trip', finalAmount: 2400, paid: true),
      tripJson('a23', kind: 'Auto', from: '2026-11-23', fromPlace: 'Kathgodam', toPlace: 'Nainital', label: 'Priya Rawat', guests: 3, finalAmount: 1800, paid: true),
      tripJson('m25', from: '2026-11-25', time: '09:30', fromPlace: 'Haldwani', toPlace: 'Mukteshwar', label: 'Mehra family', finalAmount: 2200, received: 0),
      tripJson('a28', kind: 'Auto', from: '2026-11-28', fromPlace: 'Pantnagar airport', toPlace: 'Haldwani', label: 'Vikram Singh', finalAmount: 1200, received: 0),
      tripJson('m28', from: '2026-11-28', time: '10:00', fromPlace: 'Haldwani', label: 'Bhimtal round trip', finalAmount: 1800, received: 800),
      tripJson('m30', from: '2026-11-30', fromPlace: 'Haldwani', toPlace: 'Ranikhet', label: 'Sharma family, Ranikhet', finalAmount: 2600, received: 1000),
    ];

List<Map<String, dynamic>> decEntries() => [
      tripJson('d05', from: '2026-12-05', time: '06:00', fromPlace: 'Haldwani', label: 'Corbett day trip'),
      tripJson('d12', from: '2026-12-12', time: '07:00', fromPlace: 'Haldwani', label: 'Naukuchiatal'),
      tripJson('d18', kind: 'Auto', from: '2026-12-18', to: '2026-12-26', fromPlace: 'Kathgodam', label: 'Aarav Sharma', seats: 4),
      tripJson('d25', from: '2026-12-25', time: '09:00', fromPlace: 'Haldwani', label: 'Christmas drop'),
    ];

const festivalJson = {'id': 'f1', 'name': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'stateName': 'Uttarakhand'};

Map<String, dynamic> monthJson({
  required List<Map<String, dynamic>> entries,
  bool plus = false,
  int used = 3,
  int? limit,
  int hidden = 0,
  bool reminderOn = true,
  String monthFrom = '2026-11-01',
  List<Map<String, dynamic>> festivals = const [festivalJson],
}) =>
    {
      'entries': entries,
      'festivals': festivals,
      'meters': [
        {'key': 'CalendarEntries', 'used': used, 'limit': limit ?? (plus ? 50 : 4)},
      ],
      'window': {
        'upcomingTo': plus ? '2027-05-21' : '2026-12-06',
        'monthFrom': monthFrom,
        'monthTo': plus ? '2027-05-01' : monthFrom,
        'manualFrom': '2026-11-14',
        'manualTo': plus ? '2027-05-23' : '2026-12-06',
        'locked': !plus,
      },
      'hiddenCount': hidden,
      'reminder': {'allowed': plus, 'on': plus && reminderOn},
      'summaryAllowed': plus,
      'paymentEnabled': true,
      'today': '2026-11-21',
    };

const summaryJson = {'month': '2026-11', 'booked': 17100, 'received': 11100, 'toCollect': 6000, 'top': []};

class CalFake {
  CalFake({
    this.months = const {},
    this.upcoming = const {},
    this.past = const {},
    this.entries = const {},
    this.summary = summaryJson,
    this.offline = false,
    this.writeOffline = false,
    this.writeRefusal,
    this.hang = false,
  });

  Map<String, Map<String, dynamic>> months;
  Map<String?, Map<String, dynamic>> upcoming;
  Map<String?, Map<String, dynamic>> past;
  Map<String, Map<String, dynamic>> entries;
  Map<String, dynamic> summary;
  bool offline;
  bool writeOffline;
  Map<String, dynamic>? writeRefusal;
  bool hang;
  final List<Map<String, dynamic>?> bodies = [];
  late final FakeTransport transport = FakeTransport(_handle);

  List<String> get calls => transport.calls;
  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;

  static DioException _offline(String path) => DioException(requestOptions: RequestOptions(path: path), type: DioExceptionType.connectionError);

  Future<Map<String, dynamic>> _handle(String method, String path, Map<String, dynamic>? body) async {
    bodies.add(body);
    if (hang) return Completer<Map<String, dynamic>>().future;
    if (offline && method == 'GET') throw _offline(path);
    final p = path.replaceFirst(CalendarApi.taxiPrefix, '');
    if (method == 'GET') {
      if (p.isEmpty) {
        final from = '${body?['from'] ?? ''}';
        final key = from.length >= 7 ? from.substring(0, 7) : from;
        final m = months[key];
        if (m == null) throw _offline(path);
        return {'data': m};
      }
      if (p == '/summary') return {'data': summary};
      if (p == '/upcoming') return {'data': upcoming[body?['cursor']] ?? const {'items': []}};
      if (p == '/past') return {'data': past[body?['cursor']] ?? const {'items': []}};
      if (p.startsWith('/entries/')) {
        final e = entries[p.substring('/entries/'.length)];
        if (e == null) {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(requestOptions: RequestOptions(path: path), statusCode: 404, data: {'error': {'type': 'NotFound'}}),
            type: DioExceptionType.badResponse,
          );
        }
        return {'data': e};
      }
    }
    if (writeOffline) throw _offline(path);
    final refusal = writeRefusal;
    if (refusal != null) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(requestOptions: RequestOptions(path: path), statusCode: refusal['status'] as int, data: refusal['body']),
        type: DioExceptionType.badResponse,
      );
    }
    if (method == 'DELETE') return const {'data': null};
    if (p == '/reminder') return {'data': {'allowed': true, 'on': body?['on'] == true}};
    return {
      'data': {
        'entry': body == null ? null : {...body, 'kind': 'Manual'},
        'meters': const [],
        'overlap': const {'bookings': 0, 'blocked': 0},
      },
    };
  }
}

TaxiCalendarController calSetUp(CalFake fake, {MyPlanModel plan = OwnerPlans.free}) {
  Get.reset();
  Get.testMode = true;
  OwnerCache.clearAll();
  PlanGate.debugPlan = plan;
  TaxiDriverDeps.debugReset();
  TaxiCalendarController.resetUsers();
  OwnerApi.transport = fake.transport;
  return Get.put(
    TaxiCalendarController(clock: () => calToday, userIdOf: () => 'user-a'),
    tag: TaxiCalendarController.tag,
  );
}

void calTearDown() {
  PlanGate.debugPlan = null;
  TaxiDriverDeps.debugReset();
  TaxiCalendarController.resetUsers();
  resetOwnerTestState();
}
