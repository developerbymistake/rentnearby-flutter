import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import 'storage_service.dart';

/// Independent of BannerHubService — new file, no shared code, mirrors its
/// connection mechanics only. Deliberately LAZY (unlike BannerHubService's
/// always-on-while-browsing trigger): the caller (Chats-list screen or a
/// specific conversation screen) explicitly connects on open and disconnects
/// on close, instead of staying connected for the whole app session.
class ChatHubService extends GetxService {
  static ChatHubService get to => Get.find();

  HubConnection? _connection;
  String? _activeConversationId;

  /// Pass [conversationId] when opening a specific thread (joins that
  /// conversation's group in addition to the always-joined per-user group on
  /// the server side); omit it when only the Chats list is open.
  Future<void> connect({String? conversationId}) async {
    final chatCtrl = Get.find<ChatController>();

    if (_connection?.state == HubConnectionState.Connected &&
        _activeConversationId == conversationId) {
      return;
    }

    await disconnect();

    if (StorageService.getToken() == null) return;

    final query = conversationId != null ? '?conversationId=$conversationId' : '';
    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConstants.serverUrl}/hubs/chat$query',
          options: HttpConnectionOptions(
            // Always reads fresh token — handles JWT refresh correctly
            accessTokenFactory: () async => StorageService.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect()
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

    _connection!.onreconnected(({String? connectionId}) {
      chatCtrl.loadConversations();
    });

    try {
      await _connection!.start();
      _activeConversationId = conversationId;
    } catch (_) {
      // Connection failed — conversation screens still work via plain REST
      // (GetMessages on open), so there's nothing further to fall back to here.
      _connection = null;
    }
  }

  Future<void> disconnect() async {
    try {
      _connection?.off('MessageReceived');
      _connection?.off('UnreadCountChanged');
      _connection?.off('MessagesRead');
      _connection?.off('ConversationStatusChanged');
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    _activeConversationId = null;
  }
}
