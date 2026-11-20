import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/features/buddy/ledger/data/ledger_api.dart';
import 'package:bakhli/features/buddy/ledger/models/ledger_models.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const samples = r'F:\Dhasu\Buddy_resume\contract_samples';
const tripId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const rahul = '11111111-1111-4111-8111-111111111111';
const aman = '22222222-2222-4222-8222-222222222222';
const priya = '33333333-3333-4333-8333-333333333333';
const aman2 = '44444444-4444-4444-8444-444444444444';
const payId = 'f0000000-0000-4000-8000-000000000001';
const payId2 = 'f0000000-0000-4000-8000-000000000002';

Map<String, dynamic> sample(String name) => jsonDecode(File('$samples\\$name.json').readAsStringSync()) as Map<String, dynamic>;

const Map<String, (String, String, String)> _who = {
  rahul: ('Rahul', '1736', 'R'),
  aman: ('Aman', '8275', 'A'),
  priya: ('Priya', '7139', 'P'),
  aman2: ('Aman', '4419', 'A'),
};

Map<String, dynamic> person(String id, String me) => {
      'userId': id,
      'name': _who[id]!.$1,
      'last4': _who[id]!.$2,
      'initial': _who[id]!.$3,
      'isMe': id == me,
      'status': id == rahul ? 'Owner' : 'Joined',
    };

Map<String, dynamic> balanceOf(String id, String me, int paid, int share) => {'person': person(id, me), 'paid': paid, 'share': share, 'net': paid - share};

Map<String, dynamic> pay(
  String from,
  String to,
  int amount, {
  String state = 'Open',
  String? id,
  String? saidPaidAt,
  String? receivedAt,
  String? receivedBy,
  String? afterNotReceivedAt,
  bool afterEdit = false,
  bool canSayPaid = false,
  bool canWithdraw = false,
  bool canMarkReceived = false,
  bool canMarkNotReceived = false,
  bool canRemind = false,
  bool reminderSentToday = false,
}) =>
    {
      'paymentId': id ?? (state == 'Open' ? null : payId),
      'fromUserId': from,
      'toUserId': to,
      'amount': amount,
      'state': state,
      'saidPaidAt': saidPaidAt,
      'receivedAt': receivedAt,
      'receivedByUserId': receivedBy,
      'afterNotReceivedAt': afterNotReceivedAt,
      'afterEdit': afterEdit,
      'canSayPaid': canSayPaid,
      'canWithdraw': canWithdraw,
      'canMarkReceived': canMarkReceived,
      'canMarkNotReceived': canMarkNotReceived,
      'canRemind': canRemind,
      'reminderSentToday': reminderSentToday,
    };

TripBalances balances({
  required String me,
  required List<Map<String, dynamic>> people,
  required List<Map<String, dynamic>> payments,
  Map<String, dynamic>? meBlock,
  bool ended = false,
  bool frozen = false,
  int done = 0,
  int? total,
  int version = 7,
  Map<String, dynamic>? reopened,
}) {
  final mine = people.firstWhere((p) => (p['person'] as Map)['userId'] == me, orElse: () => {'paid': 0, 'share': 0, 'net': 0});
  return TripBalances.fromJson({
    'tripId': tripId,
    'tripTitle': 'Uttarakhand Hills Trip',
    'ownerName': 'Rahul',
    'role': me == rahul ? 'Owner' : 'Viewer',
    'isOwner': me == rahul,
    'tripEnded': ended,
    'frozen': frozen,
    'endDate': '2026-05-22',
    'balancesVersion': version,
    'settled': payments.every((p) => p['state'] == 'Received'),
    'paymentsDone': done,
    'paymentsTotal': total ?? payments.length,
    'reopened': reopened,
    'me': meBlock ?? {'paid': mine['paid'], 'share': mine['share'], 'net': mine['net'], 'received': 0, 'stillOpen': 0, 'saidPaidWaiting': 0},
    'people': people,
    'payments': payments,
  });
}

List<Map<String, dynamic>> people49(String me, {bool twoAmans = false, bool edited = false}) => [
      balanceOf(rahul, me, edited ? 29400 : 29800, edited ? 11418 : 11618),
      balanceOf(aman, me, 1000, edited ? 12616 : 12816),
      balanceOf(twoAmans ? aman2 : priya, me, 1500, 7866),
    ];

TripBalances owner49({bool twoAmans = false}) => balances(me: rahul, people: people49(rahul, twoAmans: twoAmans), payments: [
      pay(aman, rahul, 11816, state: 'SaidPaid', saidPaidAt: '2026-05-19T09:30:00Z', canMarkReceived: true, canMarkNotReceived: true),
      pay(twoAmans ? aman2 : priya, rahul, 6366, canRemind: true),
    ]);

TripBalances owner49b() => balances(me: rahul, people: people49(rahul, edited: true), payments: [
      pay(aman, rahul, 11616, canRemind: true),
      pay(priya, rahul, 6366, canRemind: true),
    ]);

TripBalances owner49e({bool amanSaid = true}) => balances(
      me: rahul,
      people: [balanceOf(rahul, rahul, 2000, 2500), balanceOf(aman, rahul, 2000, 2500), balanceOf(priya, rahul, 3500, 2500)],
      payments: [
        pay(rahul, priya, 500, canSayPaid: true),
        amanSaid
            ? pay(aman, priya, 500, state: 'SaidPaid', id: payId2, saidPaidAt: '2026-05-17T09:30:00Z', canMarkReceived: true, canMarkNotReceived: true)
            : pay(aman, priya, 500),
      ],
    );

TripBalances viewer410({int amount = 11816, int share = 12816, String state = 'Open', String? afterNotReceived, bool canSay = true}) => balances(
      me: aman,
      people: [balanceOf(rahul, aman, 29800, 11618), balanceOf(aman, aman, 1000, share), balanceOf(priya, aman, 1500, 7866)],
      payments: [
        pay(aman, rahul, amount,
            state: state,
            saidPaidAt: state == 'SaidPaid' ? '2026-05-19T09:30:00Z' : null,
            afterNotReceivedAt: afterNotReceived,
            canSayPaid: state == 'Open' && canSay,
            canWithdraw: state == 'SaidPaid'),
        pay(priya, rahul, 6366),
      ],
    );

TripBalances viewer410c() => balances(
      me: aman,
      people: [balanceOf(rahul, aman, 1000, 1000), balanceOf(aman, aman, 1000, 1000)],
      payments: const [],
    );

TripBalances viewer410e() => balances(
      me: priya,
      people: [balanceOf(rahul, priya, 2000, 2500), balanceOf(aman, priya, 2000, 2500), balanceOf(priya, priya, 3500, 2500)],
      payments: [
        pay(rahul, priya, 500),
        pay(aman, priya, 500, state: 'SaidPaid', saidPaidAt: '2026-05-17T09:30:00Z'),
      ],
    );

TripBalances viewerReceived() => balances(
      me: aman,
      people: [balanceOf(rahul, aman, 29800, 11618), balanceOf(aman, aman, 1000, 12816)],
      payments: [pay(aman, rahul, 11816, state: 'Received', saidPaidAt: '2026-05-19T09:30:00Z', receivedAt: '2026-05-23T07:00:00Z', receivedBy: rahul)],
    );

TripBalances owner414({bool received = true, bool allDone = false}) => balances(
      me: rahul,
      ended: true,
      done: allDone ? 2 : (received ? 1 : 0),
      total: 2,
      people: people49(rahul),
      meBlock: {'paid': 29800, 'share': 11618, 'net': 18182, 'received': allDone ? 18182 : (received ? 11816 : 0), 'stillOpen': allDone ? 0 : (received ? 6366 : 18182), 'saidPaidWaiting': 0},
      payments: [
        received
            ? pay(aman, rahul, 11816, state: 'Received', saidPaidAt: '2026-05-19T09:30:00Z', receivedAt: '2026-05-23T07:00:00Z', receivedBy: rahul)
            : pay(aman, rahul, 11816, state: 'SaidPaid', saidPaidAt: '2026-05-19T09:30:00Z', canMarkReceived: true, canMarkNotReceived: true),
        allDone
            ? pay(priya, rahul, 6366, state: 'Received', id: payId2, saidPaidAt: '2026-05-20T09:30:00Z', receivedAt: '2026-05-23T07:00:00Z', receivedBy: rahul)
            : pay(priya, rahul, 6366, canRemind: true),
      ],
    );

TripBalances owner415a() => TripBalances.fromJson(sample('e8_balances_reopened'));

TripBalances owner415b() => balances(me: rahul, ended: true, frozen: true, people: people49(rahul), payments: [
      pay(aman, rahul, 11816, state: 'SaidPaid', saidPaidAt: '2026-06-22T09:30:00Z', canMarkReceived: true, canMarkNotReceived: true),
      pay(priya, rahul, 6366, canRemind: true),
    ]);

ExpenseSummary summarySample({bool settled = true, int open = 0}) =>
    ExpenseSummary.fromJson({...sample('e17_summary'), 'settled': settled, 'openPayments': open});

class FakeLedgerApi extends LedgerApi {
  FakeLedgerApi(List<BuddyResult<TripBalances>> answers, {this.summaryResult}) : _answers = [...answers];

  final List<BuddyResult<TripBalances>> _answers;
  BuddyResult<ExpenseSummary>? summaryResult;
  int balanceCalls = 0;
  int summaryCalls = 0;
  final List<String> calls = [];
  final List<String> opIds = [];
  BuddyResult<PaymentWriteResponse> writeResult = const BuddyOk(PaymentWriteResponse(balancesVersion: 8));
  BuddyResult<void> remindResult = const BuddyOk(null);

  void answer(BuddyResult<TripBalances> next) => _answers
    ..clear()
    ..add(next);

  @override
  Future<BuddyResult<TripBalances>> balances(String tripId) async {
    balanceCalls++;
    return _answers.length > 1 ? _answers.removeAt(0) : _answers.first;
  }

  @override
  Future<BuddyResult<PaymentWriteResponse>> saidPaid(String tripId, {required String opId, required String toUserId, required int amount}) async {
    calls.add('saidPaid:$toUserId:$amount');
    opIds.add(opId);
    return writeResult;
  }

  @override
  Future<BuddyResult<PaymentWriteResponse>> received(String tripId, String paymentId) async {
    calls.add('received:$paymentId');
    return writeResult;
  }

  @override
  Future<BuddyResult<PaymentWriteResponse>> withdraw(String tripId, String paymentId) async {
    calls.add('withdraw:$paymentId');
    return writeResult;
  }

  @override
  Future<BuddyResult<PaymentWriteResponse>> notReceived(String tripId, String paymentId) async {
    calls.add('notReceived:$paymentId');
    return writeResult;
  }

  @override
  Future<BuddyResult<void>> remind(String tripId, String fromUserId) async {
    calls.add('remind:$fromUserId');
    return remindResult;
  }

  @override
  Future<BuddyResult<ExpenseSummary>> summary(String tripId) async {
    summaryCalls++;
    return summaryResult ?? BuddyOk(summarySample());
  }
}

BuddyRefused<T> refused<T>(String type, {int status = 409, String? message}) => BuddyRefused<T>(type: type, statusCode: status, message: message);

FakeLedgerApi registerLedger(List<BuddyResult<TripBalances>> answers, {BuddyResult<ExpenseSummary>? summary}) {
  final api = FakeLedgerApi(answers, summaryResult: summary);
  Get.put<LedgerApi>(api);
  return api;
}

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
      getPages: [for (final r in [AppRoutes.tripExpenses, AppRoutes.tripSettle, AppRoutes.tripMoneySummary]) _stub(r)],
      builder: (context, c) => Stack(fit: StackFit.expand, children: [Positioned.fill(child: c!), Overlay(key: AppToast.overlayKey)]),
      home: home,
    );
