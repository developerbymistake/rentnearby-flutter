import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/question_template_model.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';

class ChatController extends GetxController {
  final conversations = <ConversationModel>[].obs;
  final conversationsLoading = false.obs;
  // Separate from conversationsLoading (which gates the initial-load shimmer) — this is for
  // the scroll-triggered "load next page" spinner at the bottom of an already-populated list.
  final loadingMoreConversations = false.obs;
  final hasMoreConversations = true.obs;
  static const _conversationsPageSize = 20;
  final unreadCount = 0.obs;

  final questionTemplates = <QuestionTemplateModel>[].obs;
  bool _templatesLoaded = false;

  // Broadcast points for ChatHubService — any currently-open conversation
  // screen listens to these via its own ever() worker, filtering by
  // conversationId, without needing a direct dependency on the hub service.
  final incomingMessage = Rxn<MessageModel>();
  final readEvent = Rxn<Map<String, dynamic>>();

  Future<void> loadConversations({bool forceRefresh = false}) async {
    if (conversationsLoading.value) return;
    conversationsLoading.value = true;
    try {
      final res = await ApiService.get('/chat/conversations',
          params: {'offset': 0, 'limit': _conversationsPageSize});
      final items = (res['data']['items'] as List)
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      conversations.value = items;
      hasMoreConversations.value = items.length >= _conversationsPageSize;
      _recomputeUnreadCount();
    } catch (_) {
    } finally {
      conversationsLoading.value = false;
    }
  }

  // Appends the next page. Offset is simply the number of conversations already loaded —
  // safe because this list is never sparse/filtered client-side (search filters the already
  // -loaded items in the UI layer, it doesn't remove them from this source list).
  Future<void> loadMoreConversations() async {
    if (conversationsLoading.value || loadingMoreConversations.value || !hasMoreConversations.value) return;
    loadingMoreConversations.value = true;
    try {
      final res = await ApiService.get('/chat/conversations',
          params: {'offset': conversations.length, 'limit': _conversationsPageSize});
      final items = (res['data']['items'] as List)
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      conversations.addAll(items);
      hasMoreConversations.value = items.length >= _conversationsPageSize;
    } catch (_) {
    } finally {
      loadingMoreConversations.value = false;
    }
  }

  Future<List<QuestionTemplateModel>> loadQuestionTemplates({bool forceRefresh = false}) async {
    if (_templatesLoaded && !forceRefresh) return questionTemplates;
    try {
      final res = await ApiService.get('/chat/question-templates');
      final items = (res['data'] as List)
          .map((e) => QuestionTemplateModel.fromJson(e as Map<String, dynamic>))
          .where((t) => t.isActive)
          .toList();
      questionTemplates.value = items;
      _templatesLoaded = true;
    } catch (_) {}
    return questionTemplates;
  }

  Future<ConversationModel?> createOrGetConversation(String listingType, String listingId) async {
    try {
      final res = await ApiService.post('/chat/conversations', {
        'listingType': listingType,
        'listingId': listingId,
      });
      final model = ConversationModel.fromJson(res['data'] as Map<String, dynamic>);
      if (!conversations.any((c) => c.id == model.id)) {
        conversations.insert(0, model);
      }
      return model;
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not start chat. Please try again.'));
      return null;
    }
  }

  Future<void> markRead(String conversationId) async {
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1 && conversations[index].unreadCount > 0) {
      // Optimistic — the badge should drop the moment the user opens the thread,
      // not wait on a round-trip.
      _recomputeUnreadCount(excludingConversationId: conversationId);
    }
    try {
      await ApiService.post('/chat/conversations/$conversationId/read', {});
      await loadConversations();
    } catch (_) {
      // Silent — marking read is a passive side-effect of opening a thread,
      // not a user-initiated action expecting feedback; the next successful
      // sync will catch it up.
    }
  }

  // Called by ChatHubService when a live "UnreadCountChanged" event arrives —
  // zero REST call, mirrors BannerController.applyFromPush.
  void applyUnreadCountChanged(String conversationId, int newUnreadCount) {
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final c = conversations[index];
      conversations[index] = ConversationModel(
        id: c.id, listingType: c.listingType, listingId: c.listingId,
        listingTitle: c.listingTitle, area: c.area, listingThumbnailUrl: c.listingThumbnailUrl,
        roomTypeId: c.roomTypeId, plotTypeId: c.plotTypeId,
        otherPartyId: c.otherPartyId, otherPartyName: c.otherPartyName,
        isOwner: c.isOwner, status: c.status, lastMessageAt: DateTime.now(),
        lastMessagePreview: c.lastMessagePreview, unreadCount: newUnreadCount,
      );
      conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    } else {
      loadConversations();
    }
    _recomputeUnreadCount();
  }

  // Called by ChatHubService on a live "MessageReceived" event — bumps the
  // conversation-list preview/timestamp immediately, and broadcasts the raw
  // message for whichever conversation screen (if any) is currently open.
  void applyIncomingMessage(Map<String, dynamic> data) {
    final message = MessageModel.fromJson(data);
    final index = conversations.indexWhere((c) => c.id == message.conversationId);
    if (index != -1) {
      final c = conversations[index];
      conversations[index] = ConversationModel(
        id: c.id, listingType: c.listingType, listingId: c.listingId,
        listingTitle: c.listingTitle, area: c.area, listingThumbnailUrl: c.listingThumbnailUrl,
        roomTypeId: c.roomTypeId, plotTypeId: c.plotTypeId,
        otherPartyId: c.otherPartyId, otherPartyName: c.otherPartyName,
        isOwner: c.isOwner, status: c.status, lastMessageAt: message.createdAt,
        // Falls back to the previous preview for message types without a plain 'text'
        // payload field (contact/schedule cards) — still correct, just not live-updating
        // for those specific types until the next full list reload.
        lastMessagePreview: message.payload['text'] as String? ?? c.lastMessagePreview,
        unreadCount: c.unreadCount,
      );
      conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    } else {
      loadConversations();
    }
    incomingMessage.value = message;
  }

  void applyMessagesRead(Map<String, dynamic> data) => readEvent.value = data;

  // ── Message history + sending ───────────────────────────────────────────

  Future<({List<MessageModel> items, String? status})> getMessages(String conversationId, {DateTime? before}) async {
    try {
      final res = await ApiService.get(
        '/chat/conversations/$conversationId/messages',
        params: before != null ? {'before': before.toIso8601String()} : null,
      );
      final items = (res['data']['items'] as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final status = res['data']['conversationStatus'] as String?;
      return (items: items, status: status);
    } catch (_) {
      return (items: <MessageModel>[], status: null);
    }
  }

  Future<MessageModel?> sendMessage(String conversationId, String type, Map<String, dynamic> payload, {String? respondsToMessageId}) async {
    try {
      final res = await ApiService.post('/chat/conversations/$conversationId/messages', {
        'type': type,
        'payloadJson': jsonEncode(payload),
        if (respondsToMessageId != null) 'respondsToMessageId': respondsToMessageId,
      });
      return MessageModel.fromJson({...res['data'] as Map<String, dynamic>, 'isMine': true});
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not send that. Please try again.'));
      return null;
    }
  }

  Future<MessageModel?> respondContact(String messageId, bool approve) async {
    try {
      final res = await ApiService.post('/chat/messages/$messageId/contact-response', {'approve': approve});
      return MessageModel.fromJson({...res['data'] as Map<String, dynamic>, 'isMine': true});
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not respond. Please try again.'));
      return null;
    }
  }

  Future<MessageModel?> respondSchedule(String messageId, String action, {List<DateTime>? proposedAts, DateTime? acceptedAt}) async {
    try {
      final body = <String, dynamic>{'action': action};
      if (proposedAts != null) body['proposedAts'] = proposedAts.map((d) => d.toIso8601String()).toList();
      if (acceptedAt != null) body['acceptedAt'] = acceptedAt.toIso8601String();
      final res = await ApiService.post('/chat/messages/$messageId/schedule-response', body);
      return MessageModel.fromJson({...res['data'] as Map<String, dynamic>, 'isMine': true});
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not respond. Please try again.'));
      return null;
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      await ApiService.post('/chat/users/$userId/block', {});
      return true;
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not block this user. Please try again.'));
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      await ApiService.post('/chat/users/$userId/unblock', {});
      return true;
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not unblock this user. Please try again.'));
      return false;
    }
  }

  void _recomputeUnreadCount({String? excludingConversationId}) {
    unreadCount.value = conversations
        .where((c) => c.id != excludingConversationId)
        .fold(0, (sum, c) => sum + c.unreadCount);
  }

  static String _errorMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final status = e.response?.statusCode;
      String? message;

      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        message = responseData['error']?['message'] as String? ??
                  responseData['message'] as String?;
      } else if (responseData is String) {
        message = responseData;
      }

      if (status == 400 && message != null) return message;
      if (status == 403 && message != null) return message;
      if (status == 429) return 'Too many attempts. Please try again later.';
      if (status != null && status >= 500) return 'Server error. Please try again.';
      if (message != null) return message;
    }
    return fallback;
  }
}
