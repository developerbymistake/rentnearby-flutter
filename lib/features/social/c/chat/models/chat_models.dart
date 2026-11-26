import '../../../../buddy/shared/buddy_json.dart';
import '../../../shared/social_models.dart';

abstract final class RoomKind {
  static const String direct = 'D';
  static const String trip = 'T';
}

abstract final class RoomStatus {
  static const String request = 'Request';
  static const String active = 'Active';
  static const String declined = 'Declined';
}

abstract final class RoomLock {
  static const String none = 'none';
  static const String awaitingReply = 'awaitingReply';
  static const String limit = 'limit';
  static const String left = 'left';
}

abstract final class RoomBucket {
  static const String people = 'people';
  static const String trips = 'trips';
  static const String requests = 'requests';
}

class RoomTrip {
  const RoomTrip({required this.tripId, required this.title, this.memberCount = 0, this.photoUrls = const [], this.initials = const [], this.cityKey = 0});

  final String tripId;
  final String title;
  final int memberCount;
  final List<String> photoUrls;
  final List<String> initials;
  final int cityKey;

  factory RoomTrip.fromJson(Map<String, dynamic> j) => RoomTrip(
        tripId: BuddyJson.str(j['tripId']),
        title: BuddyJson.str(j['title']),
        memberCount: BuddyJson.integer(j['memberCount']),
        photoUrls: BuddyJson.strings(j['photoUrls']),
        initials: BuddyJson.strings(j['memberInitials']),
        cityKey: BuddyJson.integer(j['cityKey']),
      );
}

class ChatRoomModel {
  const ChatRoomModel({
    required this.roomId,
    required this.kind,
    required this.status,
    this.iStarted = false,
    this.peer,
    this.trip,
    this.subtitle,
    this.peerFollowsMe = false,
    this.iFollowPeer = false,
    this.lastSeq = 0,
    this.lastReadSeq = 0,
    this.peerLastReadSeq,
    this.unread = 0,
    this.lastMessageAt,
    this.preview,
    this.canSend = true,
    this.lock = RoomLock.none,
  });

  final String roomId;
  final String kind;
  final String status;
  final bool iStarted;
  final SocialPerson? peer;
  final RoomTrip? trip;
  final String? subtitle;
  final bool peerFollowsMe;
  final bool iFollowPeer;
  final int lastSeq;
  final int lastReadSeq;
  final int? peerLastReadSeq;
  final int unread;
  final DateTime? lastMessageAt;
  final String? preview;
  final bool canSend;
  final String lock;

  bool get isTrip => kind == RoomKind.trip;
  bool get isRequest => status == RoomStatus.request;
  bool get isIncomingRequest => !isTrip && isRequest && !iStarted;
  String get title => isTrip ? (trip?.title ?? '') : (peer?.name ?? '');

  ChatRoomModel copyWith({
    String? status,
    String? lock,
    bool? canSend,
    int? lastSeq,
    int? lastReadSeq,
    int? peerLastReadSeq,
    int? unread,
    DateTime? lastMessageAt,
    String? preview,
  }) =>
      ChatRoomModel(
        roomId: roomId,
        kind: kind,
        status: status ?? this.status,
        iStarted: iStarted,
        peer: peer,
        trip: trip,
        subtitle: subtitle,
        peerFollowsMe: peerFollowsMe,
        iFollowPeer: iFollowPeer,
        lastSeq: lastSeq ?? this.lastSeq,
        lastReadSeq: lastReadSeq ?? this.lastReadSeq,
        peerLastReadSeq: peerLastReadSeq ?? this.peerLastReadSeq,
        unread: unread ?? this.unread,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        preview: preview ?? this.preview,
        canSend: canSend ?? this.canSend,
        lock: lock ?? this.lock,
      );

  factory ChatRoomModel.fromJson(Map<String, dynamic> j) {
    final peer = BuddyJson.mapOrNull(j['peer']);
    final trip = BuddyJson.mapOrNull(j['trip']);
    return ChatRoomModel(
      roomId: BuddyJson.str(j['roomId']),
      kind: BuddyJson.str(j['kind'], RoomKind.direct) == RoomKind.trip ? RoomKind.trip : RoomKind.direct,
      status: BuddyJson.str(j['status'], RoomStatus.active),
      iStarted: BuddyJson.boolean(j['iStarted']),
      peer: peer == null ? null : SocialPerson.fromJson(peer),
      trip: trip == null ? null : RoomTrip.fromJson(trip),
      subtitle: BuddyJson.strOrNull(j['subtitle']),
      peerFollowsMe: BuddyJson.boolean(j['peerFollowsMe']),
      iFollowPeer: BuddyJson.boolean(j['iFollowPeer']),
      lastSeq: BuddyJson.integer(j['lastSeq']),
      lastReadSeq: BuddyJson.integer(j['lastReadSeq']),
      peerLastReadSeq: BuddyJson.intOrNull(j['peerLastReadSeq']),
      unread: BuddyJson.integer(j['unread']),
      lastMessageAt: BuddyJson.time(j['lastMessageAt']),
      preview: BuddyJson.strOrNull(j['preview']),
      canSend: BuddyJson.boolean(j['canSend'], true),
      lock: BuddyJson.str(j['lock'], RoomLock.none),
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.seq,
    this.senderId,
    this.senderName,
    required this.text,
    this.masked = false,
    this.system,
    this.createdAt,
    this.expiresAt,
    this.clientMessageId,
    this.sending = false,
    this.failed = false,
  });

  final int seq;
  final String? senderId;
  final String? senderName;
  final String text;
  final bool masked;
  final String? system;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? clientMessageId;
  final bool sending;
  final bool failed;

  static const String joined = 'joined';
  static const String left = 'left';

  bool get isSystem => system != null;
  bool get isLocal => seq <= 0;

  ChatMessageModel copyWith({bool? sending, bool? failed}) => ChatMessageModel(
        seq: seq,
        senderId: senderId,
        senderName: senderName,
        text: text,
        masked: masked,
        system: system,
        createdAt: createdAt,
        expiresAt: expiresAt,
        clientMessageId: clientMessageId,
        sending: sending ?? this.sending,
        failed: failed ?? this.failed,
      );

  factory ChatMessageModel.fromJson(Map<String, dynamic> j) {
    final system = BuddyJson.strOrNull(j['system']);
    return ChatMessageModel(
      seq: BuddyJson.integer(j['seq']),
      senderId: BuddyJson.strOrNull(j['senderId']),
      senderName: BuddyJson.strOrNull(j['senderName']),
      text: BuddyJson.str(j['text']),
      masked: BuddyJson.boolean(j['masked']),
      system: system == joined || system == left ? system : null,
      createdAt: BuddyJson.time(j['createdAt']),
      expiresAt: BuddyJson.time(j['expiresAt']),
      clientMessageId: BuddyJson.strOrNull(j['clientMessageId']),
    );
  }
}

class RoomsPage {
  const RoomsPage({required this.items, this.nextCursor, this.unread = ChatUnread.zero});

  final List<ChatRoomModel> items;
  final String? nextCursor;
  final ChatUnread unread;

  factory RoomsPage.fromJson(Map<String, dynamic> j) => RoomsPage(
        items: BuddyJson.list(j['items'], ChatRoomModel.fromJson),
        nextCursor: BuddyJson.strOrNull(j['nextCursor']),
        unread: ChatUnread.fromJson(BuddyJson.mapOrNull(j['unread'])),
      );
}

class ChatPreflight {
  const ChatPreflight({this.room, required this.peer, this.canMessage = false, this.lock = RoomLock.none, this.newChats = LimitUse.none, this.isFree = false});

  final ChatRoomModel? room;
  final SocialPerson peer;
  final bool canMessage;
  final String lock;
  final LimitUse newChats;
  final bool isFree;

  factory ChatPreflight.fromJson(Map<String, dynamic> j) {
    final room = BuddyJson.mapOrNull(j['room']);
    return ChatPreflight(
      room: room == null ? null : ChatRoomModel.fromJson(room),
      peer: SocialPerson.fromJson(BuddyJson.map(j['peer'])),
      canMessage: BuddyJson.boolean(j['canMessage']),
      lock: BuddyJson.str(j['lock'], RoomLock.none),
      newChats: LimitUse.fromJson(BuddyJson.mapOrNull(j['newChats'])),
      isFree: BuddyJson.boolean(j['isFree']),
    );
  }
}

class StartedChat {
  const StartedChat({required this.room, required this.message});

  final ChatRoomModel room;
  final ChatMessageModel message;

  factory StartedChat.fromJson(Map<String, dynamic> j) => StartedChat(
        room: ChatRoomModel.fromJson(BuddyJson.map(j['room'])),
        message: ChatMessageModel.fromJson(BuddyJson.map(j['message'])),
      );
}

class MessagesPage {
  const MessagesPage({required this.items, this.lastSeq = 0, this.peerLastReadSeq});

  final List<ChatMessageModel> items;
  final int lastSeq;
  final int? peerLastReadSeq;

  factory MessagesPage.fromJson(Map<String, dynamic> j) => MessagesPage(
        items: BuddyJson.list(j['items'], ChatMessageModel.fromJson),
        lastSeq: BuddyJson.integer(j['lastSeq']),
        peerLastReadSeq: BuddyJson.intOrNull(j['peerLastReadSeq']),
      );
}
