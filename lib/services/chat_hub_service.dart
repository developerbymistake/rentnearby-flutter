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
        // Same "compare against my own logged-in id" pattern MessageReceived already uses for
        // isMine — the push only carries WHO did the blocking; each recipient derives their
        // own direction from it, since Status alone is a symmetric string.
        final myId = Get.find<AuthController>().user.value?.id;
        final blockedByUserId = data['blockedByUserId'] as String?;
        final isBlockedByMe = myId != null && blockedByUserId == myId;
        chatCtrl.applyConversationStatusChanged(
          data['conversationId'] as String,
          data['status'] as String,
          isBlockedByMe: isBlockedByMe,
        );
      } catch (_) {}
    });

    _connection!.onreconnected(({String? connectionId}) async {
      // Preserves however many pages the Chats list had already scrolled through instead of
      // silently snapping it back to a fresh 20-item page 1 on every brief network blip.
      chatCtrl.reloadPreservingPages();
      // SignalR's automatic-reconnect gets a brand-new server-side ConnectionId — every
      // group membership from before (including any joined conversation) is gone and must
      // be explicitly redone, or the open conversation screen goes silently live-mute after
      // any brief network blip with no visible error.
      await _reconcileGroupMembership();
      chatCtrl.notifyHubReconnected();
    });

    try {
      await _connection!.start();
      // Covers the very-first-connect / cold-start case: if a conversation screen called
      // joinConversation() while this connection was still being established, the desired
      // state (_activeConversationId) was already recorded — this is what turns it into an
      // actual server-side join now that we're Connected, without waiting for some future
      // reconnect event.
      await _reconcileGroupMembership();
    } catch (_) {
      // Connection failed — conversation screens still work via plain REST
      // (GetMessages on open), so there's nothing further to fall back to here.
      _connection = null;
    }
  }

  /// The single place that ever invokes the server-side JoinConversation. Reads
  /// _activeConversationId ("desired state" — which conversation the user wants to be
  /// in, set synchronously by joinConversation() below regardless of connection state) and,
  /// if set and the connection is actually Connected right now, tells the server. Safe to
  /// call redundantly/repeatedly — ChatHub.JoinConversation's Groups.AddToGroupAsync on an
  /// already-joined group is a no-op. Called from every point this connection reaches
  /// Connected (right after the initial start(), on every onreconnected, and opportunistically
  /// from joinConversation() itself) so "desired" and "actual" state can never drift apart
  /// for longer than it takes the connection to come back up.
  Future<void> _reconcileGroupMembership() async {
    final active = _activeConversationId;
    if (active == null) return;
    if (_connection?.state != HubConnectionState.Connected) return;
    try {
      await _connection!.invoke('JoinConversation', args: [active]);
    } catch (_) {}
  }

  /// Pass when opening a specific conversation screen. Records the desired state
  /// immediately and unconditionally — BEFORE touching the connection at all — then
  /// reconciles against whatever the actual connection state happens to be. If already
  /// Connected (the common case) this joins the server group right away; if the connection
  /// is mid-connect/reconnecting at this exact moment, this call's own reconcile is a no-op,
  /// but _activeConversationId is now correctly set so the next `start()`-succeeded or
  /// onreconnected reconcile picks it up instead of having nothing to act on — this is what
  /// closes the old race where a connection blip at exactly the wrong moment left the
  /// conversation's group membership never (re)established for the rest of the screen visit.
  Future<void> joinConversation(String conversationId) async {
    _activeConversationId = conversationId;
    await connect();
    await _reconcileGroupMembership();
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
