import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_models.dart';
import 'package:bakhli/features/buddy/ledger/models/ledger_models.dart';
import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/buddy/shared/buddy_json.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = r'F:\Dhasu\Buddy_resume\contract_samples';

Object? _raw(String name) => jsonDecode(File('$_dir\\$name.json').readAsStringSync());
Map<String, dynamic> _map(String name) => BuddyJson.map(_raw(name));
List<Map<String, dynamic>> _list(String name) => [for (final e in _raw(name) as List) BuddyJson.map(e)];

const _rahul = '11111111-1111-4111-8111-111111111111';
const _aman = '22222222-2222-4222-8222-222222222222';
const _trip = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

void main() {
  group('buddies', () {
    test('B1 found and not found', () {
      final f = FindResult.fromJson(_map('b1_find_found'));
      expect(f.found, isTrue);
      expect(f.person!.username, 'Bakhli#29583047');
      expect(f.person!.relation, BuddyRelation.none);
      expect(FindResult.fromJson(_map('b1_find_not_found')).found, isFalse);
    });

    test('B1 every relation', () {
      final rel = [for (final j in _list('b1_find_relations')) FindResult.fromJson(j).person!];
      expect(rel.map((p) => p.relation), BuddyRelation.values);
      expect(rel[1].requestId, isNotNull);
      expect(rel[1].expiresAt, DateTime.utc(2026, 5, 30, 10));
      expect(FoundPerson.fromJson({'relation': 'somethingNew'}).relation, BuddyRelation.none);
    });

    test('B5 B8 B11 B14 B16 B17', () {
      expect(BuddyPerson.fromJson(BuddyJson.map(_map('b5_accept')['buddy'])).username, 'Bakhli#73019462');
      final b = BuddyList.fromJson(_map('b8_buddies'));
      expect(b.count, b.items.length);
      final t = BuddyList.fromJson(_map('b8_buddies_for_trip'));
      expect(t.items.map((e) => e.tripState), [BuddyTripState.joined, BuddyTripState.invited, BuddyTripState.none]);
      final sum = BuddySummary.fromJson(_map('b11_summary'));
      expect([sum.buddies, sum.newBuddies, sum.receivedPending, sum.blocked], [2, 1, 1, 1]);
      final bl = BlockedList.fromJson(_map('b14_blocks'));
      expect(bl.items.single.name, 'Vikas');
      final reasons = [for (final j in _list('b16_report_reasons')) ReportReason.fromJson(j)];
      expect(reasons.map((r) => r.name), ['Spam', 'Harassment', 'Fake account', 'Other']);
      expect(reasons.last.isOther, isTrue);
      final ctx = BlockContext.fromJson(_map('b17_block_context'));
      expect(ctx.tripsInCommon.single.iOwn, isTrue);
      expect(const ReportInput(reasonId: 'x', note: 'n').toJson(), {'reasonId': 'x', 'note': 'n'});
    });
  });

  group('sharing', () {
    test('S1 owner and viewer', () {
      final o = TripMembers.fromJson(_map('s1_members_owner'));
      expect(o.isOwner, isTrue);
      expect(o.joined.map((j) => j.last4), ['1736', '8275', '7139']);
      expect(o.joined.first.joinedAt, isNull);
      expect(o.invited.single.name, 'Neha');
      expect(o.seatsLeft, 8);
      final v = TripMembers.fromJson(_map('s1_members_viewer'));
      expect(v.isOwner, isFalse);
      expect(v.invited, isEmpty);
    });

    test('S2 S12 S16 S17 and the trip sharing block', () {
      final i = InviteResult.fromJson(_map('s2_invite_result'));
      expect(i.invitedCount, 1);
      expect(i.results.last.memberId, isNull);
      expect(RemoveResult.fromJson(_map('s12_remove')).sharesExpenses, 6);
      expect(BuddyJson.integer(_map('s16_expense_count')['count']), 6);
      final opts = [for (final j in _list('s17_invite_options')) InviteOption.fromJson(j)];
      expect(opts.map((o) => o.option), ['Available', 'Available', 'OnTrip', 'InviteSent', 'Full']);
      expect(opts[1].startDate, isNull);
      expect(opts.first.startDate, DateTime(2026, 6, 2));
      final block = TripSharingBlock.fromJson(BuddyJson.map(_map('trip_dto_sharing')['sharing']));
      expect(block.isShared, isTrue);
      expect(block.firstTravellers.map((t) => t.initial), ['R', 'A', 'P']);
      expect(block.expenses.spent, 32300);
      expect(TripSharingBlock.fromJson(block.toJson()).expenses.myShare, 11618);
    });

    test('open payments of a refused trip delete', () {
      final lines = OpenPaymentLine.fromRefusal({
        'openPayments': [
          {
            'from': {'userId': _aman, 'name': 'Aman', 'last4': '8275', 'initial': 'A', 'isMe': false, 'status': 'Joined'},
            'to': {'userId': _rahul, 'name': 'Rahul', 'last4': '1736', 'initial': 'R', 'isMe': true, 'status': 'Owner'},
            'amount': 11816,
            'state': 'SaidPaid',
          },
        ],
      });
      expect(lines.single.from.name, 'Aman');
      expect(lines.single.state, 'SaidPaid');
    });
  });

  group('viewer', () {
    test('S7 S8 S13', () {
      final p = InvitePreview.fromJson(_map('s7_invite_preview'));
      expect(p.owner.name, 'Rahul');
      expect(p.legCities, ['Nainital', 'Rishikesh', 'Mussoorie']);
      expect(p.tripId, isNull);
      expect(p.endDate, DateTime(2026, 5, 22));
      expect(BuddyJson.str(_map('s8_accept')['tripId']), _trip);
      expect(LeaveResult.fromJson(_map('s13_leave')).hasShare, isTrue);
    });

    test('S14 view and its cache round trip', () {
      final t = ViewerTrip.fromJson(_map('s14_view'));
      expect(t.legs.length, 3);
      expect(t.days.single.spots.length, 4);
      expect(t.days.single.spots.last.travelMinutesToNext, isNull);
      expect(t.stay.items.single.stayName, 'Snow View Hotel');
      expect(t.taxi.driverFirstName, 'Suresh');
      expect(t.expenses.openPayments, 1);
      final again = ViewerTrip.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(again.toJson(), t.toJson());
      final empty = ViewerTrip.fromJson(_map('s14_view_empty'));
      expect(empty.stay.state, ViewerBookingState.notAdded);
      expect(empty.taxi.vehicleType, isNull);
    });

    test('S15 shared trips', () {
      final s = SharedTrips.fromJson(_map('s15_shared'));
      expect(s.items.single.stayState, 'booked');
      expect(s.invites.single.ownerName, 'Neha');
      expect(s.former.single.myNet, -11816);
      expect(s.counts.upcoming, 1);
    });

    test('S7 and S14 refusal data', () {
      final ended = InviteEnded.fromJson({'reason': 'Expired', 'title': 'Goa', 'ownerName': 'Neha'});
      expect(ended.reason, 'Expired');
      final not = NotOnTripInfo.fromJson({'hasShare': true, 'title': 'Hills', 'endedHow': 'Removed', 'startDate': '2026-05-16'});
      expect(not.removed, isTrue);
      expect(not.startDate, DateTime(2026, 5, 16));
    });
  });

  group('expenses', () {
    test('E1 owner, viewer, former, empty', () {
      final o = ExpenseList.fromJson(_map('e1_expenses_owner'));
      expect(o.isOwner, isTrue);
      expect(o.totals.spent, 32300);
      expect(o.items.length, 6);
      expect(o.items.first.dayNumber, 4);
      expect(o.days.first.date, DateTime(2026, 5, 19));
      expect(o.links.map((l) => l.kind), ['Stay', 'Taxi']);
      expect(o.items[1].edited, isTrue);
      expect(o.travellers.first.isMe, isTrue);
      expect(ExpenseList.fromJson(_map('e1_expenses_viewer')).role, 'Viewer');
      expect(ExpenseList.fromJson(_map('e1_expenses_former')).isFormer, isTrue);
      final e = ExpenseList.fromJson(_map('e1_expenses_empty'));
      expect(e.isEmpty, isTrue);
      expect(e.suggestions.single.amount, 8000);
      final round = ExpenseList.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
      expect(round.toJson(), o.toJson());
    });

    test('E1 late prompt', () {
      final p = LatePrompt.fromJson({
        'userId': '33333333-3333-4333-8333-333333333333',
        'name': 'Priya',
        'joinedAt': '2026-05-18T05:00:00Z',
        'count': 1,
        'total': 8000,
        'items': [
          {
            'expenseId': 'e1',
            'title': 'Snow View Hotel, 3 nights',
            'dayNumber': 1,
            'amount': 8000,
            'paidByUserId': _rahul,
            'version': 1,
            'shares': [
              {'userId': _rahul, 'share': 4000},
              {'userId': _aman, 'share': 4000},
            ],
          },
        ],
      });
      expect(p.items.single.shares.length, 2);
      expect(p.items.single.version, 1);
    });

    test('E2 request matches the sample both ways', () {
      final raw = _map('e2_put_request');
      final req = ExpenseWriteRequest.fromJson(raw);
      expect(req.isCreate, isTrue);
      expect(req.toJson(), raw);
      expect(req.copyWith(paymentsAcknowledged: true, opId: 'o2').toJson()['opId'], 'o2');
    });

    test('E2 response, E4 detail, E7 share with', () {
      final r = ExpenseWriteResponse.fromJson(_map('e2_put_response'));
      expect(r.created, isTrue);
      expect(r.expense.shareOf(_rahul), 6168);
      expect(r.expense.link!.label, 'Taxi, Suresh (Dzire)');
      final d = ExpenseDetailPage.fromJson(_map('e4_expense_detail'));
      expect(d.history.first.changes.single.oldValue, 19200);
      expect(d.person(_aman)!.last4, '8275');
      expect(d.canEdit, isTrue);
      final raw = _map('e7_share_with_request');
      expect(ShareWithRequest.fromJson(raw).toJson(), raw);
      final s = ShareWithResponse.fromJson(_map('e7_share_with_response'));
      expect(s.expenses.single.splitMode, SplitMode.chosen);
      expect(s.notified.length, 2);
    });

    test('unknown enum text falls back', () {
      expect(ExpenseCategory.of('Spa'), ExpenseCategory.other);
      expect(SplitMode.of(null), SplitMode.all);
      expect(PaymentState.of('Withdrawn'), PaymentState.open);
    });
  });

  group('ledger', () {
    test('E8 every sample', () {
      for (final name in ['e8_balances_owner', 'e8_balances_viewer', 'e8_balances_said_paid', 'e8_balances_reopened', 'e8_balances_viewer_receiver']) {
        final b = TripBalances.fromJson(_map(name));
        expect(b.tripId, _trip, reason: name);
        expect(b.people, isNotEmpty, reason: name);
        expect(b.payments, isNotEmpty, reason: name);
      }
      final re = TripBalances.fromJson(_map('e8_balances_reopened'));
      expect(re.reopened!.expenseTitle, 'Taxi, Suresh (Dzire), full trip');
      expect(re.payments[1].paymentId, isNull);
      expect(re.payments[1].afterEdit, isTrue);
      expect(re.payments.first.isReceived, isTrue);
      expect(re.person(_aman)!.name, 'Aman');
    });

    test('E9 E10 E19 E17', () {
      final said = PaymentWriteResponse.fromJson(_map('e9_said_paid_response'));
      expect(said.payment!.isSaidPaid, isTrue);
      expect(said.payment!.canWithdraw, isTrue);
      expect(PaymentWriteResponse.fromJson(_map('e10_received')).balancesVersion, greaterThan(0));
      final nr = PaymentWriteResponse.fromJson(_map('e19_not_received'));
      expect(nr.payment!.afterNotReceivedAt, DateTime.utc(2026, 5, 20, 7));
      expect(PaymentWriteResponse.fromJson({'payment': null, 'balancesVersion': 3}).payment, isNull);
      final s = ExpenseSummary.fromJson(_map('e17_summary'));
      expect(s.total, 32300);
      expect(s.dayTotal(3), 20000);
      expect(s.linkTotal('Taxi', 'd0000000-0000-4000-8000-000000000002'), 18500);
      expect(s.byCategory.first.category, 'Taxi');
    });
  });

  group('notices', () {
    test('N1 has one row of every stored kind', () {
      final p = NoticePage.fromJson(_map('n1_notices'));
      final kinds = p.items.map((n) => n.kind).toSet();
      expect(kinds.every(NoticeKinds.known), isTrue);
      expect(kinds, containsAll(NoticeKinds.all.take(8)));
      expect(p.unread, 5);
      final deleted = p.items.firstWhere((n) => n.kind == NoticeKinds.tripDeleted);
      expect(deleted.tripTitle, isNull);
      expect(deleted.args['deletedTripId'], isNotNull);
      expect(p.items.first.markedRead().isRead, isTrue);
      expect(Notice.fromJson({'kind': 'Future'}).isKnown, isFalse);
    });

    test('unread count, with and without total', () {
      final u = UnreadCount.fromJson(_map('n_unread_count'));
      expect(u.total, 5);
      expect(UnreadCount.fromJson({'count': 2}).total, 2);
    });
  });

  test('every error type of errors.json is a BuddyErrorTypes const or an existing type', () {
    final types = [for (final e in _raw('errors') as List) BuddyJson.map(BuddyJson.map(e)['error'])['type']];
    final missing = types.where((t) => !BuddyErrorTypes.all.contains(t)).toSet();
    expect(missing, isEmpty);
  });
}
