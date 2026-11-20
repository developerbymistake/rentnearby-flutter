import '../../shared/buddy_json.dart';
import '../../shared/models/person_models.dart';

abstract final class TripRoles {
  static const String owner = 'Owner';
  static const String viewer = 'Viewer';
  static const String former = 'Former';
}

class JoinedMember {
  const JoinedMember({
    required this.userId,
    required this.name,
    this.username,
    required this.initial,
    required this.last4,
    required this.role,
    required this.isMe,
    this.joinedAt,
  });

  final String userId;
  final String name;
  final String? username;
  final String initial;
  final String last4;
  final String role;
  final bool isMe;
  final DateTime? joinedAt;

  bool get isOwner => role == TripRoles.owner;

  factory JoinedMember.fromJson(Map<String, dynamic> j) => JoinedMember(
        userId: BuddyJson.str(j['userId']),
        name: BuddyJson.str(j['name']),
        username: BuddyJson.strOrNull(j['username']),
        initial: BuddyJson.str(j['initial']),
        last4: BuddyJson.str(j['last4']),
        role: BuddyJson.str(j['role'], TripRoles.viewer),
        isMe: BuddyJson.boolean(j['isMe']),
        joinedAt: BuddyJson.time(j['joinedAt']),
      );
}

class InvitedMember {
  const InvitedMember({required this.memberId, required this.userId, required this.name, this.username, required this.initial, this.invitedAt, this.expiresAt});

  final String memberId;
  final String userId;
  final String name;
  final String? username;
  final String initial;
  final DateTime? invitedAt;
  final DateTime? expiresAt;

  factory InvitedMember.fromJson(Map<String, dynamic> j) => InvitedMember(
        memberId: BuddyJson.str(j['memberId']),
        userId: BuddyJson.str(j['userId']),
        name: BuddyJson.str(j['name']),
        username: BuddyJson.strOrNull(j['username']),
        initial: BuddyJson.str(j['initial']),
        invitedAt: BuddyJson.time(j['invitedAt']),
        expiresAt: BuddyJson.time(j['expiresAt']),
      );
}

class TripMembers {
  const TripMembers({
    required this.tripId,
    required this.title,
    required this.role,
    required this.ownerName,
    required this.travellerCount,
    required this.maxTravellers,
    required this.pendingInvites,
    required this.seatsLeft,
    required this.joined,
    required this.invited,
    required this.canInvite,
    required this.canLeave,
  });

  final String tripId;
  final String title;
  final String role;
  final String ownerName;
  final int travellerCount;
  final int maxTravellers;
  final int pendingInvites;
  final int seatsLeft;
  final List<JoinedMember> joined;
  final List<InvitedMember> invited;
  final bool canInvite;
  final bool canLeave;

  bool get isOwner => role == TripRoles.owner;
  bool get isFull => isOwner && seatsLeft <= 0;

  factory TripMembers.fromJson(Map<String, dynamic> j) => TripMembers(
        tripId: BuddyJson.str(j['tripId']),
        title: BuddyJson.str(j['title']),
        role: BuddyJson.str(j['role'], TripRoles.viewer),
        ownerName: BuddyJson.str(j['ownerName']),
        travellerCount: BuddyJson.integer(j['travellerCount'], 1),
        maxTravellers: BuddyJson.integer(j['maxTravellers'], 12),
        pendingInvites: BuddyJson.integer(j['pendingInvites']),
        seatsLeft: BuddyJson.integer(j['seatsLeft']),
        joined: BuddyJson.list(j['joined'], JoinedMember.fromJson),
        invited: BuddyJson.list(j['invited'], InvitedMember.fromJson),
        canInvite: BuddyJson.boolean(j['canInvite']),
        canLeave: BuddyJson.boolean(j['canLeave']),
      );
}

abstract final class InviteOutcomes {
  static const String invited = 'Invited';
  static const String alreadyInvited = 'AlreadyInvited';
  static const String alreadyOnTrip = 'AlreadyOnTrip';
  static const String notBuddy = 'NotBuddy';
}

class InviteOutcome {
  const InviteOutcome({required this.userId, required this.outcome, this.memberId});

  final String userId;
  final String outcome;
  final String? memberId;

  factory InviteOutcome.fromJson(Map<String, dynamic> j) =>
      InviteOutcome(userId: BuddyJson.str(j['userId']), outcome: BuddyJson.str(j['outcome']), memberId: BuddyJson.strOrNull(j['memberId']));
}

class InviteResult {
  const InviteResult({required this.results, required this.seatsLeft});

  final List<InviteOutcome> results;
  final int seatsLeft;

  int get invitedCount => results.where((r) => r.outcome == InviteOutcomes.invited).length;

  factory InviteResult.fromJson(Map<String, dynamic> j) =>
      InviteResult(results: BuddyJson.list(j['results'], InviteOutcome.fromJson), seatsLeft: BuddyJson.integer(j['seatsLeft']));
}

class RemoveResult {
  const RemoveResult({required this.status, required this.sharesExpenses});

  final String status;
  final int sharesExpenses;

  factory RemoveResult.fromJson(Map<String, dynamic> j) =>
      RemoveResult(status: BuddyJson.str(j['status']), sharesExpenses: BuddyJson.integer(j['sharesExpenses']));
}

abstract final class InviteOptionKind {
  static const String available = 'Available';
  static const String onTrip = 'OnTrip';
  static const String inviteSent = 'InviteSent';
  static const String full = 'Full';
  static const String noPlaces = 'NoPlaces';
}

class InviteOption {
  const InviteOption({
    required this.tripId,
    required this.title,
    required this.status,
    this.startDate,
    this.endDate,
    required this.dayCount,
    required this.travellerCount,
    required this.option,
  });

  final String tripId;
  final String title;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int dayCount;
  final int travellerCount;
  final String option;

  bool get available => option == InviteOptionKind.available;

  factory InviteOption.fromJson(Map<String, dynamic> j) => InviteOption(
        tripId: BuddyJson.str(j['tripId']),
        title: BuddyJson.str(j['title']),
        status: BuddyJson.str(j['status']),
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        dayCount: BuddyJson.integer(j['dayCount']),
        travellerCount: BuddyJson.integer(j['travellerCount'], 1),
        option: BuddyJson.str(j['option'], InviteOptionKind.available),
      );
}

class TravellerDot {
  const TravellerDot({required this.userId, required this.initial, required this.name});

  final String userId;
  final String initial;
  final String name;

  factory TravellerDot.fromJson(Map<String, dynamic> j) =>
      TravellerDot(userId: BuddyJson.str(j['userId']), initial: BuddyJson.str(j['initial']), name: BuddyJson.str(j['name']));

  Map<String, dynamic> toJson() => {'userId': userId, 'initial': initial, 'name': name};
}

class TripExpenseCard {
  const TripExpenseCard({this.hasExpenses = false, this.spent = 0, this.myShare = 0, this.dayToday, this.openPayments = 0, this.settled = true});

  final bool hasExpenses;
  final int spent;
  final int myShare;
  final int? dayToday;
  final int openPayments;
  final bool settled;

  static const TripExpenseCard none = TripExpenseCard();

  factory TripExpenseCard.fromJson(Map<String, dynamic> j) => TripExpenseCard(
        hasExpenses: BuddyJson.boolean(j['hasExpenses']),
        spent: BuddyJson.integer(j['spent']),
        myShare: BuddyJson.integer(j['myShare']),
        dayToday: BuddyJson.intOrNull(j['dayToday']),
        openPayments: BuddyJson.integer(j['openPayments']),
        settled: BuddyJson.boolean(j['settled'], true),
      );

  Map<String, dynamic> toJson() => {
        'hasExpenses': hasExpenses,
        'spent': spent,
        'myShare': myShare,
        'dayToday': dayToday,
        'openPayments': openPayments,
        'settled': settled,
      };
}

class TripSharingBlock {
  const TripSharingBlock({
    required this.travellerCount,
    required this.viewerCount,
    required this.pendingInvites,
    required this.firstTravellers,
    required this.expenses,
  });

  final int travellerCount;
  final int viewerCount;
  final int pendingInvites;
  final List<TravellerDot> firstTravellers;
  final TripExpenseCard expenses;

  bool get isShared => viewerCount > 0;

  factory TripSharingBlock.fromJson(Map<String, dynamic> j) => TripSharingBlock(
        travellerCount: BuddyJson.integer(j['travellerCount'], 1),
        viewerCount: BuddyJson.integer(j['viewerCount']),
        pendingInvites: BuddyJson.integer(j['pendingInvites']),
        firstTravellers: BuddyJson.list(j['firstTravellers'], TravellerDot.fromJson),
        expenses: TripExpenseCard.fromJson(BuddyJson.map(j['expenses'])),
      );

  Map<String, dynamic> toJson() => {
        'travellerCount': travellerCount,
        'viewerCount': viewerCount,
        'pendingInvites': pendingInvites,
        'firstTravellers': [for (final t in firstTravellers) t.toJson()],
        'expenses': expenses.toJson(),
      };
}

class OpenPaymentLine {
  const OpenPaymentLine({required this.from, required this.to, required this.amount, required this.state});

  final MoneyPerson from;
  final MoneyPerson to;
  final int amount;
  final String state;

  factory OpenPaymentLine.fromJson(Map<String, dynamic> j) => OpenPaymentLine(
        from: MoneyPerson.fromJson(BuddyJson.map(j['from'])),
        to: MoneyPerson.fromJson(BuddyJson.map(j['to'])),
        amount: BuddyJson.integer(j['amount']),
        state: BuddyJson.str(j['state'], 'Open'),
      );

  static List<OpenPaymentLine> fromRefusal(Map<String, dynamic> data) => BuddyJson.list(data['openPayments'], OpenPaymentLine.fromJson);
}
