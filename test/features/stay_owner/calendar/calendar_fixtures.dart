import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_controller.dart';
import 'package:bakhli/features/stay_owner/special_prices/stay_special_prices_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';
import '../core/stay_fixtures.dart';

final DateTime calToday = DateTime(2026, 11, 21);
DateTime calClock() => calToday;

Map<String, dynamic> entryJson(
  String id,
  String from,
  String to,
  String label, {
  bool auto = false,
  String? detail,
  String? roomNames,
  int? guests,
  int? finalAmount,
  int? received,
  bool paid = false,
  bool cancelled = false,
  String? note,
  int? listed,
  String? cancelledBy,
  String? cancelledOn,
}) {
  final rec = paid ? (finalAmount ?? 0) : (received ?? 0);
  final balance = finalAmount == null ? null : (finalAmount - rec < 0 ? 0 : finalAmount - rec);
  final chip = balance != null ? (balance > 0 ? 'ToCollect' : 'PaidInFull') : (rec > 0 ? 'Received' : 'None');
  final chipAmount = switch (chip) {
    'ToCollect' => balance,
    'PaidInFull' => finalAmount,
    'Received' => rec,
    _ => 0,
  };
  return {
    'id': id,
    'kind': auto ? 'Auto' : 'Manual',
    'sourceType': auto ? 'TripEnquiry' : null,
    'sourceId': auto ? 'q-$id' : null,
    'sourceAvailable': auto ? true : null,
    'dateFrom': from,
    'dateTo': to,
    'label': label,
    'detail': detail,
    'roomNames': roomNames,
    'guests': guests,
    'note': note,
    'listedTotal': listed,
    'finalAmount': finalAmount,
    'advanceReceived': paid ? null : received,
    'paidInFull': paid,
    'received': rec,
    'balance': balance,
    'chip': cancelled && rec > 0 ? 'Received' : chip,
    'chipAmount': cancelled && rec > 0 ? rec : chipAmount,
    'cancelled': cancelled,
    'cancelledBy': cancelledBy,
    'cancelledOn': cancelledOn,
    'version': 1,
  };
}

List<Map<String, dynamic>> novEntries() => [
      entryJson('sanjay', '2026-11-09', '2026-11-10', 'Sanjay Rao', auto: true, roomNames: 'Family Room', finalAmount: 3600, paid: true),
      entryJson('walkin', '2026-11-17', '2026-11-18', 'Walk-in couple', finalAmount: 2400, paid: true),
      entryJson('neha', '2026-11-22', '2026-11-23', 'Neha Joshi',
          auto: true, roomNames: 'Family Room', guests: 2, listed: 4500, finalAmount: 4500, received: 1000, detail: 'Family Room · 2 guests'),
      entryJson('kapoor', '2026-11-24', '2026-11-25', 'Kapoor couple', finalAmount: 2800, paid: true),
      entryJson('gupta', '2026-11-25', '2026-11-27', 'Gupta ji, 2 rooms', finalAmount: 9000, received: 3000, note: 'Family room + deluxe, 4 guests'),
      entryJson('rohit', '2026-11-27', '2026-11-29', 'Rohit Verma', auto: true, roomNames: 'Deluxe Room', finalAmount: 7200, received: 2000),
    ];

Map<String, dynamic> meter(String key, int used, int limit) => {'key': key, 'used': used, 'limit': limit};

Map<String, dynamic> monthJson({
  bool plus = false,
  String month = '2026-11',
  List<Map<String, dynamic>>? entries,
  List<Map<String, dynamic>>? blocks,
  List<Map<String, dynamic>>? specialPrices,
  int hiddenCount = 0,
  int entriesUsed = 3,
  int blocksUsed = 1,
  bool paymentEnabled = true,
}) =>
    {
      'entries': entries ?? novEntries(),
      'blocks': blocks ?? [{'id': 'b1', 'dateFrom': '2026-11-30', 'dateTo': '2026-11-30', 'reason': 'Water tank repair', 'version': 1}],
      'specialPrices': specialPrices ??
          [
            {'id': 'sp1', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'nights': 7, 'direction': 'Higher', 'percent': 20, 'label': 'Diwali week', 'live': true, 'version': 1},
          ],
      'festivals': [
        {'id': 'f1', 'name': 'Diwali', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'},
      ],
      'meters': plus ? [meter('CalendarEntries', 12, 50), meter('BlockedRanges', 2, 10)] : [meter('CalendarEntries', entriesUsed, 4), meter('BlockedRanges', blocksUsed, 1)],
      'window': plus
          ? {'upcomingTo': '2027-05-23', 'monthFrom': '2026-11-01', 'monthTo': '2027-05-01', 'manualFrom': '2026-11-14', 'manualTo': '2027-05-23', 'locked': false}
          : {'upcomingTo': '2026-12-06', 'monthFrom': '2026-11-01', 'monthTo': '2026-11-30', 'manualFrom': '2026-11-14', 'manualTo': '2026-12-06', 'locked': true},
      'hiddenCount': hiddenCount,
      'reminder': {'allowed': plus, 'on': false},
      'summaryAllowed': plus,
      'paymentEnabled': paymentEnabled,
      'today': '2026-11-21',
    };

Map<String, dynamic> decMonthJson() => monthJson(
      plus: true,
      month: '2026-12',
      entries: [
        entryJson('office', '2026-12-04', '2026-12-05', 'Office group, 6 people', finalAmount: 6000),
        entryJson('ankit', '2026-12-12', '2026-12-14', 'Ankit Joshi', auto: true, roomNames: 'Family Room', finalAmount: 9000),
        entryJson('arora', '2026-12-24', '2026-12-27', 'Arora family', auto: true, roomNames: 'Whole stay', finalAmount: 18000, received: 8000),
        entryJson('mehra', '2026-12-28', '2026-12-31', 'Mehra group', finalAmount: 8200, received: 2600),
      ],
      blocks: [{'id': 'b2', 'dateFrom': '2026-12-18', 'dateTo': '2026-12-20', 'reason': 'Family visit', 'version': 1}],
      specialPrices: [
        {'id': 'sp2', 'dateFrom': '2026-12-24', 'dateTo': '2027-01-01', 'nights': 9, 'direction': 'Higher', 'percent': 25, 'label': 'Christmas and New Year', 'live': true, 'version': 1},
      ],
    );

Map<String, dynamic> summaryJson({int booked = 29500, int received = 14800, int toCollect = 14700, bool top = true, int? dueCount}) => {
      'month': '2026-11',
      'finalTotal': booked,
      'receivedTotal': received,
      'balanceTotal': toCollect,
      'entryCount': 6,
      'dueCount': dueCount ?? (top ? 3 : 0),
      'paymentEnabled': true,
      'topBalances': top
          ? [
              entryJson('gupta', '2026-11-25', '2026-11-27', 'Gupta ji, 2 rooms', finalAmount: 9000, received: 3000),
              entryJson('rohit', '2026-11-27', '2026-11-29', 'Rohit Verma', auto: true, finalAmount: 7200, received: 2000),
              entryJson('neha', '2026-11-22', '2026-11-23', 'Neha Joshi', auto: true, finalAmount: 4500, received: 1000),
            ]
          : const [],
    };

Map<String, dynamic> specialJson({bool plus = false, List<Map<String, dynamic>>? items, int savesLeft = 3}) => {
      'items': items ??
          [
            {'id': 'sp1', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'nights': 7, 'direction': 'Higher', 'percent': 20, 'label': 'Diwali week', 'live': true, 'version': 1},
          ],
      'meters': [meter('SpecialPrices', items?.length ?? 1, plus ? 5 : 1)],
      'savesLeftToday': savesLeft,
      'rooms': [
        {'id': 'r1', 'roomName': 'Deluxe Room', 'basePrice': 3000},
        {'id': 'r2', 'roomName': 'Family Room', 'basePrice': 4500},
      ],
      'paymentEnabled': true,
    };

List<Map<String, dynamic>> plusRules() => [
      {'id': 'sp1', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'nights': 7, 'direction': 'Higher', 'percent': 20, 'label': 'Diwali week', 'live': true, 'version': 1},
      {'id': 'sp2', 'dateFrom': '2026-12-24', 'dateTo': '2027-01-01', 'nights': 9, 'direction': 'Higher', 'percent': 25, 'label': 'Christmas and New Year', 'live': true, 'version': 1},
      {'id': 'sp3', 'dateFrom': '2027-01-25', 'dateTo': '2027-01-27', 'nights': 3, 'direction': 'Higher', 'percent': 10, 'isPaused': true, 'version': 1},
      {'id': 'sp4', 'dateFrom': '2027-02-08', 'dateTo': '2027-02-18', 'nights': 11, 'direction': 'Lower', 'percent': 15, 'live': true, 'version': 1},
    ];

Map<String, dynamic> festivalsJson() => {
      'items': [
        {'id': 'f1', 'name': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'},
        {'id': 'f2', 'name': 'Christmas and New Year', 'dateFrom': '2026-12-24', 'dateTo': '2027-01-01'},
      ],
    };

typedef CalHandler = Future<Map<String, dynamic>> Function(String method, String path, Map<String, dynamic>? body);

DioException refusal(int status, String type, {Map<String, dynamic> data = const {}, String? message}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: {
          'error': {'type': type, 'message': message ?? type},
          'data': data,
        },
      ),
      type: DioExceptionType.badResponse,
    );

DioException offline() => DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);

class CalendarHarness {
  CalendarHarness(this.transport);

  final FakeTransport transport;
  late StayCalendarController calendar;
  StaySpecialPricesController? prices;

  static CalendarHarness setUp({
    MyPlanModel plan = OwnerPlans.free,
    Map<String, dynamic>? month,
    Map<String, dynamic>? december,
    Map<String, dynamic>? special,
    Map<String, dynamic>? Function(String path)? extra,
    CalHandler? override,
    bool registerCalendar = true,
  }) {
    StayHarness.setUp(homeJson());
    PlanGate.debugPlan = plan;
    final m = month ?? monthJson();
    late FakeTransport t;
    t = FakeTransport((method, path, body) async {
      final o = override;
      if (o != null) {
        final r = await o(method, path, body);
        if (r.isNotEmpty) return r;
      }
      final x = extra?.call(path);
      if (x != null) return {'data': x};
      if (method == 'GET' && path == '/stays/me/calendar') {
        final from = body?['from'];
        if (from is String && from.startsWith('2026-12') && december != null) return {'data': december};
        return {'data': m};
      }
      if (path == '/stays/me/calendar/summary') return {'data': summaryJson()};
      if (path == '/stays/me/special-prices') return {'data': special ?? specialJson()};
      if (path == '/festivals') return {'data': festivalsJson()};
      if (path == '/stays/me/blocked-ranges' && method == 'GET') {
        return {
          'data': {'items': m['blocks'], 'meters': [meter('BlockedRanges', 1, 1)]},
        };
      }
      return {'data': <String, dynamic>{}};
    });
    OwnerApi.transport = t;
    final h = CalendarHarness(t);
    if (registerCalendar) {
      h.calendar = Get.put(
        StayCalendarController(clock: calClock, userIdOf: () => 'user-a', listingNameOf: () => 'Deodar Heights'),
        tag: StayCalendarController.tag,
      );
    }
    return h;
  }
}
