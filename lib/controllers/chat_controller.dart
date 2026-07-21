import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/question_template_model.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';
import '../utils/dio_error_mapper.dart';

class ChatController extends GetxController {
  final conversations = <ConversationModel>[].obs;
  final conversationsLoading = false.obs;
  // Separate from conversationsLoading (which gates the initial-load shimmer) — this is for
  // the scroll-triggered "load next page" spinner at the bottom of an already-populated list.
  final loadingMoreConversations = false.obs;
  final hasMoreConversations = true.obs;
  static const _conversationsPageSize = 20;

  // Server-authoritative total unread across ALL conversations (drives the Home header badge).
  // Never derived by summing the loaded `conversations` list — that list is paginated
  // (page size 20), so a local sum silently under-counts whenever an unread conversation
  // sits beyond the loaded pages. Instead the total is anchored to GET /chat/unread-count
  // at every drift-prone moment (app start, app resume, hub reconnect) and adjusted in
  // between only by paths that know an exact per-conversation delta (mark-read, live
  // UnreadCountChanged pushes).
  final unreadCount = 0.obs;

  // Race guards for fetchUnreadCount(): only the newest in-flight fetch may apply its
  // result (sequence number), and a precise delta landing while a fetch is in flight
  // schedules one follow-up fetch — the server total was computed concurrently, so it may
  // or may not already include that delta's change depending on request ordering.
  int _unreadFetchSeq = 0;
  bool _unreadFetchInFlight = false;
  bool _unreadDeltaDuringFetch = false;

  final questionTemplates = <QuestionTemplateModel>[].obs;
  bool _templatesLoaded = false;

  // Broadcast points for ChatHubService — any currently-open conversation
  // screen listens to these via its own ever() worker, filtering by
  // conversationId, without needing a direct dependency on the hub service.
  final incomingMessage = Rxn<MessageModel>();
  final messageUpdated = Rxn<MessageModel>();
  final readEvent = Rxn<Map<String, dynamic>>();
  final conversationStatusChanged = Rxn<Map<String, dynamic>>();
  // Bumped (to the current instant, always a fresh value so ever() reliably refires) every
  // time ChatHubService's connection comes back from a drop — a currently-open conversation
  // screen uses this to fetch anything it missed while offline via getMessages(after: ...).
  final hubReconnected = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    // App-start anchor — makes the badge exact before (and independent of) the first
    // conversations-list load, which only ever covers page 1.
    fetchUnreadCount();
  }

  // Anchors unreadCount to the server's total (GET /chat/unread-count — a single cheap SUM
  // across every conversation the user is in). Call sites: onInit (app start), app resume
  // (main_screen.dart), hub reconnect (chat_hub_service.dart — pushes missed while
  // disconnected are the one drift source the delta paths can't cover), and
  // applyUnreadCountChanged's not-loaded branch (no precise delta is knowable there).
  Future<void> fetchUnreadCount() async {
    final seq = ++_unreadFetchSeq;
    _unreadFetchInFlight = true;
    _unreadDeltaDuringFetch = false;
    try {
      final res = await ApiService.get('/chat/unread-count');
      final total = (res['data']?['count'] as num?)?.toInt() ?? 0;
      if (seq != _unreadFetchSeq) return; // superseded by a newer fetch — let that one win
      unreadCount.value = total;
      if (_unreadDeltaDuringFetch) {
        // A delta landed mid-flight; the total above may predate it. Re-anchor once so the
        // value converges instead of a stale server snapshot silently clobbering the delta.
        _unreadDeltaDuringFetch = false;
        unawaited(fetchUnreadCount());
      }
    } catch (_) {
      // Best-effort — the badge keeps its last-known value (deltas still apply on top),
      // and the next sync point re-anchors it.
    } finally {
      if (seq == _unreadFetchSeq) _unreadFetchInFlight = false;
    }
  }

  // The only way the total moves between server anchors — callers must pass an EXACT
  // per-conversation delta (old row count vs new), never a guess.
  void _applyUnreadDelta(int delta) {
    if (delta == 0) return;
    final next = unreadCount.value + delta;
    unreadCount.value = next < 0 ? 0 : next;
    if (_unreadFetchInFlight) _unreadDeltaDuringFetch = true;
  }

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
      // Deliberately does NOT touch unreadCount — this page-1 load sees at most 20
      // conversations, and summing a partial list is exactly the under-count
      // fetchUnreadCount() exists to prevent.
    } catch (_) {
    } finally {
      conversationsLoading.value = false;
    }
  }

  // Re-fetches page 1 through however many conversations were already loaded, in one call
  // (server already supports an arbitrary limit up to 100), instead of always resetting to a
  // single fresh 20-item page 1 like loadConversations() does. Used specifically for a
  // SignalR reconnect — the old behavior silently snapped a scrolled-down Chats list back to
  // the top on every brief network blip, discarding everything past page 1.
  Future<void> reloadPreservingPages() async {
    if (conversationsLoading.value) return;
    // Clamped to 100 to match the server's own Math.Clamp(limit, 1, 100) — beyond that,
    // comparing items.length >= targetCount below would never be true even when there
    // genuinely is more, since the server silently caps its response regardless of what
    // limit was requested.
    final targetCount = conversations.length < _conversationsPageSize
        ? _conversationsPageSize
        : conversations.length.clamp(_conversationsPageSize, 100);
    conversationsLoading.value = true;
    try {
      final res = await ApiService.get('/chat/conversations',
          params: {'offset': 0, 'limit': targetCount});
      final items = (res['data']['items'] as List)
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      conversations.value = items;
      hasMoreConversations.value = items.length >= targetCount;
      // No unreadCount recompute here either — the reconnect path that calls this also
      // calls fetchUnreadCount(), which anchors the total properly.
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

  // Keyed by "listingType:listingId" — a second call for the same listing while one is
  // already in flight (e.g. a double-tap on "Chat" before the first request resolves) awaits
  // the same Future instead of firing a duplicate POST and, more importantly, a duplicate
  // Get.toNamed push from the caller. The backend's own unique-index race handling already
  // guarantees both requests would resolve to the same conversation anyway — this just stops
  // the screen from being pushed twice.
  final _pendingConversationRequests = <String, Future<ConversationModel?>>{};

  Future<ConversationModel?> createOrGetConversation(String listingType, String listingId) {
    final key = '$listingType:$listingId';
    final pending = _pendingConversationRequests[key];
    if (pending != null) return pending;

    final future = _createOrGetConversation(listingType, listingId).whenComplete(() {
      _pendingConversationRequests.remove(key);
    });
    _pendingConversationRequests[key] = future;
    return future;
  }

  Future<ConversationModel?> _createOrGetConversation(String listingType, String listingId) async {
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
      AppToast.error(DioErrorMapper.toMessage(
        e,
        'Could not start chat. Please try again.',
        showRawMessageForStatusCodes: const {400, 403},
      ));
      return null;
    }
  }

  Future<void> markRead(String conversationId) async {
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1 && conversations[index].unreadCount > 0) {
      // Optimistic — the badge should drop the moment the user opens the thread, not wait on
      // a round-trip. Previously this only recomputed the aggregate tab-badge count, leaving
      // this specific row's own badge/bold-name stale until loadConversations() resolved —
      // zeroing the row itself here (same immutable-reconstruction shape
      // applyUnreadCountChanged already uses) is what actually makes it optimistic.
      final c = conversations[index];
      conversations[index] = ConversationModel(
        id: c.id, listingType: c.listingType, listingId: c.listingId,
        listingTitle: c.listingTitle, area: c.area, listingThumbnailUrl: c.listingThumbnailUrl,
        roomTypeId: c.roomTypeId, plotTypeId: c.plotTypeId,
        otherPartyId: c.otherPartyId, otherPartyName: c.otherPartyName,
        isOwner: c.isOwner, status: c.status, isBlockedByMe: c.isBlockedByMe, lastMessageAt: c.lastMessageAt,
        lastMessagePreview: c.lastMessagePreview, unreadCount: 0,
      );
      // Exact delta: this row held `c.unreadCount` and was just zeroed. The server's own
      // mark-read push (UnreadCountChanged to user_{id}) then confirms via
      // applyUnreadCountChanged — consistent, because the row is already 0 by then.
      _applyUnreadDelta(-c.unreadCount);
    }
    try {
      await ApiService.post('/chat/conversations/$conversationId/read', {});
      await loadConversations();
    } catch (_) {
      // The optimistic zero above already reflects what SHOULD be true — if the POST
      // actually failed to even reach the server, retry once in the background rather than
      // silently leaving the row wrong until some unrelated future sync happens to correct
      // it. If the POST actually succeeded server-side and only this response was lost, the
      // backend's own MarkRead now also pushes a live UnreadCountChanged event (reaching
      // this exact conversation's row via applyUnreadCountChanged), so this reconciles
      // either way.
      unawaited(loadConversations());
    }
  }

  // Called by ChatHubService when a live "UnreadCountChanged" event arrives —
  // zero REST call, mirrors BannerController.applyFromPush.
  void applyUnreadCountChanged(String conversationId, int newUnreadCount) {
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final c = conversations[index];
      // Exact delta: the push carries this conversation's authoritative new count, and we
      // know what the row held locally — the total moves by precisely the difference.
      final oldUnreadCount = c.unreadCount;
      conversations[index] = ConversationModel(
        id: c.id, listingType: c.listingType, listingId: c.listingId,
        listingTitle: c.listingTitle, area: c.area, listingThumbnailUrl: c.listingThumbnailUrl,
        roomTypeId: c.roomTypeId, plotTypeId: c.plotTypeId,
        otherPartyId: c.otherPartyId, otherPartyName: c.otherPartyName,
        isOwner: c.isOwner, status: c.status, isBlockedByMe: c.isBlockedByMe, lastMessageAt: DateTime.now(),
        lastMessagePreview: c.lastMessagePreview, unreadCount: newUnreadCount,
      );
      conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      _applyUnreadDelta(newUnreadCount - oldUnreadCount);
    } else {
      // Conversation isn't in the loaded pages — no local row, so no precise delta is
      // knowable. Reload the list for the row AND re-anchor the total from the server.
      loadConversations();
      fetchUnreadCount();
    }
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
        isOwner: c.isOwner, status: c.status, isBlockedByMe: c.isBlockedByMe, lastMessageAt: message.createdAt,
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

  // Called by ChatHubService on a live "MessageUpdated" event — an EXISTING message's state
  // changed (e.g. a schedule proposal marked "superseded" by a counter-offer), not a new
  // unread item, so this never touches the conversation list's preview/unread count —
  // only broadcasts for whichever conversation screen (if any) is currently open to swap
  // the matching message in place.
  void applyMessageUpdated(Map<String, dynamic> data) => messageUpdated.value = MessageModel.fromJson(data);

  void notifyHubReconnected() => hubReconnected.value = DateTime.now();

  // Called by ChatHubService on a live "ConversationStatusChanged" event (block/unblock by
  // either party) — updates the Chats-list row's status immediately (drives the dimmed
  // avatar/block badge in chats_list_screen.dart) and broadcasts for whichever conversation
  // screen (if any) is currently open, same two-surface shape as applyIncomingMessage.
  // isBlockedByMe is pre-computed by ChatHubService (which already compares the push's
  // blockedByUserId against the logged-in user's own id, the same place isMine is derived
  // for incoming messages) — only meaningful when status == 'Blocked'.
  void applyConversationStatusChanged(String conversationId, String status, {bool isBlockedByMe = false}) {
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final c = conversations[index];
      conversations[index] = ConversationModel(
        id: c.id, listingType: c.listingType, listingId: c.listingId,
        listingTitle: c.listingTitle, area: c.area, listingThumbnailUrl: c.listingThumbnailUrl,
        roomTypeId: c.roomTypeId, plotTypeId: c.plotTypeId,
        otherPartyId: c.otherPartyId, otherPartyName: c.otherPartyName,
        isOwner: c.isOwner, status: status, isBlockedByMe: isBlockedByMe, lastMessageAt: c.lastMessageAt,
        lastMessagePreview: c.lastMessagePreview, unreadCount: c.unreadCount,
      );
    }
    conversationStatusChanged.value = {'conversationId': conversationId, 'status': status, 'isBlockedByMe': isBlockedByMe};
  }

  // ── Message history + sending ───────────────────────────────────────────

  // Pass exactly one of before/after — before is normal backward history-scrolling, after is
  // the reconnect catch-up path ("everything since the last message I already have"). hasMore
  // is true when this page was full-length (server-side heuristic, same one the conversations-
  // list pagination already uses) — drives both load-older-on-scroll-to-top and looping the
  // reconnect catch-up until it's genuinely caught up, not just fetched one page of the gap.
  Future<({List<MessageModel> items, String? status, bool hasMore})> getMessages(String conversationId, {DateTime? before, DateTime? after}) async {
    assert(before == null || after == null, 'Pass either before or after, not both');
    try {
      final params = <String, dynamic>{};
      if (before != null) params['before'] = before.toIso8601String();
      if (after != null) params['after'] = after.toIso8601String();
      final res = await ApiService.get(
        '/chat/conversations/$conversationId/messages',
        params: params.isEmpty ? null : params,
      );
      final items = (res['data']['items'] as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final status = res['data']['conversationStatus'] as String?;
      final hasMore = res['data']['hasMore'] as bool? ?? false;
      return (items: items, status: status, hasMore: hasMore);
    } catch (_) {
      return (items: <MessageModel>[], status: null, hasMore: false);
    }
  }

  // clientMessageId: pass for a fresh send only (never alongside respondsToMessageId, which
  // already has its own server-side dedup) — one id generated per compose-attempt by the
  // caller, so a genuinely-concurrent double-invocation of the same attempt (e.g. a fast
  // double-tap landing before a sheet visually dismisses) collapses to the one message the
  // server actually created instead of a real duplicate.
  Future<MessageModel?> sendMessage(String conversationId, String type, Map<String, dynamic> payload, {String? respondsToMessageId, String? clientMessageId}) async {
    try {
      final res = await ApiService.post('/chat/conversations/$conversationId/messages', {
        'type': type,
        'payloadJson': jsonEncode(payload),
        if (respondsToMessageId != null) 'respondsToMessageId': respondsToMessageId,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
      });
      return MessageModel.fromJson({...res['data'] as Map<String, dynamic>, 'isMine': true});
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(
        e,
        'Could not send that. Please try again.',
        showRawMessageForStatusCodes: const {400, 403},
      ));
      return null;
    }
  }

  Future<MessageModel?> respondContact(String messageId, bool approve) async {
    try {
      final res = await ApiService.post('/chat/messages/$messageId/contact-response', {'approve': approve});
      return MessageModel.fromJson({...res['data'] as Map<String, dynamic>, 'isMine': true});
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(
        e,
        'Could not respond. Please try again.',
        showRawMessageForStatusCodes: const {400, 403},
      ));
      return null;
    }
  }

  Future<MessageModel?> respondSchedule(String messageId, String action, {List<DateTime>? proposedAts, DateTime? acceptedAt}) async {
    try {
      final body = <String, dynamic>{'action': action};
      if (proposedAts != null) body['proposedAts'] = proposedAts.map((d) => d.toUtc().toIso8601String()).toList();
      if (acceptedAt != null) body['acceptedAt'] = acceptedAt.toUtc().toIso8601String();
      final res = await ApiService.post('/chat/messages/$messageId/schedule-response', body);
      return MessageModel.fromJson({...res['data'] as Map<String, dynamic>, 'isMine': true});
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(
        e,
        'Could not respond. Please try again.',
        showRawMessageForStatusCodes: const {400, 403},
      ));
      return null;
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      await ApiService.post('/chat/users/$userId/block', {});
      return true;
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(
        e,
        'Could not block this user. Please try again.',
        showRawMessageForStatusCodes: const {400, 403},
      ));
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      await ApiService.post('/chat/users/$userId/unblock', {});
      return true;
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(
        e,
        'Could not unblock this user. Please try again.',
        showRawMessageForStatusCodes: const {400, 403},
      ));
      return false;
    }
  }
}
