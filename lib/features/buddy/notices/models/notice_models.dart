import '../../shared/buddy_json.dart';

abstract final class NoticeKinds {
  static const String buddyRequest = 'BuddyRequest';
  static const String tripInvite = 'TripInvite';
  static const String paymentSaidPaid = 'PaymentSaidPaid';
  static const String settleReminder = 'SettleReminder';
  static const String paymentNotReceived = 'PaymentNotReceived';
  static const String expensesChanged = 'ExpensesChanged';
  static const String tripRemoved = 'TripRemoved';
  static const String tripDeleted = 'TripDeleted';
  static const String buddyAccepted = 'BuddyAccepted';
  static const String newBuddy = 'NewBuddy';
  static const String tripJoined = 'TripJoined';
  static const String planUpdated = 'PlanUpdated';
  static const String expenseAdded = 'ExpenseAdded';
  static const String shareChanged = 'ShareChanged';

  static const List<String> all = [
    buddyRequest,
    tripInvite,
    paymentSaidPaid,
    settleReminder,
    paymentNotReceived,
    expensesChanged,
    tripRemoved,
    tripDeleted,
    buddyAccepted,
    newBuddy,
    tripJoined,
    planUpdated,
    expenseAdded,
    shareChanged,
  ];

  static bool known(String kind) => all.contains(kind);
}

class Notice {
  const Notice({
    required this.id,
    required this.kind,
    this.tripId,
    this.tripTitle,
    this.actorUserId,
    this.actorName,
    this.refId,
    this.amount,
    required this.count,
    this.createdAt,
    this.updatedAt,
    required this.isRead,
    this.route,
    this.args = const {},
  });

  final String id;
  final String kind;
  final String? tripId;
  final String? tripTitle;
  final String? actorUserId;
  final String? actorName;
  final String? refId;
  final int? amount;
  final int count;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isRead;
  final String? route;
  final Map<String, dynamic> args;

  bool get isKnown => NoticeKinds.known(kind);

  Notice markedRead() => Notice(
        id: id,
        kind: kind,
        tripId: tripId,
        tripTitle: tripTitle,
        actorUserId: actorUserId,
        actorName: actorName,
        refId: refId,
        amount: amount,
        count: count,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isRead: true,
        route: route,
        args: args,
      );

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: BuddyJson.str(j['id']),
        kind: BuddyJson.str(j['kind']),
        tripId: BuddyJson.strOrNull(j['tripId']),
        tripTitle: BuddyJson.strOrNull(j['tripTitle']),
        actorUserId: BuddyJson.strOrNull(j['actorUserId']),
        actorName: BuddyJson.strOrNull(j['actorName']),
        refId: BuddyJson.strOrNull(j['refId']),
        amount: BuddyJson.intOrNull(j['amount']),
        count: BuddyJson.integer(j['count'], 1),
        createdAt: BuddyJson.time(j['createdAt']),
        updatedAt: BuddyJson.time(j['updatedAt']),
        isRead: BuddyJson.boolean(j['isRead']),
        route: BuddyJson.strOrNull(j['route']),
        args: BuddyJson.map(j['args']),
      );
}

class NoticePage {
  const NoticePage({required this.items, this.nextCursor, required this.unread});

  final List<Notice> items;
  final String? nextCursor;
  final int unread;

  factory NoticePage.fromJson(Map<String, dynamic> j) => NoticePage(
        items: BuddyJson.list(j['items'], Notice.fromJson),
        nextCursor: BuddyJson.strOrNull(j['nextCursor']),
        unread: BuddyJson.integer(j['unread']),
      );
}

class UnreadCount {
  const UnreadCount({required this.count, required this.notices, required this.total});

  final int count;
  final int notices;
  final int total;

  factory UnreadCount.fromJson(Map<String, dynamic> j) {
    final count = BuddyJson.integer(j['count']);
    final notices = BuddyJson.integer(j['notices']);
    return UnreadCount(count: count, notices: notices, total: BuddyJson.intOrNull(j['total']) ?? count + notices);
  }
}
