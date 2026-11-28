import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../../buddy/shared/buddy_json.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_models.dart';
import 'data/social_chat_api.dart';
import 'models/chat_models.dart';

sealed class DmEvent {
  const DmEvent();
}

class DmMessageEvent extends DmEvent {
  const DmMessageEvent({required this.roomId, required this.kind, required this.roomStatus, required this.message});

  final String roomId;
  final String kind;
  final String roomStatus;
  final ChatMessageModel message;
}

class DmReadEvent extends DmEvent {
  const DmReadEvent({required this.roomId, required this.userId, required this.seq});

  final String roomId;
  final String userId;
  final int seq;
}

class DmRoomChangedEvent extends DmEvent {
  const DmRoomChangedEvent({required this.roomId, required this.status, required this.lock});

  final String roomId;
  final String status;
  final String lock;
}

class DmRoomSettingsEvent extends DmEvent {
  const DmRoomSettingsEvent({required this.roomId, required this.onlyOwnerSends, required this.ownerName});

  final String roomId;
  final bool onlyOwnerSends;
  final String ownerName;
}

class DmUnreadEvent extends DmEvent {
  const DmUnreadEvent(this.unread);

  final ChatUnread unread;
}

class DmSessionEndedEvent extends DmEvent {
  const DmSessionEndedEvent(this.reason);

  final String reason;
}

class DmReconnectedEvent extends DmEvent {
  const DmReconnectedEvent();
}

abstract class DmTransport {
  Stream<DmEvent> get events;

  Future<Map<String, dynamic>?> send(String roomId, String clientMessageId, String text);

  void read(String roomId, int seq);
}

class DmHubBridge implements DmTransport {
  DmHubBridge._();

  static final DmHubBridge instance = DmHubBridge._();

  static const Duration sendTimeout = Duration(seconds: 5);
  static const Duration readDebounce = Duration(seconds: 1);
  static const List<String> _events = ['DmMessage', 'DmRead', 'DmRoomChanged', 'DmRoomSettings', 'DmUnread', 'SessionEnded'];

  final _controller = StreamController<DmEvent>.broadcast();
  HubConnection? _connection;
  final Map<String, int> _pendingRead = {};
  Timer? _readTimer;

  static void attach(HubConnection connection) => instance._attach(connection);

  static void detach() => instance._detach();

  static void notifyReconnected() => instance._controller.add(const DmReconnectedEvent());

  @override
  Stream<DmEvent> get events => _controller.stream;

  void _attach(HubConnection connection) {
    _detach();
    _connection = connection;
    connection.on('DmMessage', (a) => _emit(a, _message));
    connection.on('DmRead', (a) => _emit(a, (m) => DmReadEvent(roomId: BuddyJson.str(m['roomId']), userId: BuddyJson.str(m['userId']), seq: BuddyJson.integer(m['seq']))));
    connection.on('DmRoomChanged', (a) => _emit(a, (m) => DmRoomChangedEvent(roomId: BuddyJson.str(m['roomId']), status: BuddyJson.str(m['status']), lock: BuddyJson.str(m['lock'], RoomLock.none))));
    connection.on('DmRoomSettings', (a) => _emit(a, (m) => DmRoomSettingsEvent(roomId: BuddyJson.str(m['roomId']), onlyOwnerSends: BuddyJson.boolean(m['onlyOwnerSends']), ownerName: BuddyJson.str(m['ownerName']))));
    connection.on('DmUnread', (a) => _emit(a, (m) => DmUnreadEvent(ChatUnread.fromJson(m))));
    connection.on('SessionEnded', (a) => _emit(a, (m) => DmSessionEndedEvent(BuddyJson.str(m['reason']))));
  }

  void _detach() {
    final c = _connection;
    _connection = null;
    _readTimer?.cancel();
    _readTimer = null;
    _pendingRead.clear();
    if (c == null) return;
    for (final e in _events) {
      c.off(e);
    }
  }

  static DmEvent _message(Map<String, dynamic> m) => DmMessageEvent(
        roomId: BuddyJson.str(m['roomId']),
        kind: BuddyJson.str(m['kind'], RoomKind.direct),
        roomStatus: BuddyJson.str(m['roomStatus'], RoomStatus.active),
        message: ChatMessageModel.fromJson(BuddyJson.map(m['message'])),
      );

  void _emit(List<Object?>? args, DmEvent Function(Map<String, dynamic>) parse) {
    if (args == null || args.isEmpty || args.first is! Map) return;
    try {
      _controller.add(parse(BuddyJson.map(args.first)));
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>?> send(String roomId, String clientMessageId, String text) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return null;
    try {
      final r = await c.invoke('DmSend', args: [roomId, clientMessageId, text]).timeout(sendTimeout);
      return r is Map ? BuddyJson.map(r) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void read(String roomId, int seq) {
    final had = _pendingRead[roomId] ?? 0;
    if (seq <= had) return;
    _pendingRead[roomId] = seq;
    _readTimer ??= Timer(readDebounce, _flushReads);
  }

  void _flushReads() {
    _readTimer = null;
    final c = _connection;
    final batch = Map<String, int>.from(_pendingRead);
    _pendingRead.clear();
    final live = c != null && c.state == HubConnectionState.Connected;
    for (final e in batch.entries) {
      if (live) {
        unawaited(c.send('DmRead', args: [e.key, e.value]).catchError((Object _) {}));
      } else {
        unawaited(const SocialChatApi().read(e.key, e.value).then((r) {
          if (r case BuddyOk(:final value)) _controller.add(DmUnreadEvent(value));
        }));
      }
    }
  }
}
