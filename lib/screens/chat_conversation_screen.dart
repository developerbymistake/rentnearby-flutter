import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
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
  // Dims the inline "next slot" bubble and disables its tap while a send is in flight. A
  // single shared flag is enough — every send path below is awaited sequentially from this
  // screen's own UI thread, so only one send can ever be in flight at a time.
  final _sending = false.obs;
  final _scrollCtrl = ScrollController();
  Worker? _incomingWorker;
  Worker? _readWorker;
  Worker? _statusWorker;

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
    _loadHistory();
    ChatHubService.to.connect(conversationId: _conversationId);
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatHubService.to.connect(conversationId: _conversationId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingWorker?.dispose();
    _readWorker?.dispose();
    _statusWorker?.dispose();
    _scrollCtrl.dispose();
    ChatHubService.to.disconnect();
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
    _messages.value = result.items.reversed.toList();
    if (result.status != null) _status.value = result.status!;
    if (isFirstLoad) {
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

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _openPlusMenu() {
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
  }

  Future<void> _send(String type, Map<String, dynamic> payload) async {
    _sending.value = true;
    try {
      final msg = await _chatCtrl.sendMessage(_conversationId, type, payload);
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
    final msg = await _chatCtrl.sendMessage(_conversationId, 'quick_reply', {
      'key': answerKey,
      'text': answerText,
    }, respondsToMessageId: questionMessageId);
    if (msg != null && mounted) _insertIfNew(msg);
  }

  Future<void> _respondContact(String messageId, bool approve) async {
    final msg = await _chatCtrl.respondContact(messageId, approve);
    if (msg != null && mounted) _insertIfNew(msg);
  }

  Future<void> _acceptScheduleSlot(String messageId, DateTime chosen) async {
    final msg = await _chatCtrl.respondSchedule(
      messageId,
      'accept',
      acceptedAt: chosen,
    );
    if (msg != null && mounted) _insertIfNew(msg);
  }

  Future<void> _declineSchedule(String messageId) async {
    final msg = await _chatCtrl.respondSchedule(messageId, 'decline');
    if (msg != null && mounted) _insertIfNew(msg);
  }

  Future<void> _counterSchedule(String messageId) async {
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
    final canAnswer =
        !answered && m.type == 'quick_reply' && (_isOwner || !m.isMine);
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
      onApproveContact: (isContactRequest && !m.isMine && _isOwner && !contactAlreadyResponded)
          ? () => _respondContact(m.id, true)
          : null,
      onDeclineContact: (isContactRequest && !m.isMine && _isOwner && !contactAlreadyResponded)
          ? () => _respondContact(m.id, false)
          : null,
      onAcceptSlot: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded
          ? (dt) => _acceptScheduleSlot(m.id, dt)
          : null,
      onDeclineSchedule: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded
          ? () => _declineSchedule(m.id)
          : null,
      onCounterSchedule: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded
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
