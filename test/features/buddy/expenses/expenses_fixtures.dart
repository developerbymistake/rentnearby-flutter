import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/expenses/data/expense_list_cache.dart';
import 'package:bakhli/features/buddy/expenses/data/expense_write_gateway.dart';
import 'package:bakhli/features/buddy/expenses/data/expenses_api.dart';
import 'package:bakhli/features/buddy/expenses/expense_deps.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_draft.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_models.dart';
import 'package:bakhli/features/buddy/expenses/widgets/expense_sheet.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:get/get.dart';

const samples = r'F:\Dhasu\Buddy_resume\contract_samples';
const tripId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const rahul = '11111111-1111-4111-8111-111111111111';
const aman = '22222222-2222-4222-8222-222222222222';
const priya = '33333333-3333-4333-8333-333333333333';
const stayLink = 'd0000000-0000-4000-8000-000000000001';
const taxiLink = 'd0000000-0000-4000-8000-000000000002';
const e1 = 'e0000000-0000-4000-8000-000000000001';
const e2 = 'e0000000-0000-4000-8000-000000000002';
const e3 = 'e0000000-0000-4000-8000-000000000003';
const e4 = 'e0000000-0000-4000-8000-000000000004';
const e5 = 'e0000000-0000-4000-8000-000000000005';

Map<String, dynamic> sample(String name) => jsonDecode(File('$samples\\$name.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> person(String id, String name, String last4, {bool me = false, String status = 'Joined'}) =>
    {'userId': id, 'name': name, 'last4': last4, 'initial': name[0], 'isMe': me, 'status': status};

List<Map<String, dynamic>> people({String amanStatus = 'Joined', bool withPriya = true, String me = rahul}) => [
      person(rahul, 'Rahul', '1736', me: me == rahul, status: 'Owner'),
      person(aman, 'Aman', '8275', me: me == aman, status: amanStatus),
      if (withPriya) person(priya, 'Priya', '7139', me: me == priya),
    ];

Map<String, dynamic> item(String id, String title, String cat, int amount, int day, String payer, int sharedBy, int myShare, {bool edited = false}) => {
      'id': id,
      'title': title,
      'category': cat,
      'amount': amount,
      'dayNumber': day,
      'paidByUserId': payer,
      'sharedBy': sharedBy,
      'myShare': myShare,
      'version': 1,
      'edited': edited,
    };

ExpenseList ownerList([Map<String, dynamic> over = const {}]) => ExpenseList.fromJson({...sample('e1_expenses_owner'), ...over});

ExpenseList emptyList() => ownerList({
      'dayToday': 1,
      'totals': {'spent': 0, 'expenseCount': 0, 'myShare': 0, 'myPaid': 0},
      'travellers': people(withPriya: false),
      'days': <Object>[],
      'items': <Object>[],
      'suggestions': [
        {'kind': 'Stay', 'sourceId': stayLink, 'name': 'Snow View Hotel', 'amount': 8000, 'day': 1},
      ],
    });

ExpenseList viewerEmpty() => ExpenseList.fromJson({
      ...emptyList().toJson(),
      'role': 'Viewer',
      'isOwner': false,
      'suggestions': <Object>[],
      'travellers': people(withPriya: false, me: aman),
    });

ExpenseList sheetList({int dayToday = 4, String amanStatus = 'Joined'}) => ownerList({'dayToday': dayToday, 'travellers': people(amanStatus: amanStatus)});

ExpenseList limitList() => ownerList({
      'dayToday': 6,
      'limitReached': true,
      'totals': {'spent': 412600, 'expenseCount': 500, 'myShare': 137534, 'myPaid': 200000},
      'days': [
        {'day': 6, 'date': '2026-05-21', 'total': 3250, 'count': 3},
        {'day': 5, 'date': '2026-05-20', 'total': 100000, 'count': 100},
        {'day': 4, 'date': '2026-05-19', 'total': 100000, 'count': 100},
        {'day': 3, 'date': '2026-05-18', 'total': 100000, 'count': 100},
        {'day': 2, 'date': '2026-05-17', 'total': 100000, 'count': 100},
        {'day': 1, 'date': '2026-05-16', 'total': 9350, 'count': 97},
      ],
      'items': [
        item('x1', 'Breakfast at the cafe', 'Food', 750, 6, rahul, 3, 250),
        item('x2', 'Kempty Falls tickets', 'Tickets', 1500, 6, rahul, 3, 500),
        item('x3', 'Fuel top-up', 'Fuel', 1000, 6, aman, 3, 334),
      ],
      'nextCursor': 'next',
    });

Map<String, dynamic> lateCandidate(String id, String title, int day, int amount, String payer, List<List<Object>> shares) => {
      'expenseId': id,
      'title': title,
      'dayNumber': day,
      'amount': amount,
      'paidByUserId': payer,
      'version': 1,
      'shares': [for (final s in shares) {'userId': s[0], 'share': s[1]}],
    };

ExpenseList lateList() => ownerList({
      'dayToday': 3,
      'totals': {'spent': 9900, 'expenseCount': 3, 'myShare': 4950, 'myPaid': 8900},
      'days': [
        {'day': 2, 'date': '2026-05-17', 'total': 900, 'count': 1},
        {'day': 1, 'date': '2026-05-16', 'total': 9000, 'count': 2},
      ],
      'items': [
        item(e3, 'Naini Lake boating', 'Tickets', 900, 2, rahul, 2, 450),
        item(e1, 'Snow View Hotel, 3 nights', 'Stay', 8000, 1, rahul, 2, 4000),
        item(e2, 'Lunch at Mall Road', 'Food', 1000, 1, aman, 2, 500),
      ],
      'latePrompt': {
        'userId': priya,
        'name': 'Priya',
        'joinedAt': '2026-05-18T08:00:00Z',
        'count': 3,
        'total': 9900,
        'items': [
          lateCandidate(e1, 'Snow View Hotel, 3 nights', 1, 8000, rahul, [
            [rahul, 4000],
            [aman, 4000],
          ]),
          lateCandidate(e2, 'Lunch at Mall Road', 1, 1000, aman, [
            [rahul, 500],
            [aman, 500],
          ]),
          lateCandidate(e3, 'Naini Lake boating', 2, 900, rahul, [
            [rahul, 450],
            [aman, 450],
          ]),
        ],
      },
    });

ExpenseDetailPage detailPage([Map<String, dynamic> expenseOver = const {}, Map<String, dynamic> over = const {}]) {
  final j = sample('e4_expense_detail');
  return ExpenseDetailPage.fromJson({
    ...j,
    'expense': {...(j['expense'] as Map<String, dynamic>), ...expenseOver},
    ...over,
  });
}

class FakeExpensesApi extends ExpensesApi {
  FakeExpensesApi({this.listResult, this.detailResult, this.pages = const {}});

  BuddyResult<ExpenseList>? listResult;
  BuddyResult<ExpenseDetailPage>? detailResult;
  final Map<String, BuddyResult<ExpenseList>> pages;
  BuddyResult<void> skipResult = const BuddyOk<void>(null);
  BuddyResult<void> keepResult = const BuddyOk<void>(null);
  final List<BuddyResult<ShareWithResponse>> shareResults = [];
  final List<String> calls = [];
  final List<ShareWithRequest> shareBodies = [];

  @override
  Future<BuddyResult<ExpenseList>> list(String tripId, {String? cursor, int limit = 100}) async {
    calls.add('list:${cursor ?? ''}:$limit');
    if (cursor != null) return pages[cursor] ?? const BuddyOffline();
    return listResult ?? const BuddyOffline();
  }

  @override
  Future<BuddyResult<ExpenseDetailPage>> detail(String tripId, String expenseId) async {
    calls.add('detail:$expenseId');
    return detailResult ?? const BuddyOffline();
  }

  @override
  Future<BuddyResult<void>> skipSuggestion(String tripId, {required String kind, required String sourceId}) async {
    calls.add('skip:$sourceId');
    return skipResult;
  }

  @override
  Future<BuddyResult<void>> keepLateJoin(String tripId, String userId) async {
    calls.add('keep:$userId');
    return keepResult;
  }

  @override
  Future<BuddyResult<ShareWithResponse>> shareWith(String tripId, ShareWithRequest body) async {
    calls.add('share');
    shareBodies.add(body);
    if (shareResults.isEmpty) return const BuddyOk(ShareWithResponse(expenses: [], balancesVersion: 8, notified: []));
    return shareResults.removeAt(0);
  }
}

class FakeGateway implements ExpenseWriteGateway {
  final List<ExpenseDraft> drafts = [];
  final List<({int baseVersion, String opId, bool ack})> deletes = [];
  final List<ExpenseWriteOutcome> saveOutcomes = [];
  final List<ExpenseWriteOutcome> deleteOutcomes = [];

  @override
  Future<ExpenseWriteOutcome> save(ExpenseDraft draft) async {
    drafts.add(draft);
    if (saveOutcomes.isNotEmpty) return saveOutcomes.removeAt(0);
    return ExpenseSaved(expense: detailPage().expense, balancesVersion: 9);
  }

  @override
  Future<ExpenseWriteOutcome> delete({
    required String tripId,
    required String expenseId,
    required int baseVersion,
    required String opId,
    bool paymentsAcknowledged = false,
    required ExpenseItem shown,
  }) async {
    deletes.add((baseVersion: baseVersion, opId: opId, ack: paymentsAcknowledged));
    if (deleteOutcomes.isNotEmpty) return deleteOutcomes.removeAt(0);
    return const ExpenseDeleted(balancesVersion: 9);
  }
}

ExpenseRefused refused(String type, {int status = 409, Map<String, dynamic> data = const {}, String? message}) =>
    ExpenseRefused(error: BuddyRefused<Object?>(type: type, statusCode: status, data: data, message: message));

({FakeExpensesApi api, FakeGateway gateway}) registerFakes({BuddyResult<ExpenseList>? list, BuddyResult<ExpenseDetailPage>? detail}) {
  final api = FakeExpensesApi(listResult: list, detailResult: detail);
  final gateway = FakeGateway();
  Get.put<ExpensesApi>(api);
  Get.put<ExpenseWriteGateway>(gateway);
  ExpenseListCache.store = MemoryExpenseCacheStore();
  return (api: api, gateway: gateway);
}

void resetExpenseFakes() {
  BuddySnack.hide();
  ExpenseDeps.debugReset();
  ExpenseListCache.debugReset();
  ExpenseSheet.debugLast = null;
  BuddyLive.reset();
  Get.reset();
}
