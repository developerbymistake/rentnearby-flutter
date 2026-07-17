import 'package:get/get.dart';
import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import 'storage_service.dart';

/// The package's own DefaultRetryPolicy always appends a final `null` delay even when given
/// a custom retryDelays list — meaning it always eventually gives up permanently, going
/// Disconnected with nothing to bring it back except the next app-resume/screen-open call to
/// connect(). A real chat client shouldn't need the user to background-and-resume the app
/// just to recover from an extended rough patch of network — this never returns null, so
/// the connection keeps retrying (capped backoff) indefinitely instead of ever giving up.
class _ChatReconnectPolicy implements IRetryPolicy {
  static const _delaysMs = [0, 2000, 5000, 10000, 15000, 30000];

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) {
    final i = retryContext.previousRetryCount;
    return i < _delaysMs.length ? _delaysMs[i] : _delaysMs.last;
  }
}

/// One persistent connection for the whole chat feature's session lifetime — established
/// once (see MainScreen) and kept alive until logout, never torn down just because a
/// conversation screen opened or closed. Conversation-level group membership moves via
/// JoinConversation/LeaveConversation hub-method invocations on this SAME connection (see
/// ChatConversationScreen), not by reconnecting with a different query string — tearing
/// the whole connection down and rebuilding it per screen was the root cause of chat going
/// silently live-mute for the rest of a session the moment any one conversation had been
/// opened and closed once.
class ChatHubService extends GetxService {
  static ChatHubService get to => Get.find();

  HubConnection? _connection;
  Future<void>? _connecting;
  // Only one conversation is assumed "active" at a time (matches this app's normal usage —
  // one conversation screen open at once) — if it's ever pushed on top of another without
  // the first disposing, only the most-recently-joined one gets restored after a reconnect.
  String? _activeConversationId;

  /// Single-flight: concurrent callers (e.g. MainScreen.initState() and a fast-tapped
  /// conversation open racing it) await the same in-flight attempt instead of each building
  /// and starting their own HubConnection — this is what removes the race condition the old
  /// per-screen connect() had.
  Future<void> connect() {
    if (_connection?.state == HubConnectionState.Connected) return Future.value();
    return _connecting ??= _doConnect().whenComplete(() => _connecting = null);
  }

  Future<void> _doConnect() async {
    final chatCtrl = Get.find<ChatController>();

    if (StorageService.getToken() == null) return;

    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConstants.serverUrl}/hubs/chat',
          options: HttpConnectionOptions(
            // Always reads fresh token — handles JWT refresh correctly
            accessTokenFactory: () async => StorageService.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect(reconnectPolicy: _ChatReconnectPolicy())
        .build();

    _connection!.on('MessageReceived', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        // The hub always pushes isMine=false (it can't know which connected
        // client is "me") — recompute it against our own logged-in user id
        // rather than trusting that literal value.
        final myId = Get.find<AuthController>().user.value?.id;
        data['isMine'] = myId != null && data['senderId'] == myId;
        chatCtrl.applyIncomingMessage(data);
      } catch (_) {}
    });

    _connection!.on('MessageUpdated', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final myId = Get.find<AuthController>().user.value?.id;
        data['isMine'] = myId != null && data['senderId'] == myId;
        chatCtrl.applyMessageUpdated(data);
      } catch (_) {}
    });

    _connection!.on('UnreadCountChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = args[0] as Map<String, dynamic>;
        chatCtrl.applyUnreadCountChanged(data['conversationId'] as String, (data['unreadCount'] as num).toInt());
      } catch (_) {}
    });

    _connection!.on('MessagesRead', (args) {
      if (args == null || args.isEmpty) return;
      try {
        chatCtrl.applyMessagesRead(args[0] as Map<String, dynamic>);
      } catch (_) {}
    });

    _connection!.on('ConversationStatusChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        chatCtrl.applyConversationStatusChanged(data['conversationId'] as String, data['status'] as String);
      } catch (_) {}
    });

    _connection!.onreconnected(({String? connectionId}) async {
      chatCtrl.loadConversations();
      // SignalR's automatic-reconnect gets a brand-new server-side ConnectionId — every
      // group membership from before (including any joined conversation) is gone and must
      // be explicitly redone, or the open conversation screen goes silently live-mute after
      // any brief network blip with no visible error.
      final active = _activeConversationId;
      if (active != null) {
        try {
          await _connection!.invoke('JoinConversation', args: [active]);
        } catch (_) {}
      }
      chatCtrl.notifyHubReconnected();
    });

    try {
      await _connection!.start();
    } catch (_) {
      // Connection failed — conversation screens still work via plain REST
      // (GetMessages on open), so there's nothing further to fall back to here.
      _connection = null;
    }
  }

  /// Pass when opening a specific conversation screen — joins its live-broadcast group on
  /// the existing connection (connecting first if this is the very first chat interaction
  /// this session). Never rebuilds/reconnects.
  Future<void> joinConversation(String conversationId) async {
    await connect();
    if (_connection?.state != HubConnectionState.Connected) return;
    try {
      await _connection!.invoke('JoinConversation', args: [conversationId]);
      _activeConversationId = conversationId;
    } catch (_) {}
  }

  Future<void> leaveConversation(String conversationId) async {
    if (_activeConversationId == conversationId) _activeConversationId = null;
    if (_connection?.state != HubConnectionState.Connected) return;
    try {
      await _connection!.invoke('LeaveConversation', args: [conversationId]);
    } catch (_) {}
  }

  /// Only called from logout/account-deletion now — opening/closing a conversation screen
  /// no longer tears the connection down (see joinConversation/leaveConversation above).
  Future<void> disconnect() async {
    try {
      _connection?.off('MessageReceived');
      _connection?.off('MessageUpdated');
      _connection?.off('UnreadCountChanged');
      _connection?.off('MessagesRead');
      _connection?.off('ConversationStatusChanged');
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    _connecting = null;
    _activeConversationId = null;
  }
}
