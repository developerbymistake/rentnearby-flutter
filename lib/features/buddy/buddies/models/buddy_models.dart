import '../../shared/buddy_json.dart';
import '../../shared/models/person_models.dart';

enum BuddyRelation { none, requestedByMe, requestedMe, buddy, cooldown, self }

BuddyRelation _relation(Object? v) => BuddyJson.pick(v, {for (final r in BuddyRelation.values) r.name: r}, BuddyRelation.none);

abstract final class BuddySource {
  static const String search = 'Search';
  static const String qr = 'Qr';
}

abstract final class BuddyContext {
  static const String request = 'Request';
  static const String buddy = 'Buddy';
  static const String find = 'Find';
  static const String trip = 'Trip';
  static const String profile = 'Profile';
  static const String tripPost = 'TripPost';
  static const String chat = 'Chat';
  static const String joinReq = 'JoinReq';
}

class FoundPerson extends BuddyPerson {
  const FoundPerson({
    required super.userId,
    required super.name,
    required super.username,
    required super.initial,
    super.photoUrl,
    required this.relation,
    this.requestId,
    this.expiresAt,
    this.followState = 'none',
  });

  final BuddyRelation relation;
  final String? requestId;
  final DateTime? expiresAt;
  // Does the caller follow this person: following | requested | none.
  final String followState;

  factory FoundPerson.fromJson(Map<String, dynamic> j) => FoundPerson(
        userId: BuddyJson.str(j['userId']),
        name: BuddyJson.str(j['name']),
        username: BuddyJson.strOrNull(j['username']),
        initial: BuddyJson.str(j['initial']),
        photoUrl: BuddyJson.photo(j['photoUrl']),
        relation: _relation(j['relation']),
        requestId: BuddyJson.strOrNull(j['requestId']),
        expiresAt: BuddyJson.time(j['expiresAt']),
        followState: BuddyJson.str(j['followState'], 'none'),
      );

  FoundPerson copyWith({BuddyRelation? relation, String? requestId, DateTime? expiresAt}) => FoundPerson(
        userId: userId,
        name: name,
        username: username,
        initial: initial,
        photoUrl: photoUrl,
        relation: relation ?? this.relation,
        requestId: requestId ?? this.requestId,
        expiresAt: expiresAt ?? this.expiresAt,
        followState: followState,
      );
}

class FindResult {
  const FindResult({required this.found, this.person});

  final bool found;
  final FoundPerson? person;

  factory FindResult.fromJson(Map<String, dynamic> j) {
    final p = BuddyJson.mapOrNull(j['person']);
    final found = BuddyJson.boolean(j['found']) && p != null;
    return FindResult(found: found, person: found ? FoundPerson.fromJson(p) : null);
  }
}

abstract final class BuddyTripState {
  static const String none = 'None';
  static const String invited = 'Invited';
  static const String joined = 'Joined';
}

class BuddyItem {
  const BuddyItem({
    required this.userId,
    required this.name,
    required this.username,
    required this.initial,
    required this.isNew,
    this.since,
    this.tripState,
    this.photoUrl,
    this.gender = '',
    this.tripsTogether = 0,
    this.mutualCount = 0,
  });

  final String userId;
  final String name;
  final String? username;
  final String initial;
  final String? photoUrl;
  final bool isNew;
  final DateTime? since;
  final String? tripState;
  final String gender;
  final int tripsTogether;
  final int mutualCount;

  BuddyPerson get person => BuddyPerson(userId: userId, name: name, username: username, initial: initial, photoUrl: photoUrl);

  factory BuddyItem.fromJson(Map<String, dynamic> j) => BuddyItem(
        userId: BuddyJson.str(j['userId']),
        name: BuddyJson.str(j['name']),
        username: BuddyJson.strOrNull(j['username']),
        initial: BuddyJson.str(j['initial']),
        isNew: BuddyJson.boolean(j['isNew']),
        since: BuddyJson.time(j['since']),
        tripState: BuddyJson.strOrNull(j['tripState']),
        photoUrl: BuddyJson.photo(j['photoUrl']),
        gender: BuddyJson.str(j['gender']),
        tripsTogether: BuddyJson.integer(j['tripsTogether']),
        mutualCount: BuddyJson.integer(j['mutualCount']),
      );
}

class BuddyList {
  const BuddyList({required this.items, required this.count, this.nextCursor});

  final List<BuddyItem> items;
  final int count;
  final String? nextCursor;

  factory BuddyList.fromJson(Map<String, dynamic> j) => BuddyList(
        items: BuddyJson.list(j['items'], BuddyItem.fromJson),
        count: BuddyJson.integer(j['count']),
        nextCursor: BuddyJson.strOrNull(j['nextCursor']),
      );
}

class BuddySummary {
  const BuddySummary({this.buddies = 0, this.newBuddies = 0, this.receivedPending = 0, this.blocked = 0});

  final int buddies;
  final int newBuddies;
  final int receivedPending;
  final int blocked;

  static const BuddySummary empty = BuddySummary();

  factory BuddySummary.fromJson(Map<String, dynamic> j) => BuddySummary(
        buddies: BuddyJson.integer(j['buddies']),
        newBuddies: BuddyJson.integer(j['newBuddies']),
        receivedPending: BuddyJson.integer(j['receivedPending']),
        blocked: BuddyJson.integer(j['blocked']),
      );
}

class BlockedPerson {
  const BlockedPerson({required this.userId, required this.name, required this.username, required this.initial, this.blockedAt, this.photoUrl});

  final String userId;
  final String name;
  final String? username;
  final String initial;
  final String? photoUrl;
  final DateTime? blockedAt;

  factory BlockedPerson.fromJson(Map<String, dynamic> j) => BlockedPerson(
        userId: BuddyJson.str(j['userId']),
        name: BuddyJson.str(j['name']),
        username: BuddyJson.strOrNull(j['username']),
        initial: BuddyJson.str(j['initial']),
        blockedAt: BuddyJson.time(j['blockedAt']),
        photoUrl: BuddyJson.photo(j['photoUrl']),
      );
}

class BlockedList {
  const BlockedList({required this.items, required this.count, this.nextCursor});

  final List<BlockedPerson> items;
  final int count;
  final String? nextCursor;

  factory BlockedList.fromJson(Map<String, dynamic> j) => BlockedList(
        items: BuddyJson.list(j['items'], BlockedPerson.fromJson),
        count: BuddyJson.integer(j['count']),
        nextCursor: BuddyJson.strOrNull(j['nextCursor']),
      );
}

class ReportReason {
  const ReportReason({required this.id, required this.name, this.description});

  final String id;
  final String name;
  final String? description;

  bool get isOther => name == 'Other';

  factory ReportReason.fromJson(Map<String, dynamic> j) =>
      ReportReason(id: BuddyJson.str(j['id']), name: BuddyJson.str(j['name']), description: BuddyJson.strOrNull(j['description']));
}

class ReportInput {
  const ReportInput({required this.reasonId, this.note});

  final String reasonId;
  final String? note;

  Map<String, dynamic> toJson() => {'reasonId': reasonId, 'note': note};
}

class TripInCommon {
  const TripInCommon({required this.tripId, required this.title, required this.myRole});

  final String tripId;
  final String title;
  final String myRole;

  bool get iOwn => myRole == 'Owner';

  factory TripInCommon.fromJson(Map<String, dynamic> j) =>
      TripInCommon(tripId: BuddyJson.str(j['tripId']), title: BuddyJson.str(j['title']), myRole: BuddyJson.str(j['myRole'], 'Viewer'));
}

class BlockContext {
  const BlockContext({this.person, required this.tripsInCommon});

  final BuddyPerson? person;
  final List<TripInCommon> tripsInCommon;

  factory BlockContext.fromJson(Map<String, dynamic> j) {
    final p = BuddyJson.mapOrNull(j['person']);
    return BlockContext(person: p == null ? null : BuddyPerson.fromJson(p), tripsInCommon: BuddyJson.list(j['tripsInCommon'], TripInCommon.fromJson));
  }
}
