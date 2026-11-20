import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/features/buddy/expenses/data/expenses_api.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_models.dart';
import 'package:bakhli/features/buddy/ledger/data/ledger_api.dart';
import 'package:bakhli/features/buddy/ledger/models/ledger_models.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/viewer/data/trip_viewer_api.dart';
import 'package:bakhli/features/buddy/viewer/data/viewer_trip_cache.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:bakhli/features/buddy/viewer/viewer_deps.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const samples = r'F:\Dhasu\Buddy_resume\contract_samples';
const tripId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const memberId = 'a1a1a1a1-0000-4000-8000-000000000002';
const rahul = '11111111-1111-4111-8111-111111111111';
const aman = '22222222-2222-4222-8222-222222222222';
const priya = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> sample(String name) => jsonDecode(File('$samples\\$name.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _day2() => {
      'day': 2,
      'leg': 1,
      'restDay': false,
      'date': '2026-05-17',
      'totalMinutes': 460,
      'placeCount': 4,
      'routeGeoJson': null,
      'spots': [
        {'id': 'sp-5', 'name': 'Bhimtal Lake', 'category': 'lake', 'latitude': 29.35, 'longitude': 79.55, 'visitMinutes': 120, 'startTime': '08:30', 'travelMinutesToNext': 35},
        {'id': 'sp-6', 'name': 'Sattal', 'category': 'park', 'latitude': 29.34, 'longitude': 79.53, 'visitMinutes': 150, 'startTime': '11:30', 'travelMinutesToNext': 40},
        {'id': 'sp-7', 'name': 'Kainchi Dham', 'category': 'temple', 'latitude': 29.42, 'longitude': 79.52, 'visitMinutes': 90, 'startTime': '15:00', 'travelMinutesToNext': null},
      ],
    };

Map<String, dynamic> s14Json({String role = 'Viewer', bool withDay2 = true}) {
  final j = sample('s14_view');
  j['role'] = role;
  if (withDay2) (j['days'] as List).add(_day2());
  return j;
}

ViewerTrip s14({String role = 'Viewer'}) => ViewerTrip.fromJson(s14Json(role: role));

ViewerTrip s14Empty() => ViewerTrip.fromJson(sample('s14_view_empty'));

SharedTrips sharedTrips({bool items = false, bool invites = false, bool former = false, int past = 0}) => SharedTrips(
      items: items ? [SharedTripCard.fromJson((sample('s15_shared')['items'] as List).first as Map<String, dynamic>)] : const [],
      invites: invites
          ? [
              SharedInvite(
                memberId: memberId,
                title: 'Uttarakhand Hills Trip',
                ownerName: 'Rahul',
                startDate: DateTime(2026, 5, 16),
                endDate: DateTime(2026, 5, 22),
                dayCount: 7,
                cityCount: 3,
              ),
            ]
          : const [],
      former: former
          ? [
              FormerTripCard(
                tripId: tripId,
                title: 'Uttarakhand Hills Trip',
                ownerName: 'Rahul',
                startDate: DateTime(2026, 5, 16),
                endDate: DateTime(2026, 5, 22),
                endedHow: 'Left',
                myNet: -11816,
                owesToName: 'Rahul',
                sharedCount: 6,
              ),
            ]
          : const [],
      counts: SharedTripCounts(upcoming: items ? 1 : 0, past: past),
    );

TripMembers viewerMembers() => TripMembers.fromJson(sample('s1_members_viewer'));

ExpenseList formerList() => ExpenseList.fromJson(sample('e1_expenses_former'));

TripBalances formerBalances() {
  final j = sample('e8_balances_viewer');
  j['role'] = 'Former';
  final people = (j['people'] as List).cast<Map<String, dynamic>>();
  for (final p in people) {
    final person = p['person'] as Map<String, dynamic>;
    if (person['isMe'] == true) person['status'] = 'Left';
  }
  return TripBalances.fromJson(j);
}

ExpenseSummary summaryDay1() {
  final j = sample('e17_summary');
  j['byDay'] = [
    {'day': 1, 'date': '2026-05-16', 'total': 9000},
  ];
  return ExpenseSummary.fromJson(j);
}

class FakeViewerApi extends TripViewerApi {
  FakeViewerApi({this.preview, this.accept, this.decline, this.leaveResult, this.sharedResult, this.pastResult});

  BuddyResult<InvitePreview>? preview;
  BuddyResult<String>? accept;
  BuddyResult<void>? decline;
  BuddyResult<LeaveResult>? leaveResult;
  final List<BuddyResult<ViewerTripResponse>> views = [];
  BuddyResult<SharedTrips>? sharedResult;
  BuddyResult<SharedTrips>? pastResult;
  final List<String?> etags = [];
  final List<String?> sharedCursors = [];
  int acceptCalls = 0;
  int declineCalls = 0;
  int leaveCalls = 0;
  int sharedCalls = 0;

  void queueViews(List<BuddyResult<ViewerTripResponse>> v) => views.addAll(v);

  @override
  Future<BuddyResult<InvitePreview>> invitePreview(String memberId) async => preview ?? BuddyOffline<InvitePreview>();

  @override
  Future<BuddyResult<String>> acceptInvite(String memberId) async {
    acceptCalls++;
    return accept ?? const BuddyOk(tripId);
  }

  @override
  Future<BuddyResult<void>> declineInvite(String memberId) async {
    declineCalls++;
    return decline ?? const BuddyOk<void>(null);
  }

  @override
  Future<BuddyResult<LeaveResult>> leave(String tripId) async {
    leaveCalls++;
    return leaveResult ?? const BuddyOk(LeaveResult(status: 'Left', hasShare: true));
  }

  @override
  Future<BuddyResult<ViewerTripResponse>> view(String tripId, {String? etag}) async {
    etags.add(etag);
    if (views.isEmpty) return BuddyOffline<ViewerTripResponse>();
    return views.length == 1 ? views.first : views.removeAt(0);
  }

  @override
  Future<BuddyResult<SharedTrips>> shared({String state = 'upcoming', String? cursor}) async {
    sharedCalls++;
    sharedCursors.add(cursor);
    if (state == 'past') return pastResult ?? BuddyOk(sharedTrips());
    return sharedResult ?? BuddyOk(sharedTrips());
  }
}

class FakeViewerLedger extends LedgerApi {
  FakeViewerLedger({this.balancesResult, this.summaryResult});

  BuddyResult<TripBalances>? balancesResult;
  BuddyResult<ExpenseSummary>? summaryResult;
  final List<(String, int)> saidPaidCalls = [];
  final List<String> withdrawCalls = [];
  int summaryCalls = 0;

  @override
  Future<BuddyResult<TripBalances>> balances(String tripId) async => balancesResult ?? BuddyOffline<TripBalances>();

  @override
  Future<BuddyResult<ExpenseSummary>> summary(String tripId) async {
    summaryCalls++;
    return summaryResult ?? BuddyOffline<ExpenseSummary>();
  }

  @override
  Future<BuddyResult<PaymentWriteResponse>> saidPaid(String tripId, {required String opId, required String toUserId, required int amount}) async {
    saidPaidCalls.add((toUserId, amount));
    return const BuddyOk(PaymentWriteResponse(balancesVersion: 8));
  }

  @override
  Future<BuddyResult<PaymentWriteResponse>> withdraw(String tripId, String paymentId) async {
    withdrawCalls.add(paymentId);
    return const BuddyOk(PaymentWriteResponse(balancesVersion: 9));
  }
}

class FakeViewerExpenses extends ExpensesApi {
  FakeViewerExpenses(this.result);

  BuddyResult<ExpenseList> result;

  @override
  Future<BuddyResult<ExpenseList>> list(String tripId, {String? cursor, int limit = 100}) async => result;
}

class FakeMyTrips extends MyTripsController {
  @override
  Future<void> load() async {
    active.assignAll([
      TripSummaryModel.fromJson({
        'id': 'cccccccc-0000-4000-8000-000000000001',
        'title': 'Rajasthan Forts Trip',
        'status': 'Draft',
        'dayCount': 4,
        'spotCount': 8,
        'legCount': 2,
        'legCities': ['Jaipur', 'Udaipur'],
        'updatedAt': '2026-05-01T00:00:00Z',
      }),
    ]);
  }

  @override
  Future<void> loadPast() async {}
}

final List<(String, Object?)> opened = [];
int toMyTripsCalls = 0;

GetPage<dynamic> _stub(String name) => GetPage(
      name: name,
      page: () {
        opened.add((name, Get.arguments));
        return Scaffold(body: Text('page $name'));
      },
    );

List<GetPage<dynamic>> stubPages() => [
      for (final r in [
        AppRoutes.tripView,
        AppRoutes.tripDayPlan,
        AppRoutes.tripDayMap,
        AppRoutes.tripMyShare,
        AppRoutes.tripExpenses,
        AppRoutes.tripTravellers,
        AppRoutes.tripInvite,
        AppRoutes.tripOverview,
        AppRoutes.tripSettle,
        AppRoutes.tripMoneySummary,
      ])
        _stub(r),
    ];

Widget app(Widget home) => GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      getPages: stubPages(),
      builder: (context, c) => Stack(fit: StackFit.expand, children: [Positioned.fill(child: c!), Overlay(key: AppToast.overlayKey)]),
      home: home,
    );

MemoryViewerCacheStore useMemoryCache() {
  final s = MemoryViewerCacheStore();
  ViewerTripCache.store = s;
  return s;
}

void registerViewerFakes({FakeViewerApi? api, FakeViewerLedger? ledger, FakeViewerExpenses? expenses}) {
  if (api != null) Get.put<TripViewerApi>(api);
  if (ledger != null) Get.put<LedgerApi>(ledger);
  if (expenses != null) Get.put<ExpensesApi>(expenses);
  ViewerDeps.toMyTrips = () => toMyTripsCalls++;
}

BuddyResult<ViewerTripResponse> viewOk(ViewerTrip t, {String etag = '"v1"'}) => BuddyOk(ViewerTripResponse(notModified: false, etag: etag, trip: t));

BuddyResult<ViewerTripResponse> notModified({String etag = '"v1"'}) => BuddyOk(ViewerTripResponse(notModified: true, etag: etag));

BuddyResult<ViewerTripResponse> notOnTrip({bool hasShare = true}) => BuddyRefused(
      type: 'NotOnTrip',
      statusCode: 403,
      data: {
        'hasShare': hasShare,
        'title': 'Uttarakhand Hills Trip',
        'ownerName': 'Rahul',
        'startDate': '2026-05-16',
        'endDate': '2026-05-22',
        'endedHow': 'Removed',
      },
    );

BuddyResult<ViewerTripResponse> tripGone() => const BuddyRefused(type: 'TripNotFound', statusCode: 404);

ViewerTrip s14NotBooked() {
  final j = s14Json();
  j['startDate'] = null;
  j['endDate'] = null;
  for (final d in (j['days'] as List).cast<Map<String, dynamic>>()) {
    d['date'] = null;
  }
  j['stay'] = {'state': 'NotAdded', 'items': <Object>[]};
  j['taxi'] = {'state': 'NotAdded'};
  j['expenses'] = {'hasExpenses': false, 'spent': 0, 'myShare': 0, 'openPayments': 0, 'settled': true};
  j['progressPercent'] = 33;
  return ViewerTrip.fromJson(j);
}
