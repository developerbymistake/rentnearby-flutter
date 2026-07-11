import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../controllers/chat_controller.dart';
import '../models/message_model.dart';
import '../models/question_template_model.dart';
import '../services/chat_hub_service.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_plus_menu_sheet.dart';
import '../widgets/chat_schedule_picker_sheet.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({super.key});
  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> with WidgetsBindingObserver {
  final _chatCtrl = Get.find<ChatController>();

  late final String _conversationId;
  late final String _listingType;
  late final String? _roomTypeId;
  late final String? _plotTypeId;
  late final String _otherPartyId;
  late final String _otherPartyName;
  late final String _listingTitle;
  late final bool _isOwner;
  final _status = ''.obs;

  final _messages = <MessageModel>[].obs;
  final _loading = true.obs;
  Worker? _incomingWorker;

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
    _isOwner = args['isOwner'] as bool? ?? false;
    _status.value = args['status'] as String? ?? 'Active';

    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    ChatHubService.to.connect(conversationId: _conversationId);
    _chatCtrl.markRead(_conversationId);
    _chatCtrl.loadQuestionTemplates();

    _incomingWorker = ever<MessageModel?>(_chatCtrl.incomingMessage, (m) {
      if (m == null || m.conversationId != _conversationId || !mounted) return;
      if (!_messages.any((x) => x.id == m.id)) _messages.insert(0, m);
      if (!m.isMine) _chatCtrl.markRead(_conversationId);
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
    ChatHubService.to.disconnect();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    _loading.value = true;
    final items = await _chatCtrl.getMessages(_conversationId);
    _messages.value = items.reversed.toList();
    _loading.value = false;
  }

  void _openPlusMenu() {
    // Catalog questions ("Is it available?" etc.) are things a renter asks an owner —
    // an owner has no reason to ask that about their own listing, so their "+" menu
    // only offers Contact + Visit.
    final questions = _isOwner
        ? const <QuestionTemplateModel>[]
        : _chatCtrl.questionTemplates
            .where((t) => t.appliesTo(_listingType, targetRoomTypeId: _roomTypeId, targetPlotTypeId: _plotTypeId))
            .toList();
    ChatPlusMenuSheet.show(
      context,
      questions: questions,
      onAskQuestion: (q) => _send('quick_reply', {'key': q.key, 'text': q.questionText}),
      onRequestContact: () => _send('contact_request', {}),
      onScheduleVisit: _pickAndProposeSchedule,
    );
  }

  Future<void> _send(String type, Map<String, dynamic> payload) async {
    final msg = await _chatCtrl.sendMessage(_conversationId, type, payload);
    if (msg != null && mounted) _messages.insert(0, msg);
  }

  Future<void> _pickAndProposeSchedule() async {
    final picked = await ChatSchedulePickerSheet.show(context);
    if (picked == null || picked.isEmpty) return;
    await _send('schedule_proposal', {
      'proposedAts': picked.map((d) => d.toIso8601String()).toList(),
      'status': 'pending',
    });
  }

  Future<void> _answerQuestion(String questionMessageId, String answerKey, String answerText) async {
    final msg = await _chatCtrl.sendMessage(
      _conversationId, 'quick_reply', {'key': answerKey, 'text': answerText},
      respondsToMessageId: questionMessageId,
    );
    if (msg != null && mounted) _messages.insert(0, msg);
  }

  Future<void> _respondContact(String messageId, bool approve) async {
    final msg = await _chatCtrl.respondContact(messageId, approve);
    if (msg != null && mounted) _messages.insert(0, msg);
  }

  Future<void> _acceptScheduleSlot(String messageId, DateTime chosen) async {
    final msg = await _chatCtrl.respondSchedule(messageId, 'accept', acceptedAt: chosen);
    if (msg != null && mounted) _messages.insert(0, msg);
  }

  Future<void> _declineSchedule(String messageId) async {
    final msg = await _chatCtrl.respondSchedule(messageId, 'decline');
    if (msg != null && mounted) _messages.insert(0, msg);
  }

  Future<void> _counterSchedule(String messageId) async {
    final picked = await ChatSchedulePickerSheet.show(context, title: 'Propose a different time');
    if (picked == null || picked.isEmpty) return;
    final msg = await _chatCtrl.respondSchedule(messageId, 'counter', proposedAts: picked);
    if (msg != null && mounted) _messages.insert(0, msg);
  }

  Future<void> _call(String phone) async {
    final url = Uri.parse('tel:+91$phone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsapp(String phone) async {
    final url = Uri.parse('https://wa.me/91$phone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(context),
          Expanded(
            child: Obx(() {
              if (_loading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              if (_messages.isEmpty) return _buildEmpty();
              final renderList = _buildRenderList();
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: renderList.length,
                itemBuilder: (_, i) => renderList[i],
              );
            }),
          ),
          Obx(() => _status.value == 'Active' ? _buildComposer() : _buildInactiveNotice()),
        ]),
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
      if (m.type == 'quick_reply' && respondsTo != null && loadedIds.contains(respondsTo)) {
        answerByQuestionId[respondsTo] = m;
      }
    }
    final answerMessageIds = answerByQuestionId.values.map((m) => m.id).toSet();

    // Built newest-first (mirrors `_messages`) for a `reverse: true` ListView, where a
    // lower array index renders lower/newer on screen. Within a matched pair the answer
    // is appended *before* its question — despite being the newer message — so the
    // question ends up rendering above its own answer, positioned at the question's own
    // chronological slot rather than wherever the answer happened to actually arrive.
    final items = <Widget>[];
    for (final m in _messages) {
      if (answerMessageIds.contains(m.id)) continue; // rendered attached to its question below
      final answer = m.type == 'quick_reply' ? answerByQuestionId[m.id] : null;
      if (answer != null) items.add(_buildBubble(answer));
      items.add(_buildBubble(m, answered: answer != null));
    }
    return items;
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Row(children: [
        IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(_otherPartyName.isNotEmpty ? _otherPartyName[0].toUpperCase() : '?',
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_otherPartyName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white)),
            Text('${_listingType == 'Room' ? '🏠' : '📍'} $_listingTitle',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
          ]),
        ),
        if (_isOwner)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (_) => _confirmBlockUser(),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'block',
                child: Text('Block this user', style: TextStyle(fontFamily: 'Poppins', color: AppColors.error)),
              ),
            ],
          ),
      ]),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Block this user?', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          content: Text('$_otherPartyName will no longer be able to message you in any conversation.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppColors.textMedium)),
          actions: [
            TextButton(
              onPressed: blocking ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: blocking
                  ? null
                  : () async {
                      setDialogState(() => blocking = true);
                      final ok = await _chatCtrl.blockUser(_otherPartyId);
                      if (ctx.mounted) Navigator.pop(ctx, ok);
                    },
              child: blocking
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Block', style: TextStyle(fontFamily: 'Poppins')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Unblock this user?', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          content: Text('$_otherPartyName will be able to message you again.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppColors.textMedium)),
          actions: [
            TextButton(
              onPressed: unblocking ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: unblocking
                  ? null
                  : () async {
                      setDialogState(() => unblocking = true);
                      final ok = await _chatCtrl.unblockUser(_otherPartyId);
                      if (ctx.mounted) Navigator.pop(ctx, ok);
                    },
              child: unblocking
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Unblock', style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) _status.value = 'Active';
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.waving_hand_rounded, size: 44, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text('Tap + below to ask a question',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          ]),
        ),
      );

  Widget _buildBubble(MessageModel m, {bool answered = false}) {
    final isContactRequest = m.type == 'contact_request';
    final isScheduleProposal = m.type == 'schedule_proposal';
    final canAnswer = !answered && m.type == 'quick_reply' && (_isOwner || !m.isMine);
    return ChatMessageBubble(
      message: m,
      templates: _chatCtrl.questionTemplates,
      onAnswerQuestion: canAnswer ? (answerKey, answerText) => _answerQuestion(m.id, answerKey, answerText) : null,
      onApproveContact: (isContactRequest && !m.isMine && _isOwner) ? () => _respondContact(m.id, true) : null,
      onDeclineContact: (isContactRequest && !m.isMine && _isOwner) ? () => _respondContact(m.id, false) : null,
      onAcceptSlot: isScheduleProposal && !m.isMine ? (dt) => _acceptScheduleSlot(m.id, dt) : null,
      onDeclineSchedule: isScheduleProposal && !m.isMine ? () => _declineSchedule(m.id) : null,
      onCounterSchedule: isScheduleProposal && !m.isMine ? () => _counterSchedule(m.id) : null,
      onCall: () {
        final phone = m.payload['phone'] as String?;
        if (phone != null) _call(phone);
      },
      onWhatsApp: () {
        final phone = m.payload['phone'] as String?;
        if (phone != null) _whatsapp(phone);
      },
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + MediaQuery.viewPaddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _openPlusMenu,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.primaryLight),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.centerLeft,
            child: const Text('Choose an option…',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textHint)),
          ),
        ),
      ]),
    );
  }

  Widget _buildInactiveNotice() {
    final isBlockedByMe = _status.value == 'Blocked' && _isOwner;
    final text = switch (_status.value) {
      'ListingRemoved' => 'This listing has been removed — you can no longer send messages here.',
      'ListingInactive' => 'This listing is currently inactive — you can no longer send messages here.',
      'Blocked' => isBlockedByMe
          ? "You've blocked this user — they can no longer message you."
          : 'You can no longer message in this conversation.',
      _ => 'This conversation is no longer active.',
    };
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight)),
        if (isBlockedByMe) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: _confirmUnblockUser,
            child: const Text('Unblock', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ]),
    );
  }
}
