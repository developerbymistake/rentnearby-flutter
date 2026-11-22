import '../buddy_json.dart';

class BuddyPerson {
  const BuddyPerson({required this.userId, required this.name, required this.username, required this.initial, this.photoUrl});

  final String userId;
  final String name;
  final String? username;
  final String initial;
  final String? photoUrl;

  factory BuddyPerson.fromJson(Map<String, dynamic> j) => BuddyPerson(
        userId: BuddyJson.str(j['userId']),
        name: BuddyJson.str(j['name']),
        username: BuddyJson.strOrNull(j['username']),
        initial: BuddyJson.str(j['initial']),
        photoUrl: BuddyJson.photo(j['photoUrl']),
      );

  Map<String, dynamic> toJson() => {'userId': userId, 'name': name, 'username': username, 'initial': initial, 'photoUrl': photoUrl};
}

abstract final class MoneyPersonStatus {
  static const String owner = 'Owner';
  static const String joined = 'Joined';
  static const String left = 'Left';
  static const String removed = 'Removed';
  static const String deleted = 'Deleted';
}

class MoneyPerson {
  const MoneyPerson({required this.userId, required this.name, required this.last4, required this.initial, required this.isMe, required this.status, this.photoUrl});

  final String userId;
  final String name;
  final String last4;
  final String initial;
  final String? photoUrl;
  final bool isMe;
  final String status;

  bool get isFormer => status == MoneyPersonStatus.left || status == MoneyPersonStatus.removed;
  bool get isDeleted => status == MoneyPersonStatus.deleted;
  bool get isOwner => status == MoneyPersonStatus.owner;

  factory MoneyPerson.fromJson(Map<String, dynamic> j) => MoneyPerson(
        userId: BuddyJson.str(j['userId']),
        name: BuddyJson.str(j['name']),
        last4: BuddyJson.str(j['last4']),
        initial: BuddyJson.str(j['initial']),
        isMe: BuddyJson.boolean(j['isMe']),
        status: BuddyJson.str(j['status'], MoneyPersonStatus.joined),
        photoUrl: BuddyJson.photo(j['photoUrl']),
      );

  Map<String, dynamic> toJson() => {'userId': userId, 'name': name, 'last4': last4, 'initial': initial, 'isMe': isMe, 'status': status, 'photoUrl': photoUrl};
}

class BuddyCursorPage<T> {
  const BuddyCursorPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory BuddyCursorPage.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) =>
      BuddyCursorPage(items: BuddyJson.list(j['items'], parse), nextCursor: BuddyJson.strOrNull(j['nextCursor']));
}
