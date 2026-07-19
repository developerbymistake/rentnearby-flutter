import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../config/app_colors.dart';
import '../controllers/chat_controller.dart';
import '../models/message_model.dart';
import '../models/question_template_model.dart';
import '../services/chat_hub_service.dart';
import '../services/notification_service.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_next_slot_bubble.dart';
import '../widgets/chat_plus_menu_sheet.dart';
import '../widgets/chat_schedule_picker_sheet.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({super.key});
  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver {
  final _chatCtrl = Get.find<ChatController>();

  late final String _conversationId;
  late final String _listingType;
  late final String? _roomTypeId;
  late final String? _plotTypeId;
  late final String _otherPartyId;
  late final String _otherPartyName;
  late final String _listingTitle;
  late final String? _area;
  late final bool _isOwner;
  final _status = ''.obs;

  final _messages = <MessageModel>[].obs;
  final _loading = true.obs;
  // Older-history paging (scroll-to-top). _hasMoreOlder starts true (optimistic — we don't
  // know yet) and is only ever authoritatively set from _loadHistory's FIRST load; a later
  // pull-to-refresh only re-fetches page 1 and must not clobber what's already been
  // established about whether older history exists beyond it.
  final _loadingOlder = false.obs;
  final _hasMoreOlder = true.obs;
  // Dims the inline "next slot" bubble and disables its tap while a plus-menu send (question/
  // contact-request/schedule-proposal) is in flight — this one IS single-flight, since _send()
  // is the only caller and it's always awaited sequentially. Responding to an EXISTING message
  // (answer/approve/decline/accept/counter) is a separate action space with its own per-message
  // guard below (_pendingActionMessageIds) — those can legitimately overlap with a plus-menu
  // send or with each other on different messages, so one shared flag isn't enough for them.
  final _sending = false.obs;
  // Guards _openPlusMenu's async gap (the retry fetch below) against a rapid double-tap
  // opening ChatPlusMenuSheet twice — ChatPlusMenuSheet.show has no built-in re-entrancy
  // guard of its own (plain showModalBottomSheet), and unlike _sending this isn't tied to
  // a send actually being in flight, so it needs its own flag.
  bool _openingPlusMenu = false;
  // Keyed by the ORIGINAL message being responded to (the question/contact-request/schedule-
  // proposal id), not the not-yet-created response — this is exactly the id _buildBubble()
  // already keys its per-message callback wiring off. A message id present here means an
  // answer/response to it is currently in flight; every action method below adds its target's
  // id on entry and removes it in a finally, so a double-tap on the same message's button is a
  // no-op instead of firing a second request or (for quick_reply answers specifically) losing
  // the "paired under its question" render slot to an orphan duplicate.
  final _pendingActionMessageIds = <String>{}.obs;
  final _scrollCtrl = ScrollController();
  Worker? _incomingWorker;
  Worker? _readWorker;
  Worker? _statusWorker;
  Worker? _messageUpdatedWorker;
  Worker? _reconnectWorker;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _conversationId = args['conversationId'] as String;
    _listingType = args['listingType'] as String;
    _roomTypeId = args['roomTypeId'] as String?;
    _plotTypeId = args['plotTypeId'] as String?;
    _otherPartyId = args['otherPartyId'] as String? ?? '';
    _otherPartyName = args['otherPartyName'] as String? ?? 'User';
    _listingTitle = args['listingTitle'] as String? ?? '';
    _area = args['area'] as String?;
    _isOwner = args['isOwner'] as bool? ?? false;
    _status.value = args['status'] as String? ?? 'Active';

    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
    _loadHistory();
    ChatHubService.to.joinConversation(_conversationId);
    _chatCtrl.markRead(_conversationId);
    _chatCtrl.loadQuestionTemplates();
    // Runs regardless of how this screen was reached (notification tap or a plain manual
    // tap from the Chats list) — the one place that reliably fires every time this
    // conversation is actually opened, so a message already read in-app never resurfaces
    // stacked under a future chat notification for this same thread.
    NotificationService.to.dismissChatNotification(_conversationId);

    _incomingWorker = ever<MessageModel?>(_chatCtrl.incomingMessage, (m) {
      if (m == null || m.conversationId != _conversationId || !mounted) return;
      _insertIfNew(m);
      // The backend pushes this echo to the sender's own SignalR connection before the
      // sender's own REST call returns — so for our own messages, this is usually the
      // *first* confirmation of delivery, arriving before _send()'s finally block. Clear
      // the ghost's disabled state here too instead of only on the slower REST path, or
      // it stays visibly disabled for a beat after the message has already gone through.
      if (m.isMine && _sending.value) _sending.value = false;
      if (!m.isMine) _chatCtrl.markRead(_conversationId);
    });

    _readWorker = ever<Map<String, dynamic>?>(_chatCtrl.readEvent, (data) {
      if (data == null || !mounted) return;
      if (data['conversationId'] != _conversationId) return;
      // Only the OTHER party's read counts — our own markRead() call (fired on open and on
      // every incoming message above) broadcasts this same event back to our own open screen
      // too, since both sides share the conversation_{id} SignalR group.
      if (data['readByUserId'] != _otherPartyId) return;
      final now = DateTime.now();
      _messages.value = _messages
          .map(
            (m) => (m.isMine && m.readAt == null) ? m.copyWith(readAt: now) : m,
          )
          .toList();
    });

    // Live block/unblock by either party — reaches this device too when it's the one that
    // just blocked/unblocked (harmless, same value it already set optimistically), since both
    // sides share the conversation_{id} SignalR group while this screen is open.
    _statusWorker = ever<Map<String, dynamic>?>(_chatCtrl.conversationStatusChanged, (data) {
      if (data == null || !mounted) return;
      if (data['conversationId'] != _conversationId) return;
      _status.value = data['status'] as String;
    });

    // Live "MessageUpdated" — an EXISTING message's state changed (e.g. a schedule proposal
    // marked "superseded" by a counter-offer) rather than a new one arriving. Without this,
    // the superseded card stayed looking pending/actionable until the screen was reopened.
    _messageUpdatedWorker = ever<MessageModel?>(_chatCtrl.messageUpdated, (m) {
      if (m == null || m.conversationId != _conversationId || !mounted) return;
      final idx = _messages.indexWhere((x) => x.id == m.id);
      if (idx != -1) _messages[idx] = m;
    });

    // SignalR's automatic-reconnect gets a brand-new connection id, so anything sent by the
    // other party during the drop was missed entirely by this screen (not just delayed) —
    // catch up on exactly what was missed instead of waiting for a manual reopen.
    _reconnectWorker = ever<DateTime?>(_chatCtrl.hubReconnected, (_) => _catchUpAfterReconnect());
  }

  Future<void> _catchUpAfterReconnect() async {
    if (!mounted || _messages.isEmpty) return;
    final anchor = _messages.last.createdAt;
    var result = await _chatCtrl.getMessages(_conversationId, after: anchor);
    if (!mounted) return;
    for (final m in result.items.reversed) {
      _insertIfNew(m);
    }
    // The 'after' page only returns the NEWEST slice of what was missed (see
    // MessageRepository.GetPagedForConversationAsync's own doc comment) — if it was a full
    // page, there's likely an older portion of the gap still missing, closer to `anchor`.
    // Walk backward with `before` from this batch's oldest item until either the server says
    // there's no more (hasMore false) or we've reached back to already-known territory (the
    // cursor drops to/before anchor), bounded by a safety cap so a pathological gap can't
    // loop forever. Without this loop, a disconnect spanning more than one page permanently
    // stranded the older portion of the gap — the exact bug this fix closes.
    var guard = 0;
    while (result.hasMore && result.items.isNotEmpty && guard++ < 50) {
      final cursor = result.items.last.createdAt; // oldest item of the batch just fetched
      if (!cursor.isAfter(anchor)) break; // already back to known territory
      result = await _chatCtrl.getMessages(_conversationId, before: cursor);
      if (!mounted) return;
      for (final m in result.items.reversed) {
        _insertIfNew(m);
      }
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <= 150 && !_loadingOlder.value && _hasMoreOlder.value) {
      _loadOlderHistory();
    }
  }

  // Prepends older history without a visible scroll jump — the standard technique for a
  // plain (non-reversed) ListView: capture the scroll extent before the list grows, then in
  // a post-frame callback (after the new items have actually been laid out) jump by exactly
  // how much the extent changed, landing the viewport on the same content the user was
  // looking at rather than at the new top.
  Future<void> _loadOlderHistory() async {
    if (_loadingOlder.value || !_hasMoreOlder.value || _messages.isEmpty) return;
    _loadingOlder.value = true;
    try {
      final oldExtent = _scrollCtrl.hasClients ? _scrollCtrl.position.maxScrollExtent : 0.0;
      final result = await _chatCtrl.getMessages(_conversationId, before: _messages.first.createdAt);
      if (!mounted) return;
      _hasMoreOlder.value = result.hasMore;
      if (result.items.isEmpty) return;
      final existingIds = _messages.map((m) => m.id).toSet();
      final older = result.items.reversed.where((m) => !existingIds.contains(m.id)).toList();
      if (older.isEmpty) return;
      _messages.value = [...older, ..._messages];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollCtrl.hasClients) return;
        final delta = _scrollCtrl.position.maxScrollExtent - oldExtent;
        _scrollCtrl.jumpTo(_scrollCtrl.position.pixels + delta);
      });
    } finally {
      if (mounted) _loadingOlder.value = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatHubService.to.joinConversation(_conversationId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingWorker?.dispose();
    _readWorker?.dispose();
    _statusWorker?.dispose();
    _messageUpdatedWorker?.dispose();
    _reconnectWorker?.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    ChatHubService.to.leaveConversation(_conversationId);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    // Only show the full-screen spinner on the very first load. Pull-to-refresh also
    // calls this method, and by then _messages is already populated — swapping the whole
    // list out for a centered spinner mid-pull would fight RefreshIndicator's own
    // top-of-list spinner instead of complementing it.
    final isFirstLoad = _messages.isEmpty;
    if (isFirstLoad) _loading.value = true;
    final result = await _chatCtrl.getMessages(_conversationId);
    // Backend returns newest-first (OrderByDescending(CreatedAt)) — the thread now
    // renders as a normal (non-reversed) top-to-bottom list, oldest at top, so this
    // needs reversing to chronological order before display.
    //
    // Merged, not overwritten: a real-time message can arrive via _incomingWorker in the
    // gap between this call starting and resolving (e.g. right after joinConversation on
    // screen open) — a blind overwrite here would silently drop it if the fetched snapshot
    // was taken a moment before that push landed server-side.
    //
    // For an id present in BOTH, take whichever side's readAt is more "advanced" rather than
    // letting fetched blindly win — a live read-receipt update from _readWorker can otherwise
    // be transiently reverted (tick flips back from read to unread) by a marginally-stale
    // refresh response that was already in flight when the receipt arrived.
    final localById = {for (final m in _messages) m.id: m};
    final fetched = result.items.reversed.map((m) {
      final advanced = m.readAt ?? localById[m.id]?.readAt;
      return advanced == m.readAt ? m : m.copyWith(readAt: advanced);
    }).toList();
    final fetchedIds = fetched.map((m) => m.id).toSet();
    final preserved = _messages.where((m) => !fetchedIds.contains(m.id));
    _messages.value = [...fetched, ...preserved]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (result.status != null) _status.value = result.status!;
    if (isFirstLoad) {
      // Only the very first load establishes whether older history exists beyond this page —
      // a later pull-to-refresh only re-fetches page 1 (this same call) and must not
      // clobber that, or a conversation with real older history would have it silently
      // hidden again after every refresh.
      _hasMoreOlder.value = result.hasMore;
      _loading.value = false;
      // Jump (not animate) straight to the bottom on cold open — same as the reference
      // demo's behavior, and there's nothing to animate from on first paint.
      _scrollToBottom(animate: false);
    }
  }

  // The backend pushes every new message over SignalR to the whole conversation group —
  // including the sender's own connection — *before* the sender's own REST call even
  // returns. So the same message can arrive twice: once via _incomingWorker's hub echo,
  // once via the awaited response below. Every insert site must dedup by id.
  void _insertIfNew(MessageModel msg) {
    if (_messages.any((x) => x.id == msg.id)) return;
    _messages.add(msg);
    // Always follow our own messages to the bottom. For messages from the other party,
    // only follow if we're already near the bottom — otherwise someone scrolled up
    // reading history would get yanked back down by an unrelated incoming message.
    if (msg.isMine || _isNearBottom()) _scrollToBottom();
  }

  bool _isNearBottom() {
    if (!_scrollCtrl.hasClients) return true;
    final pos = _scrollCtrl.position;
    return pos.maxScrollExtent - pos.pixels < 80;
  }

  // Re-entrancy guard: a burst of inserts (e.g. several messages arriving in one reconnect
  // catch-up) previously queued one overlapping animateTo per insert, each retargeting mid-
  // flight and visibly stuttering. Only one scroll is ever scheduled at a time now; it always
  // reads maxScrollExtent fresh when it actually runs, so it still lands correctly regardless
  // of how many inserts happened before the frame it fires in.
  bool _scrollScheduled = false;

  void _scrollToBottom({bool animate = true}) {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollCtrl.jumpTo(target);
      }
    });
  }

  void _openPlusMenu() async {
    // A rapid double-tap could otherwise both reach the await below before either resolves,
    // stacking two ChatPlusMenuSheets — the old synchronous version made this structurally
    // impossible, so this guard is what restores that guarantee now that there's an async gap.
    if (_openingPlusMenu) return;
    _openingPlusMenu = true;
    try {
      // Retries the catalog fetch if the initState() load failed (e.g. network contention
      // with the several other calls firing at screen-open) — loadQuestionTemplates()'s own
      // _templatesLoaded guard makes this a cheap no-op (no network call) once the catalog
      // has already loaded successfully, so this is safe to call on every "+" tap.
      await _chatCtrl.loadQuestionTemplates();
      if (!mounted) return;
      // Catalog questions ("Is it available?" etc.) are things a renter asks an owner —
      // an owner has no reason to ask that about their own listing, so their "+" menu
      // only offers Contact + Visit.
      final questions = _isOwner
          ? const <QuestionTemplateModel>[]
          : _chatCtrl.questionTemplates
                .where(
                  (t) => t.appliesTo(
                    _listingType,
                    targetRoomTypeId: _roomTypeId,
                    targetPlotTypeId: _plotTypeId,
                  ),
                )
                .toList();
      ChatPlusMenuSheet.show(
        context,
        questions: questions,
        onAskQuestion: (q) =>
            _send('quick_reply', {'key': q.key, 'text': q.questionText}),
        onRequestContact: () => _send('contact_request', {}),
        onScheduleVisit: _pickAndProposeSchedule,
      );
    } finally {
      _openingPlusMenu = false;
    }
  }

  Future<void> _send(String type, Map<String, dynamic> payload) async {
    _sending.value = true;
    try {
      // One id per compose-attempt, generated here (not inside ChatController) so a caller
      // that retries the exact same _send() invocation reuses it — this is the "one attempt"
      // boundary the server-side idempotency key is meant to dedup against.
      final clientMessageId = const Uuid().v4();
      final msg = await _chatCtrl.sendMessage(_conversationId, type, payload, clientMessageId: clientMessageId);
      if (msg != null && mounted) _insertIfNew(msg);
    } finally {
      if (mounted) _sending.value = false;
    }
  }

  Future<void> _pickAndProposeSchedule() async {
    final picked = await ChatSchedulePickerSheet.show(context);
    if (picked == null || picked.isEmpty) return;
    await _send('schedule_proposal', {
      'proposedAts': picked.map((d) => d.toIso8601String()).toList(),
      'status': 'pending',
    });
  }

  Future<void> _answerQuestion(
    String questionMessageId,
    String answerKey,
    String answerText,
  ) async {
    if (!_pendingActionMessageIds.add(questionMessageId)) return;
    try {
      final msg = await _chatCtrl.sendMessage(_conversationId, 'quick_reply', {
        'key': answerKey,
        'text': answerText,
      }, respondsToMessageId: questionMessageId);
      if (msg != null && mounted) _insertIfNew(msg);
    } finally {
      _pendingActionMessageIds.remove(questionMessageId);
    }
  }

  Future<void> _respondContact(String messageId, bool approve) async {
    if (!_pendingActionMessageIds.add(messageId)) return;
    try {
      final msg = await _chatCtrl.respondContact(messageId, approve);
      if (msg != null && mounted) _insertIfNew(msg);
    } finally {
      _pendingActionMessageIds.remove(messageId);
    }
  }

  Future<void> _acceptScheduleSlot(String messageId, DateTime chosen) async {
    if (!_pendingActionMessageIds.add(messageId)) return;
    try {
      final msg = await _chatCtrl.respondSchedule(
        messageId,
        'accept',
        acceptedAt: chosen,
      );
      if (msg != null && mounted) _insertIfNew(msg);
    } finally {
      _pendingActionMessageIds.remove(messageId);
    }
  }

  Future<void> _declineSchedule(String messageId) async {
    if (!_pendingActionMessageIds.add(messageId)) return;
    try {
      final msg = await _chatCtrl.respondSchedule(messageId, 'decline');
      if (msg != null && mounted) _insertIfNew(msg);
    } finally {
      _pendingActionMessageIds.remove(messageId);
    }
  }

  Future<void> _counterSchedule(String messageId) async {
    // Guarded from entry (before the picker sheet even opens), not just around the send —
    // otherwise a double-tap on "Counter" could stack two schedule-picker sheets the same way
    // a double-tapped "+" used to stack two ChatPlusMenuSheets.
    if (!_pendingActionMessageIds.add(messageId)) return;
    try {
      final picked = await ChatSchedulePickerSheet.show(
        context,
        title: 'Propose a different time',
      );
      if (picked == null || picked.isEmpty) return;
      final msg = await _chatCtrl.respondSchedule(
        messageId,
        'counter',
        proposedAts: picked,
      );
      if (msg != null && mounted) _insertIfNew(msg);
    } finally {
      _pendingActionMessageIds.remove(messageId);
    }
  }

  Future<void> _call(String phone) async {
    final url = Uri.parse('tel:+91$phone');
    if (await canLaunchUrl(url))
      launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // _buildHeader() now owns the top-safe-area itself (its gradient Container wraps a
    // SafeArea(bottom:false) internally, matching explore_screen.dart's header) — the
    // gradient genuinely extends behind the status bar, so this screen no longer needs an
    // AnnotatedRegion override; it inherits the same app-wide light-icon default every other
    // gradient-headed screen already renders correctly against.
    return Scaffold(
      backgroundColor: AppColors.chatBg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildSafetyStrip(),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: Obx(() {
                      if (_loading.value)
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      // Built *after* the loading check so a brand-new, empty conversation still gets
                      // the inline "next slot" bubble as its only item — that's the only way to open
                      // the "+" menu now that there's no bar fixed to the bottom.
                      final renderList = _buildRenderList();
                      if (renderList.isEmpty) return _buildEmpty();
                      // ListView(children:) rather than .builder — every item already carries a
                      // stable ValueKey, and a new message appended at the end shifts nothing
                      // for existing items, but a keyed delegate reconciling by key (not index)
                      // is still what lets existing bubbles keep their State/AnimationController
                      // so the fade-in only ever plays once.
                      // Non-reversed: a normal top-to-bottom list packs short content at the
                      // TOP (matching chat-live-demo-v4.html's plain flex-column thread) instead
                      // of bottom-pinning it the way ListView(reverse:true) always does
                      // regardless of content length — _scrollToBottom() (called on load and on
                      // every new message near the bottom) does the "stick to latest" job
                      // manually instead, same as the demo's own scrollTop=scrollHeight.
                      // AlwaysScrollableScrollPhysics so a short conversation (fewer messages
                      // than fill the viewport) still feels draggable and lets RefreshIndicator
                      // trigger — default physics refuse to scroll at all once content is
                      // shorter than the viewport.
                      return RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadHistory,
                        child: ListView(
                          controller: _scrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          children: renderList,
                        ),
                      );
                    }),
                  ),
                  Obx(
                    () => _status.value != 'Active'
                        ? _buildInactiveNotice()
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Groups every answered quick_reply question together with its own answer, positioned
  // at the question's own slot — regardless of when the answer actually arrived relative
  // to any other pending question. An answer message is never rendered a second time at
  // its own chronological position; it only ever appears attached to its question.
  List<Widget> _buildRenderList() {
    final loadedIds = _messages.map((m) => m.id).toSet();
    final answerByQuestionId = <String, MessageModel>{};
    for (final m in _messages) {
      final respondsTo = m.respondsToMessageId;
      // Only fold into a group if the question it answers is actually loaded — an older
      // question outside the currently-loaded history page must not cause its answer to
      // be silently dropped; render it as its own standalone bubble instead.
      if (m.type == 'quick_reply' &&
          respondsTo != null &&
          loadedIds.contains(respondsTo)) {
        answerByQuestionId[respondsTo] = m;
      }
    }
    final answerMessageIds = answerByQuestionId.values.map((m) => m.id).toSet();

    // Built oldest-first (mirrors `_messages`) for a normal top-to-bottom ListView.
    // Within a matched pair the question is appended first, then its answer directly
    // after — so the question still renders above its own answer, positioned at the
    // question's own chronological slot rather than wherever the answer actually arrived.
    final items = <Widget>[];
    // Reading _loadingOlder here (inside the top-level Obx this whole build runs in) makes
    // it reactive automatically. Same visual shape as chats_list_screen.dart's own
    // load-more spinner, just at the top of this list instead of the bottom.
    if (_loadingOlder.value) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          ),
        ),
      );
    }
    for (final m in _messages) {
      if (answerMessageIds.contains(m.id))
        continue; // rendered attached to its question below
      final answer = m.type == 'quick_reply' ? answerByQuestionId[m.id] : null;
      items.add(
        _animatedBubble(m.id, _buildBubble(m, answered: answer != null)),
      );
      if (answer != null)
        items.add(_animatedBubble(answer.id, _buildBubble(answer)));
    }
    // The "next slot" bubble — the inline replacement for the old fixed composer — goes
    // last, chronologically after every message currently in the thread, for both roles
    // alike. On a short/new conversation this is what makes it sit right under the last
    // message near the TOP of the screen (matching chat-live-demo-v4.html's plain
    // flex-column thread) instead of being glued to the bottom of the screen.
    if (_status.value == 'Active') {
      items.add(
        KeyedSubtree(
          key: const ValueKey('ghost-slot'),
          child: Obx(
            () => ChatNextSlotBubble(
              onTap: _openPlusMenu,
              sending: _sending.value,
            ),
          ),
        ),
      );
    }
    return items;
  }

  // Keys each bubble by its stable message id so Flutter's reconciliation reuses the same
  // Element/State across unrelated Obx rebuilds (e.g. a read-receipt flip) — FadeInUp only
  // (re)starts from initState, so a preserved State means the entrance plays exactly once,
  // on first mount, and never replays on messages that were already on screen.
  Widget _animatedBubble(String id, Widget child) => KeyedSubtree(
    key: ValueKey(id),
    child: FadeInUp(
      duration: const Duration(milliseconds: 320),
      from: 16,
      child: child,
    ),
  );

  // Fixed, non-dismissible, unconditional (both owner and renter) — always visible for the
  // whole life of the screen, not gated on any state or event. Sits outside the scrollable
  // list so it never scrolls away. This is a UI-only safety nudge; the platform takes no
  // responsibility for off-app transactions (see terms_of_service_screen.dart) and doesn't
  // police them — this strip just makes sure that's actually seen, not just legally on record.
  Widget _buildSafetyStrip() {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primaryLight),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Bakhli never collects rent or advance. Always meet and visit before paying.',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // SafeArea lives INSIDE the gradient Container (not wrapping it) — same pattern
    // explore_screen.dart's header already uses — so the gradient's own paint area starts
    // at the very top of the screen, genuinely extending behind the status bar, and only the
    // Row's content gets padded down to clear it. This is what makes the status bar read as
    // "part of the navy header" instead of a separate light strip above it.
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  _otherPartyName.isNotEmpty
                      ? _otherPartyName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _otherPartyName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_listingType == 'Room' ? '🏠' : '📍'} $_listingTitle'
                      '${_area != null && _area.isNotEmpty ? ' · $_area' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isOwner)
                Obx(() {
                  final isBlocked = _status.value == 'Blocked';
                  return PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                    ),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (_) =>
                        isBlocked ? _confirmUnblockUser() : _confirmBlockUser(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: isBlocked ? 'unblock' : 'block',
                        child: Row(
                          children: [
                            Icon(
                              isBlocked
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.block_rounded,
                              size: 18,
                              color: isBlocked ? AppColors.primary : AppColors.error,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isBlocked ? 'Unblock the user' : 'Block this user',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: isBlocked ? AppColors.primary : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlockUser() async {
    if (_otherPartyId.isEmpty) return;
    bool blocking = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Block this user?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '$_otherPartyName will no longer be able to message you in any conversation.',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              color: AppColors.textMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: blocking ? null : () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: blocking
                  ? null
                  : () async {
                      setDialogState(() => blocking = true);
                      final ok = await _chatCtrl.blockUser(_otherPartyId);
                      if (ctx.mounted) Navigator.pop(ctx, ok);
                    },
              child: blocking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Block',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) _status.value = 'Blocked';
  }

  Future<void> _confirmUnblockUser() async {
    if (_otherPartyId.isEmpty) return;
    bool unblocking = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Unblock this user?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '$_otherPartyName will be able to message you again.',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              color: AppColors.textMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: unblocking ? null : () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: unblocking
                  ? null
                  : () async {
                      setDialogState(() => unblocking = true);
                      final ok = await _chatCtrl.unblockUser(_otherPartyId);
                      if (ctx.mounted) Navigator.pop(ctx, ok);
                    },
              child: unblocking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Unblock',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) _status.value = 'Active';
  }

  // Only reachable once the conversation is no longer Active (an Active conversation always
  // has at least the inline "next slot" bubble as an item) — the inactive notice below
  // already explains why messaging is unavailable, so this just needs to say there's
  // nothing here.
  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.waving_hand_rounded,
            size: 44,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          const Text(
            'No messages in this conversation',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildBubble(MessageModel m, {bool answered = false}) {
    final isContactRequest = m.type == 'contact_request';
    final isScheduleProposal = m.type == 'schedule_proposal';
    // Reading _pendingActionMessageIds here (inside the top-level Obx this is always called
    // from) makes it a reactive dependency automatically — no extra Obx wrapper needed. Every
    // callback below is gated by this too, so a response already in flight for this exact
    // message immediately disables its buttons (passing null, which the existing
    // `disabled = onTap == null` pattern in _actionBtn/_ScheduleProposalCard already dims)
    // instead of leaving them tappable for a full network round-trip.
    final pending = _pendingActionMessageIds.contains(m.id);
    final canAnswer =
        !answered && !pending && m.type == 'quick_reply' && (_isOwner || !m.isMine);
    // A schedule_proposal or contact_request that's already been answered must never
    // show its action buttons again. The backend links every response back to the
    // original message via respondsToMessageId (same FK column quick_reply answers
    // already use), so its presence anywhere in the loaded thread means this request is
    // done — checked here instead of trusting the original message's own payload, which
    // the backend never updates in place for either type's plain approve/decline path.
    final scheduleAlreadyResponded = isScheduleProposal &&
        _messages.any((x) => x.respondsToMessageId == m.id);
    final contactAlreadyResponded = isContactRequest &&
        _messages.any((x) => x.respondsToMessageId == m.id);
    return ChatMessageBubble(
      message: m,
      templates: _chatCtrl.questionTemplates,
      onAnswerQuestion: canAnswer
          ? (answerKey, answerText) =>
                _answerQuestion(m.id, answerKey, answerText)
          : null,
      // No owner/renter restriction — either side can send a contact request and whoever
      // receives it can respond, same shape as the schedule gating below.
      onApproveContact: (isContactRequest && !m.isMine && !contactAlreadyResponded && !pending)
          ? () => _respondContact(m.id, true)
          : null,
      onDeclineContact: (isContactRequest && !m.isMine && !contactAlreadyResponded && !pending)
          ? () => _respondContact(m.id, false)
          : null,
      onAcceptSlot: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded && !pending
          ? (dt) => _acceptScheduleSlot(m.id, dt)
          : null,
      onDeclineSchedule: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded && !pending
          ? () => _declineSchedule(m.id)
          : null,
      onCounterSchedule: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded && !pending
          ? () => _counterSchedule(m.id)
          : null,
      onCall: () {
        final phone = m.payload['phone'] as String?;
        if (phone != null) _call(phone);
      },
    );
  }

  Widget _buildInactiveNotice() {
    final isBlockedByMe = _status.value == 'Blocked' && _isOwner;
    final text = switch (_status.value) {
      'ListingRemoved' =>
        'This listing has been removed — you can no longer send messages here.',
      'ListingInactive' =>
        'This listing is currently inactive — you can no longer send messages here.',
      'Blocked' =>
        isBlockedByMe
            ? "You've blocked this user — they can no longer message you."
            : 'You can no longer message in this conversation.',
      _ => 'This conversation is no longer active.',
    };
    return Container(
      // Bottom safe-area is already reserved once by the SafeArea(top:false) wrapping the
      // whole column this sits in (default bottom:true) — adding MediaQuery's bottom inset
      // again here would double it up.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              color: AppColors.textLight,
            ),
          ),
          if (isBlockedByMe) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _confirmUnblockUser,
              child: const Text(
                'Unblock',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
