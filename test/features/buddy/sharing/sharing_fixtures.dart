import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/features/buddy/buddies/data/buddies_api.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/ledger/data/ledger_api.dart';
import 'package:bakhli/features/buddy/ledger/models/ledger_models.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/sharing/data/trip_members_api.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/sharing/widgets/owner_overview_seam.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:bakhli/features/trip/utils/trip_parts.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const samples = r'F:\Dhasu\Buddy_resume\contract_samples';
const tripId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const rahul = '11111111-1111-4111-8111-111111111111';
const aman = '22222222-2222-4222-8222-222222222222';
const priya = '33333333-3333-4333-8333-333333333333';
const neha = '44444444-4444-4444-8444-444444444444';
const vikram = '55555555-5555-4555-8555-555555555555';
const karan = '66666666-6666-4666-8666-666666666666';

Map<String, dynamic> sample(String name) => jsonDecode(File('$samples\\$name.json').readAsStringSync()) as Map<String, dynamic>;

TripModel trip({TripSharingBlock? sharing, int spotCount = 18, DateTime? endDate, bool booked = true}) => TripModel(
      id: tripId,
      title: 'Uttarakhand Hills Trip',
      nameChosen: true,
      status: TripStatuses.planned,
      cityKey: 1,
      cityName: 'Dehradun',
      cityLatitude: 30.3,
      cityLongitude: 78.0,
      dayCount: 7,
      spotCount: spotCount,
      legCount: 3,
      legCities: const ['Dehradun', 'Mussoorie', 'Rishikesh'],
      endDate: endDate,
      taxiRequest: booked ? const TripTaxiRequestRef(requestId: 'r1', state: 'Booked', view: 'Booked') : null,
      plan: TripPlan.singleCity(cityKey: 1, cityName: 'Dehradun', settings: const TripSettings(adults: 1), days: [TripDay(day: 1, spots: const [])]),
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      raw: sharing == null ? null : {'sharing': sharing.toJson()},
      sharing: sharing,
    );

const allArranged = TripParts(itinerary: TripPartState.arranged, taxi: TripPartState.arranged, stay: TripPartState.arranged);

TripSharingBlock aloneBlock() => const TripSharingBlock(
      travellerCount: 1,
      viewerCount: 0,
      pendingInvites: 0,
      firstTravellers: [TravellerDot(userId: rahul, initial: 'R', name: 'Rahul')],
      expenses: TripExpenseCard.none,
    );

TripSharingBlock sharedBlock({int pending = 1, TripExpenseCard? expenses}) => TripSharingBlock(
      travellerCount: 3,
      viewerCount: 2,
      pendingInvites: pending,
      firstTravellers: const [
        TravellerDot(userId: rahul, initial: 'R', name: 'Rahul'),
        TravellerDot(userId: aman, initial: 'A', name: 'Aman'),
        TravellerDot(userId: priya, initial: 'P', name: 'Priya'),
      ],
      expenses: expenses ?? const TripExpenseCard(hasExpenses: true, spent: 32300, myShare: 11618, dayToday: 4, openPayments: 2, settled: false),
    );

Widget overview(TripModel t, TripSharingBlock? s, {TripParts parts = allArranged}) => Builder(
      builder: (context) {
        final x = s == null ? OwnerOverviewExtras.none : OwnerOverviewSeam.build(context, t, s, progressPercent: parts.percent);
        return TripOverviewScreen(
          trip: t,
          parts: parts,
          stay: TripOverviewStay.booked,
          onViewPlan: () {},
          onTaxi: (_) {},
          onDone: () {},
          onBack: () {},
          onStay: (_) {},
          subtitle: x.subtitle,
          travellerCount: x.travellerCount,
          extraCards: x.extraCards,
          extraMenuItems: x.extraMenuItems,
          progressLine: x.progressLine,
          showProgress: x.showProgress,
        );
      },
    );

TripMembers membersSample() => TripMembers.fromJson(sample('s1_members_owner'));

JoinedMember joined(String id, String name, String username, {String role = 'Viewer', bool me = false, DateTime? at}) => JoinedMember(
      userId: id,
      name: name,
      username: username,
      initial: name.substring(0, 1),
      last4: username.substring(username.length - 4),
      role: role,
      isMe: me,
      joinedAt: at,
    );

final _rahulOwner = joined(rahul, 'Rahul', 'Bakhli#48291736', role: 'Owner', me: true);

TripMembers fullMembers() {
  final rows = <(String, String, int)>[
    ('Aman', 'Bakhli#61408275', 16),
    ('Priya', 'Bakhli#50267139', 18),
    ('Rahul', 'Bakhli#30419736', 18),
    ('Karan', 'Bakhli#88120453', 19),
    ('Sana', 'Bakhli#27760314', 19),
    ('Meera', 'Bakhli#41093357', 20),
    ('Arjun', 'Bakhli#90234418', 20),
    ('Tara', 'Bakhli#56610902', 21),
    ('Imran', 'Bakhli#33872015', 21),
    ('Zoya', 'Bakhli#72408861', 21),
  ];
  return TripMembers(
    tripId: tripId,
    title: 'Uttarakhand Hills Trip',
    role: 'Owner',
    ownerName: 'Rahul',
    travellerCount: 11,
    maxTravellers: 12,
    pendingInvites: 1,
    seatsLeft: 0,
    joined: [
      _rahulOwner,
      for (var i = 0; i < rows.length; i++)
        joined(i == 0 ? aman : (i == 1 ? priya : 'u$i-0000'), rows[i].$1, rows[i].$2, at: DateTime(2026, 5, rows[i].$3, 12)),
    ],
    invited: [membersSample().invited.first],
    canInvite: false,
    canLeave: false,
  );
}

TripMembers tenMembers() => TripMembers(
      tripId: tripId,
      title: 'Uttarakhand Hills Trip',
      role: 'Owner',
      ownerName: 'Rahul',
      travellerCount: 10,
      maxTravellers: 12,
      pendingInvites: 0,
      seatsLeft: 2,
      joined: [_rahulOwner, joined(aman, 'Aman', 'Bakhli#61408275', at: DateTime(2026, 5, 16, 12)), joined(priya, 'Priya', 'Bakhli#50267139', at: DateTime(2026, 5, 18, 12))],
      invited: const [],
      canInvite: true,
      canLeave: false,
    );

BuddyItem buddy(String id, String name, String username, {String state = 'None'}) =>
    BuddyItem(userId: id, name: name, username: username, initial: name.substring(0, 1), isNew: false, tripState: state);

BuddyList buddyList(List<BuddyItem> items, {String? next}) => BuddyList(items: items, count: items.length, nextCursor: next);

class FakeMembersApi extends TripMembersApi {
  FakeMembersApi({required this.membersResult});

  BuddyResult<TripMembers> membersResult;
  BuddyResult<InviteResult>? inviteResult;
  BuddyResult<void> cancelResult = const BuddyOk<void>(null);
  BuddyResult<RemoveResult> removeResult = const BuddyOk(RemoveResult(status: 'Removed', sharesExpenses: 6));
  BuddyResult<int> countResult = const BuddyOk(6);
  BuddyResult<void> deleteResult = const BuddyOk<void>(null);
  final List<List<String>> invites = [];
  final List<String> requestIds = [];
  final List<String> cancels = [];
  final List<String> removes = [];
  int deletes = 0;
  int memberCalls = 0;

  @override
  Future<BuddyResult<TripMembers>> members(String tripId) async {
    memberCalls++;
    return membersResult;
  }

  @override
  Future<BuddyResult<InviteResult>> invite(String tripId, List<String> userIds, {required String clientRequestId}) async {
    invites.add(userIds);
    requestIds.add(clientRequestId);
    return inviteResult ?? BuddyOk(InviteResult(results: [for (final u in userIds) InviteOutcome(userId: u, outcome: 'Invited')], seatsLeft: 0));
  }

  @override
  Future<BuddyResult<void>> cancelInvite(String tripId, String userId) async {
    cancels.add(userId);
    return cancelResult;
  }

  @override
  Future<BuddyResult<RemoveResult>> remove(String tripId, String userId) async {
    removes.add(userId);
    return removeResult;
  }

  @override
  Future<BuddyResult<int>> expenseCount(String tripId, String userId) async => countResult;

  @override
  Future<BuddyResult<void>> deleteTrip(String tripId) async {
    deletes++;
    return deleteResult;
  }
}

class FakeBuddiesApi extends BuddiesApi {
  FakeBuddiesApi(this.pages);

  final Map<String?, BuddyResult<BuddyList>> pages;
  final List<String?> cursors = [];

  @override
  Future<BuddyResult<BuddyList>> buddies({String? cursor, int limit = 50, String? forTripId}) async {
    cursors.add(cursor);
    return pages[cursor] ?? BuddyOk(buddyList(const []));
  }
}

class FakeLedgerApi extends LedgerApi {
  FakeLedgerApi(this.result);

  BuddyResult<TripBalances> result;

  @override
  Future<BuddyResult<TripBalances>> balances(String tripId) async => result;
}

TripBalances balancesSample() => TripBalances.fromJson(sample('e8_balances_owner'));

final List<(String, Object?)> opened = [];

GetPage _stub(String name) => GetPage(
      name: name,
      page: () {
        opened.add((name, Get.arguments));
        return Scaffold(body: Text('page $name'));
      },
    );

Widget app(Widget home) => GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      getPages: [
        for (final r in [AppRoutes.tripTravellers, AppRoutes.tripExpenses, AppRoutes.tripSettle, AppRoutes.tripMoneySummary, AppRoutes.buddies, AppRoutes.people, AppRoutes.myTrips])
          _stub(r),
      ],
      builder: (context, c) => Stack(fit: StackFit.expand, children: [Positioned.fill(child: c!), Overlay(key: AppToast.overlayKey)]),
      home: home,
    );

void registerFakes({FakeMembersApi? members, FakeBuddiesApi? buddies, FakeLedgerApi? ledger}) {
  if (members != null) Get.put<TripMembersApi>(members);
  if (buddies != null) Get.put<BuddiesApi>(buddies);
  if (ledger != null) Get.put<LedgerApi>(ledger);
}
