import '../../shared/buddy_json.dart';
import '../../shared/models/person_models.dart';

abstract final class PaymentState {
  static const String open = 'Open';
  static const String saidPaid = 'SaidPaid';
  static const String received = 'Received';

  static String of(Object? v) => v == saidPaid || v == received ? v as String : open;
}

class BalanceMe {
  const BalanceMe({this.paid = 0, this.share = 0, this.net = 0, this.received = 0, this.stillOpen = 0, this.saidPaidWaiting = 0});

  final int paid;
  final int share;
  final int net;
  final int received;
  final int stillOpen;
  final int saidPaidWaiting;

  factory BalanceMe.fromJson(Map<String, dynamic> j) => BalanceMe(
        paid: BuddyJson.integer(j['paid']),
        share: BuddyJson.integer(j['share']),
        net: BuddyJson.integer(j['net']),
        received: BuddyJson.integer(j['received']),
        stillOpen: BuddyJson.integer(j['stillOpen']),
        saidPaidWaiting: BuddyJson.integer(j['saidPaidWaiting']),
      );
}

class BalancePerson {
  const BalancePerson({required this.person, required this.paid, required this.share, required this.net});

  final MoneyPerson person;
  final int paid;
  final int share;
  final int net;

  factory BalancePerson.fromJson(Map<String, dynamic> j) => BalancePerson(
        person: MoneyPerson.fromJson(BuddyJson.map(j['person'])),
        paid: BuddyJson.integer(j['paid']),
        share: BuddyJson.integer(j['share']),
        net: BuddyJson.integer(j['net']),
      );
}

class PaymentRow {
  const PaymentRow({
    this.paymentId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.state,
    this.saidPaidAt,
    this.receivedAt,
    this.receivedByUserId,
    this.afterNotReceivedAt,
    this.afterEdit = false,
    this.canSayPaid = false,
    this.canWithdraw = false,
    this.canMarkReceived = false,
    this.canMarkNotReceived = false,
    this.canRemind = false,
    this.reminderSentToday = false,
  });

  final String? paymentId;
  final String fromUserId;
  final String toUserId;
  final int amount;
  final String state;
  final DateTime? saidPaidAt;
  final DateTime? receivedAt;
  final String? receivedByUserId;
  final DateTime? afterNotReceivedAt;
  final bool afterEdit;
  final bool canSayPaid;
  final bool canWithdraw;
  final bool canMarkReceived;
  final bool canMarkNotReceived;
  final bool canRemind;
  final bool reminderSentToday;

  bool get isOpen => state == PaymentState.open;
  bool get isSaidPaid => state == PaymentState.saidPaid;
  bool get isReceived => state == PaymentState.received;

  factory PaymentRow.fromJson(Map<String, dynamic> j) => PaymentRow(
        paymentId: BuddyJson.strOrNull(j['paymentId']),
        fromUserId: BuddyJson.str(j['fromUserId']),
        toUserId: BuddyJson.str(j['toUserId']),
        amount: BuddyJson.integer(j['amount']),
        state: PaymentState.of(j['state']),
        saidPaidAt: BuddyJson.time(j['saidPaidAt']),
        receivedAt: BuddyJson.time(j['receivedAt']),
        receivedByUserId: BuddyJson.strOrNull(j['receivedByUserId']),
        afterNotReceivedAt: BuddyJson.time(j['afterNotReceivedAt']),
        afterEdit: BuddyJson.boolean(j['afterEdit']),
        canSayPaid: BuddyJson.boolean(j['canSayPaid']),
        canWithdraw: BuddyJson.boolean(j['canWithdraw']),
        canMarkReceived: BuddyJson.boolean(j['canMarkReceived']),
        canMarkNotReceived: BuddyJson.boolean(j['canMarkNotReceived']),
        canRemind: BuddyJson.boolean(j['canRemind']),
        reminderSentToday: BuddyJson.boolean(j['reminderSentToday']),
      );
}

class ReopenedInfo {
  const ReopenedInfo({this.at, this.expenseId, this.expenseTitle});

  final DateTime? at;
  final String? expenseId;
  final String? expenseTitle;

  factory ReopenedInfo.fromJson(Map<String, dynamic> j) => ReopenedInfo(
        at: BuddyJson.time(j['at']),
        expenseId: BuddyJson.strOrNull(j['expenseId']),
        expenseTitle: BuddyJson.strOrNull(j['expenseTitle']),
      );
}

class TripBalances {
  const TripBalances({
    required this.tripId,
    required this.tripTitle,
    required this.ownerName,
    required this.role,
    required this.isOwner,
    required this.tripEnded,
    required this.frozen,
    this.endDate,
    required this.balancesVersion,
    required this.settled,
    required this.paymentsDone,
    required this.paymentsTotal,
    this.reopened,
    required this.me,
    required this.people,
    required this.payments,
  });

  final String tripId;
  final String tripTitle;
  final String ownerName;
  final String role;
  final bool isOwner;
  final bool tripEnded;
  final bool frozen;
  final DateTime? endDate;
  final int balancesVersion;
  final bool settled;
  final int paymentsDone;
  final int paymentsTotal;
  final ReopenedInfo? reopened;
  final BalanceMe me;
  final List<BalancePerson> people;
  final List<PaymentRow> payments;

  MoneyPerson? person(String userId) {
    for (final p in people) {
      if (p.person.userId == userId) return p.person;
    }
    return null;
  }

  factory TripBalances.fromJson(Map<String, dynamic> j) {
    final re = BuddyJson.mapOrNull(j['reopened']);
    return TripBalances(
      tripId: BuddyJson.str(j['tripId']),
      tripTitle: BuddyJson.str(j['tripTitle']),
      ownerName: BuddyJson.str(j['ownerName']),
      role: BuddyJson.str(j['role'], 'Viewer'),
      isOwner: BuddyJson.boolean(j['isOwner']),
      tripEnded: BuddyJson.boolean(j['tripEnded']),
      frozen: BuddyJson.boolean(j['frozen']),
      endDate: BuddyJson.date(j['endDate']),
      balancesVersion: BuddyJson.integer(j['balancesVersion']),
      settled: BuddyJson.boolean(j['settled'], true),
      paymentsDone: BuddyJson.integer(j['paymentsDone']),
      paymentsTotal: BuddyJson.integer(j['paymentsTotal']),
      reopened: re == null ? null : ReopenedInfo.fromJson(re),
      me: BalanceMe.fromJson(BuddyJson.map(j['me'])),
      people: BuddyJson.list(j['people'], BalancePerson.fromJson),
      payments: BuddyJson.list(j['payments'], PaymentRow.fromJson),
    );
  }
}

class PaymentWriteResponse {
  const PaymentWriteResponse({this.payment, required this.balancesVersion});

  final PaymentRow? payment;
  final int balancesVersion;

  factory PaymentWriteResponse.fromJson(Map<String, dynamic> j) {
    final p = BuddyJson.mapOrNull(j['payment']);
    return PaymentWriteResponse(payment: p == null ? null : PaymentRow.fromJson(p), balancesVersion: BuddyJson.integer(j['balancesVersion']));
  }
}

class SummaryPerson {
  const SummaryPerson({required this.person, required this.share, required this.paid});

  final MoneyPerson person;
  final int share;
  final int paid;

  factory SummaryPerson.fromJson(Map<String, dynamic> j) => SummaryPerson(
        person: MoneyPerson.fromJson(BuddyJson.map(j['person'])),
        share: BuddyJson.integer(j['share']),
        paid: BuddyJson.integer(j['paid']),
      );
}

class CategoryTotal {
  const CategoryTotal({required this.category, required this.amount});

  final String category;
  final int amount;

  factory CategoryTotal.fromJson(Map<String, dynamic> j) => CategoryTotal(category: BuddyJson.str(j['category']), amount: BuddyJson.integer(j['amount']));
}

class DayTotal {
  const DayTotal({required this.day, this.date, required this.total});

  final int day;
  final DateTime? date;
  final int total;

  factory DayTotal.fromJson(Map<String, dynamic> j) =>
      DayTotal(day: BuddyJson.integer(j['day'], 1), date: BuddyJson.date(j['date']), total: BuddyJson.integer(j['total']));
}

class LinkTotal {
  const LinkTotal({required this.kind, required this.id, required this.total});

  final String kind;
  final String id;
  final int total;

  factory LinkTotal.fromJson(Map<String, dynamic> j) =>
      LinkTotal(kind: BuddyJson.str(j['kind']), id: BuddyJson.str(j['id']), total: BuddyJson.integer(j['total']));
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.tripId,
    required this.title,
    this.startDate,
    this.endDate,
    required this.dayCount,
    required this.travellerCount,
    required this.total,
    required this.expenseCount,
    required this.settled,
    required this.openPayments,
    required this.perPerson,
    required this.byCategory,
    required this.byDay,
    required this.byLink,
  });

  final String tripId;
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final int dayCount;
  final int travellerCount;
  final int total;
  final int expenseCount;
  final bool settled;
  final int openPayments;
  final List<SummaryPerson> perPerson;
  final List<CategoryTotal> byCategory;
  final List<DayTotal> byDay;
  final List<LinkTotal> byLink;

  int dayTotal(int day) => byDay.where((d) => d.day == day).fold(0, (a, d) => a + d.total);

  int linkTotal(String kind, String id) => byLink.where((l) => l.kind == kind && l.id == id).fold(0, (a, l) => a + l.total);

  factory ExpenseSummary.fromJson(Map<String, dynamic> j) => ExpenseSummary(
        tripId: BuddyJson.str(j['tripId']),
        title: BuddyJson.str(j['title']),
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        dayCount: BuddyJson.integer(j['dayCount']),
        travellerCount: BuddyJson.integer(j['travellerCount'], 1),
        total: BuddyJson.integer(j['total']),
        expenseCount: BuddyJson.integer(j['expenseCount']),
        settled: BuddyJson.boolean(j['settled'], true),
        openPayments: BuddyJson.integer(j['openPayments']),
        perPerson: BuddyJson.list(j['perPerson'], SummaryPerson.fromJson),
        byCategory: BuddyJson.list(j['byCategory'], CategoryTotal.fromJson),
        byDay: BuddyJson.list(j['byDay'], DayTotal.fromJson),
        byLink: BuddyJson.list(j['byLink'], LinkTotal.fromJson),
      );
}
