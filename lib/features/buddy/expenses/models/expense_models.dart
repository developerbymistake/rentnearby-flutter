import '../../shared/buddy_json.dart';
import '../../shared/models/person_models.dart';

abstract final class ExpenseCategory {
  static const String stay = 'Stay';
  static const String taxi = 'Taxi';
  static const String food = 'Food';
  static const String fuel = 'Fuel';
  static const String tickets = 'Tickets';
  static const String other = 'Other';

  static const List<String> all = [stay, taxi, food, fuel, tickets, other];

  static String of(Object? v) => v is String && all.contains(v) ? v : other;
}

abstract final class SplitMode {
  static const String all = 'All';
  static const String chosen = 'Chosen';
  static const String custom = 'Custom';

  static const List<String> values = [all, chosen, custom];

  static String of(Object? v) => v is String && values.contains(v) ? v : all;
}

abstract final class ExpenseLinkKind {
  static const String stay = 'Stay';
  static const String taxi = 'Taxi';
}

class ExpenseTotals {
  const ExpenseTotals({this.spent = 0, this.expenseCount = 0, this.myShare = 0, this.myPaid = 0});

  final int spent;
  final int expenseCount;
  final int myShare;
  final int myPaid;

  factory ExpenseTotals.fromJson(Map<String, dynamic> j) => ExpenseTotals(
        spent: BuddyJson.integer(j['spent']),
        expenseCount: BuddyJson.integer(j['expenseCount']),
        myShare: BuddyJson.integer(j['myShare']),
        myPaid: BuddyJson.integer(j['myPaid']),
      );

  Map<String, dynamic> toJson() => {'spent': spent, 'expenseCount': expenseCount, 'myShare': myShare, 'myPaid': myPaid};
}

class ExpenseDayTotal {
  const ExpenseDayTotal({required this.day, this.date, required this.total, required this.count});

  final int day;
  final DateTime? date;
  final int total;
  final int count;

  factory ExpenseDayTotal.fromJson(Map<String, dynamic> j) => ExpenseDayTotal(
        day: BuddyJson.integer(j['day'], 1),
        date: BuddyJson.date(j['date']),
        total: BuddyJson.integer(j['total']),
        count: BuddyJson.integer(j['count']),
      );

  Map<String, dynamic> toJson() => {'day': day, 'date': BuddyJson.dateText(date), 'total': total, 'count': count};
}

class ExpenseSuggestion {
  const ExpenseSuggestion({required this.kind, required this.sourceId, required this.name, required this.amount, required this.day});

  final String kind;
  final String sourceId;
  final String name;
  final int amount;
  final int day;

  factory ExpenseSuggestion.fromJson(Map<String, dynamic> j) => ExpenseSuggestion(
        kind: BuddyJson.str(j['kind'], ExpenseLinkKind.stay),
        sourceId: BuddyJson.str(j['sourceId']),
        name: BuddyJson.str(j['name']),
        amount: BuddyJson.integer(j['amount']),
        day: BuddyJson.integer(j['day'], 1),
      );

  Map<String, dynamic> toJson() => {'kind': kind, 'sourceId': sourceId, 'name': name, 'amount': amount, 'day': day};
}

class ExpenseLinkOption {
  const ExpenseLinkOption({required this.kind, required this.id, required this.label, this.day, required this.cancelled});

  final String kind;
  final String id;
  final String label;
  final int? day;
  final bool cancelled;

  factory ExpenseLinkOption.fromJson(Map<String, dynamic> j) => ExpenseLinkOption(
        kind: BuddyJson.str(j['kind'], ExpenseLinkKind.stay),
        id: BuddyJson.str(j['id']),
        label: BuddyJson.str(j['label']),
        day: BuddyJson.intOrNull(j['day']),
        cancelled: BuddyJson.boolean(j['cancelled']),
      );

  Map<String, dynamic> toJson() => {'kind': kind, 'id': id, 'label': label, 'day': day, 'cancelled': cancelled};
}

class ExpenseShare {
  const ExpenseShare({required this.userId, required this.share});

  final String userId;
  final int share;

  factory ExpenseShare.fromJson(Map<String, dynamic> j) => ExpenseShare(userId: BuddyJson.str(j['userId']), share: BuddyJson.integer(j['share']));

  Map<String, dynamic> toJson() => {'userId': userId, 'share': share};
}

class LateCandidate {
  const LateCandidate({
    required this.expenseId,
    required this.title,
    required this.dayNumber,
    required this.amount,
    required this.paidByUserId,
    required this.version,
    required this.shares,
  });

  final String expenseId;
  final String title;
  final int dayNumber;
  final int amount;
  final String paidByUserId;
  final int version;
  final List<ExpenseShare> shares;

  factory LateCandidate.fromJson(Map<String, dynamic> j) => LateCandidate(
        expenseId: BuddyJson.str(j['expenseId']),
        title: BuddyJson.str(j['title']),
        dayNumber: BuddyJson.integer(j['dayNumber'], 1),
        amount: BuddyJson.integer(j['amount']),
        paidByUserId: BuddyJson.str(j['paidByUserId']),
        version: BuddyJson.integer(j['version'], 1),
        shares: BuddyJson.list(j['shares'], ExpenseShare.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'expenseId': expenseId,
        'title': title,
        'dayNumber': dayNumber,
        'amount': amount,
        'paidByUserId': paidByUserId,
        'version': version,
        'shares': [for (final s in shares) s.toJson()],
      };
}

class LatePrompt {
  const LatePrompt({required this.userId, required this.name, this.joinedAt, required this.count, required this.total, required this.items});

  final String userId;
  final String name;
  final DateTime? joinedAt;
  final int count;
  final int total;
  final List<LateCandidate> items;

  factory LatePrompt.fromJson(Map<String, dynamic> j) => LatePrompt(
        userId: BuddyJson.str(j['userId']),
        name: BuddyJson.str(j['name']),
        joinedAt: BuddyJson.time(j['joinedAt']),
        count: BuddyJson.integer(j['count']),
        total: BuddyJson.integer(j['total']),
        items: BuddyJson.list(j['items'], LateCandidate.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'joinedAt': BuddyJson.timeText(joinedAt),
        'count': count,
        'total': total,
        'items': [for (final i in items) i.toJson()],
      };
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.dayNumber,
    required this.paidByUserId,
    required this.sharedBy,
    required this.myShare,
    required this.version,
    required this.edited,
    this.linkKind,
    this.linkId,
    this.bookingCancelled = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final int amount;
  final int dayNumber;
  final String paidByUserId;
  final int sharedBy;
  final int myShare;
  final int version;
  final bool edited;
  final String? linkKind;
  final String? linkId;
  final bool bookingCancelled;
  final DateTime? createdAt;

  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
        id: BuddyJson.str(j['id']),
        title: BuddyJson.str(j['title']),
        category: ExpenseCategory.of(j['category']),
        amount: BuddyJson.integer(j['amount']),
        dayNumber: BuddyJson.integer(j['dayNumber'], 1),
        paidByUserId: BuddyJson.str(j['paidByUserId']),
        sharedBy: BuddyJson.integer(j['sharedBy']),
        myShare: BuddyJson.integer(j['myShare']),
        version: BuddyJson.integer(j['version'], 1),
        edited: BuddyJson.boolean(j['edited']),
        linkKind: BuddyJson.strOrNull(j['linkKind']),
        linkId: BuddyJson.strOrNull(j['linkId']),
        bookingCancelled: BuddyJson.boolean(j['bookingCancelled']),
        createdAt: BuddyJson.time(j['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'dayNumber': dayNumber,
        'paidByUserId': paidByUserId,
        'sharedBy': sharedBy,
        'myShare': myShare,
        'version': version,
        'edited': edited,
        'linkKind': linkKind,
        'linkId': linkId,
        'bookingCancelled': bookingCancelled,
        'createdAt': BuddyJson.timeText(createdAt),
      };
}

class ExpenseList {
  const ExpenseList({
    required this.tripId,
    required this.tripTitle,
    required this.ownerName,
    required this.role,
    required this.isOwner,
    this.startDate,
    this.endDate,
    required this.dayCount,
    required this.dayToday,
    required this.tripEnded,
    required this.frozen,
    this.closesOn,
    required this.balancesVersion,
    required this.limitReached,
    required this.totals,
    required this.travellers,
    required this.days,
    required this.suggestions,
    required this.links,
    this.latePrompt,
    required this.items,
    this.nextCursor,
  });

  final String tripId;
  final String tripTitle;
  final String ownerName;
  final String role;
  final bool isOwner;
  final DateTime? startDate;
  final DateTime? endDate;
  final int dayCount;
  final int dayToday;
  final bool tripEnded;
  final bool frozen;
  final DateTime? closesOn;
  final int balancesVersion;
  final bool limitReached;
  final ExpenseTotals totals;
  final List<MoneyPerson> travellers;
  final List<ExpenseDayTotal> days;
  final List<ExpenseSuggestion> suggestions;
  final List<ExpenseLinkOption> links;
  final LatePrompt? latePrompt;
  final List<ExpenseItem> items;
  final String? nextCursor;

  bool get isFormer => role == 'Former';
  bool get isEmpty => totals.expenseCount == 0 && items.isEmpty;

  factory ExpenseList.fromJson(Map<String, dynamic> j) {
    final late = BuddyJson.mapOrNull(j['latePrompt']);
    return ExpenseList(
      tripId: BuddyJson.str(j['tripId']),
      tripTitle: BuddyJson.str(j['tripTitle']),
      ownerName: BuddyJson.str(j['ownerName']),
      role: BuddyJson.str(j['role'], 'Viewer'),
      isOwner: BuddyJson.boolean(j['isOwner']),
      startDate: BuddyJson.date(j['startDate']),
      endDate: BuddyJson.date(j['endDate']),
      dayCount: BuddyJson.integer(j['dayCount'], 1),
      dayToday: BuddyJson.integer(j['dayToday'], 1),
      tripEnded: BuddyJson.boolean(j['tripEnded']),
      frozen: BuddyJson.boolean(j['frozen']),
      closesOn: BuddyJson.date(j['closesOn']),
      balancesVersion: BuddyJson.integer(j['balancesVersion']),
      limitReached: BuddyJson.boolean(j['limitReached']),
      totals: ExpenseTotals.fromJson(BuddyJson.map(j['totals'])),
      travellers: BuddyJson.list(j['travellers'], MoneyPerson.fromJson),
      days: BuddyJson.list(j['days'], ExpenseDayTotal.fromJson),
      suggestions: BuddyJson.list(j['suggestions'], ExpenseSuggestion.fromJson),
      links: BuddyJson.list(j['links'], ExpenseLinkOption.fromJson),
      latePrompt: late == null ? null : LatePrompt.fromJson(late),
      items: BuddyJson.list(j['items'], ExpenseItem.fromJson),
      nextCursor: BuddyJson.strOrNull(j['nextCursor']),
    );
  }

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'tripTitle': tripTitle,
        'ownerName': ownerName,
        'role': role,
        'isOwner': isOwner,
        'startDate': BuddyJson.dateText(startDate),
        'endDate': BuddyJson.dateText(endDate),
        'dayCount': dayCount,
        'dayToday': dayToday,
        'tripEnded': tripEnded,
        'frozen': frozen,
        'closesOn': BuddyJson.dateText(closesOn),
        'balancesVersion': balancesVersion,
        'limitReached': limitReached,
        'totals': totals.toJson(),
        'travellers': [for (final t in travellers) t.toJson()],
        'days': [for (final d in days) d.toJson()],
        'suggestions': [for (final s in suggestions) s.toJson()],
        'links': [for (final l in links) l.toJson()],
        'latePrompt': latePrompt?.toJson(),
        'items': [for (final i in items) i.toJson()],
        'nextCursor': nextCursor,
      };
}

class ExpenseLinkRef {
  const ExpenseLinkRef({required this.kind, required this.id, this.label, this.cancelled = false});

  final String kind;
  final String id;
  final String? label;
  final bool cancelled;

  factory ExpenseLinkRef.fromJson(Map<String, dynamic> j) => ExpenseLinkRef(
        kind: BuddyJson.str(j['kind'], ExpenseLinkKind.stay),
        id: BuddyJson.str(j['id']),
        label: BuddyJson.strOrNull(j['label']),
        cancelled: BuddyJson.boolean(j['cancelled']),
      );

  Map<String, dynamic> toRequestJson() => {'kind': kind, 'id': id};
}

class ExpenseDetail {
  const ExpenseDetail({
    required this.id,
    required this.tripId,
    required this.title,
    required this.category,
    required this.amount,
    required this.dayNumber,
    this.date,
    this.link,
    required this.paidByUserId,
    required this.splitMode,
    this.leftoverUserId,
    this.note,
    required this.version,
    required this.editedTimes,
    this.createdAt,
    this.updatedAt,
    required this.deleted,
    required this.shares,
  });

  final String id;
  final String tripId;
  final String title;
  final String category;
  final int amount;
  final int dayNumber;
  final DateTime? date;
  final ExpenseLinkRef? link;
  final String paidByUserId;
  final String splitMode;
  final String? leftoverUserId;
  final String? note;
  final int version;
  final int editedTimes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool deleted;
  final List<ExpenseShare> shares;

  int shareOf(String userId) => shares.where((s) => s.userId == userId).fold(0, (a, s) => a + s.share);

  factory ExpenseDetail.fromJson(Map<String, dynamic> j) {
    final link = BuddyJson.mapOrNull(j['link']);
    return ExpenseDetail(
      id: BuddyJson.str(j['id']),
      tripId: BuddyJson.str(j['tripId']),
      title: BuddyJson.str(j['title']),
      category: ExpenseCategory.of(j['category']),
      amount: BuddyJson.integer(j['amount']),
      dayNumber: BuddyJson.integer(j['dayNumber'], 1),
      date: BuddyJson.date(j['date']),
      link: link == null ? null : ExpenseLinkRef.fromJson(link),
      paidByUserId: BuddyJson.str(j['paidByUserId']),
      splitMode: SplitMode.of(j['splitMode']),
      leftoverUserId: BuddyJson.strOrNull(j['leftoverUserId']),
      note: BuddyJson.strOrNull(j['note']),
      version: BuddyJson.integer(j['version'], 1),
      editedTimes: BuddyJson.integer(j['editedTimes']),
      createdAt: BuddyJson.time(j['createdAt']),
      updatedAt: BuddyJson.time(j['updatedAt']),
      deleted: BuddyJson.boolean(j['deleted']),
      shares: BuddyJson.list(j['shares'], ExpenseShare.fromJson),
    );
  }
}

class ExpenseChange {
  const ExpenseChange({required this.field, this.oldValue, this.newValue});

  final String field;
  final Object? oldValue;
  final Object? newValue;

  factory ExpenseChange.fromJson(Map<String, dynamic> j) => ExpenseChange(field: BuddyJson.str(j['field']), oldValue: j['old'], newValue: j['new']);
}

abstract final class ExpenseHistoryKind {
  static const String added = 'Added';
  static const String edited = 'Edited';
  static const String sharedWith = 'SharedWith';
  static const String deleted = 'Deleted';
}

class ExpenseHistoryLine {
  const ExpenseHistoryLine({
    required this.version,
    this.at,
    this.actorUserId,
    required this.kind,
    required this.changes,
    required this.amountAfter,
    required this.sharedBy,
  });

  final int version;
  final DateTime? at;
  final String? actorUserId;
  final String kind;
  final List<ExpenseChange> changes;
  final int amountAfter;
  final int sharedBy;

  factory ExpenseHistoryLine.fromJson(Map<String, dynamic> j) => ExpenseHistoryLine(
        version: BuddyJson.integer(j['version'], 1),
        at: BuddyJson.time(j['at']),
        actorUserId: BuddyJson.strOrNull(j['actorUserId']),
        kind: BuddyJson.str(j['kind'], ExpenseHistoryKind.edited),
        changes: BuddyJson.list(j['changes'], ExpenseChange.fromJson),
        amountAfter: BuddyJson.integer(j['amountAfter']),
        sharedBy: BuddyJson.integer(j['sharedBy']),
      );
}

class ExpenseDetailPage {
  const ExpenseDetailPage({required this.expense, required this.people, required this.history, required this.canEdit, required this.canDelete});

  final ExpenseDetail expense;
  final List<MoneyPerson> people;
  final List<ExpenseHistoryLine> history;
  final bool canEdit;
  final bool canDelete;

  MoneyPerson? person(String? userId) {
    for (final p in people) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  factory ExpenseDetailPage.fromJson(Map<String, dynamic> j) => ExpenseDetailPage(
        expense: ExpenseDetail.fromJson(BuddyJson.map(j['expense'])),
        people: BuddyJson.list(j['people'], MoneyPerson.fromJson),
        history: BuddyJson.list(j['history'], ExpenseHistoryLine.fromJson),
        canEdit: BuddyJson.boolean(j['canEdit']),
        canDelete: BuddyJson.boolean(j['canDelete']),
      );
}

class ExpenseWriteRequest {
  const ExpenseWriteRequest({
    required this.opId,
    required this.baseVersion,
    required this.amount,
    required this.title,
    required this.category,
    required this.dayNumber,
    this.link,
    required this.paidByUserId,
    required this.splitMode,
    this.sharers = const [],
    this.shares = const [],
    this.note,
    this.paymentsAcknowledged = false,
  });

  final String opId;
  final int baseVersion;
  final int amount;
  final String title;
  final String category;
  final int dayNumber;
  final ExpenseLinkRef? link;
  final String paidByUserId;
  final String splitMode;
  final List<String> sharers;
  final List<ExpenseShare> shares;
  final String? note;
  final bool paymentsAcknowledged;

  bool get isCreate => baseVersion == 0;

  factory ExpenseWriteRequest.fromJson(Map<String, dynamic> j) {
    final link = BuddyJson.mapOrNull(j['link']);
    return ExpenseWriteRequest(
      opId: BuddyJson.str(j['opId']),
      baseVersion: BuddyJson.integer(j['baseVersion']),
      amount: BuddyJson.integer(j['amount']),
      title: BuddyJson.str(j['title']),
      category: ExpenseCategory.of(j['category']),
      dayNumber: BuddyJson.integer(j['dayNumber'], 1),
      link: link == null ? null : ExpenseLinkRef.fromJson(link),
      paidByUserId: BuddyJson.str(j['paidByUserId']),
      splitMode: SplitMode.of(j['splitMode']),
      sharers: BuddyJson.strings(j['sharers']),
      shares: BuddyJson.list(j['shares'], ExpenseShare.fromJson),
      note: BuddyJson.strOrNull(j['note']),
      paymentsAcknowledged: BuddyJson.boolean(j['paymentsAcknowledged']),
    );
  }

  ExpenseWriteRequest copyWith({String? opId, int? baseVersion, bool? paymentsAcknowledged}) => ExpenseWriteRequest(
        opId: opId ?? this.opId,
        baseVersion: baseVersion ?? this.baseVersion,
        amount: amount,
        title: title,
        category: category,
        dayNumber: dayNumber,
        link: link,
        paidByUserId: paidByUserId,
        splitMode: splitMode,
        sharers: sharers,
        shares: shares,
        note: note,
        paymentsAcknowledged: paymentsAcknowledged ?? this.paymentsAcknowledged,
      );

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'baseVersion': baseVersion,
        'amount': amount,
        'title': title,
        'category': category,
        'dayNumber': dayNumber,
        'link': link?.toRequestJson(),
        'paidByUserId': paidByUserId,
        'splitMode': splitMode,
        'sharers': sharers,
        'shares': [for (final s in shares) s.toJson()],
        'note': note,
        'paymentsAcknowledged': paymentsAcknowledged,
      };
}

class ExpenseWriteResponse {
  const ExpenseWriteResponse({required this.expense, required this.balancesVersion, required this.created});

  final ExpenseDetail expense;
  final int balancesVersion;
  final bool created;

  factory ExpenseWriteResponse.fromJson(Map<String, dynamic> j) => ExpenseWriteResponse(
        expense: ExpenseDetail.fromJson(BuddyJson.map(j['expense'])),
        balancesVersion: BuddyJson.integer(j['balancesVersion']),
        created: BuddyJson.boolean(j['created']),
      );
}

class ShareWithItem {
  const ShareWithItem({required this.expenseId, required this.baseVersion});

  final String expenseId;
  final int baseVersion;

  Map<String, dynamic> toJson() => {'expenseId': expenseId, 'baseVersion': baseVersion};
}

class ShareWithRequest {
  const ShareWithRequest({required this.opId, required this.userId, required this.items, this.paymentsAcknowledged = false});

  final String opId;
  final String userId;
  final List<ShareWithItem> items;
  final bool paymentsAcknowledged;

  factory ShareWithRequest.fromJson(Map<String, dynamic> j) => ShareWithRequest(
        opId: BuddyJson.str(j['opId']),
        userId: BuddyJson.str(j['userId']),
        items: BuddyJson.list(j['items'], (m) => ShareWithItem(expenseId: BuddyJson.str(m['expenseId']), baseVersion: BuddyJson.integer(m['baseVersion']))),
        paymentsAcknowledged: BuddyJson.boolean(j['paymentsAcknowledged']),
      );

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'userId': userId,
        'items': [for (final i in items) i.toJson()],
        'paymentsAcknowledged': paymentsAcknowledged,
      };
}

class ShareWithResponse {
  const ShareWithResponse({required this.expenses, required this.balancesVersion, required this.notified});

  final List<ExpenseDetail> expenses;
  final int balancesVersion;
  final List<String> notified;

  factory ShareWithResponse.fromJson(Map<String, dynamic> j) => ShareWithResponse(
        expenses: BuddyJson.list(j['expenses'], ExpenseDetail.fromJson),
        balancesVersion: BuddyJson.integer(j['balancesVersion']),
        notified: BuddyJson.strings(j['notified']),
      );
}
