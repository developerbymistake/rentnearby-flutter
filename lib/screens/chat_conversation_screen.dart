import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import '../config/app_routes.dart';
import '../controllers/chat_controller.dart';
import '../features/trip/controllers/trip_enquiry_controller.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/utils/trip_report.dart';
import '../features/trip/widgets/trip_enquiry_strip.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../services/chat_hub_service.dart';
import '../services/notification_service.dart';
import '../utils/app_toast.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/trip_chat_cards.dart';
import '../widgets/trip_offer_cards.dart';
import '../widgets/trip_report_traveller_sheet.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({super.key});
  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> with WidgetsBindingObserver {
  final _chatCtrl = Get.find<ChatController>();

  late final String _conversationId;
  late final String _listingType;
  ChatKindStyle get _kind => ChatKindStyle.of(_listingType);
  Color get _accent => _kind.dark;
  ListingTone get _tone => ChatLook3D.toneFor(_listingType);
  late final String _otherPartyId;
  late final String _otherPartyName;
  late final String? _otherPartyPhotoUrl;
  late final String _listingTitle;
  late final String? _area;
  late final bool _isOwner;
  late final String? _argListingId;
  late final bool _invalidArgs;
  bool get _isStay => _listingType == 'Stay';
  final _enquiry = Rxn<TripEnquiryModel>();
  bool _enquiryBusy = false;
  bool _enquiryDirty = false;
  String? _focusEnquiryId;
  final _status = ''.obs;
  // Only meaningful when _status.value == 'Blocked' — true if the CURRENT user did the
  // blocking. Never inferred from _isOwner (either party can block the other regardless of
  // listing ownership) — comes from the backend (UserBlocks source of truth) at load time,
  // and is kept live via _statusWorker below when a ConversationStatusChanged push arrives.
  final _isBlockedByMe = false.obs;

  final _messages = <MessageModel>[].obs;
  final _loading = true.obs;
  // Older-history paging (scroll-to-top). _hasMoreOlder starts true (optimistic — we don't
  // know yet) and is only ever authoritatively set from _loadHistory's FIRST load; a later
  // pull-to-refresh only re-fetches page 1 and must not clobber what's already been
  // established about whether older history exists beyond it.
  final _loadingOlder = false.obs;
  final _hasMoreOlder = true.obs;
  final _scrollCtrl = ScrollController();
  Worker? _incomingWorker;
  Worker? _readWorker;
  Worker? _statusWorker;
  Worker? _messageUpdatedWorker;
  Worker? _reconnectWorker;

  @override
  void initState() {
    super.initState();
    final raw = Get.arguments;
    final args = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    String? text(String key) {
      final v = args[key];
      return v == null || v.toString().isEmpty ? null : v.toString();
    }

    bool? flag(String key) {
      final v = args[key];
      return v is bool ? v : (v is String ? v.toLowerCase() == 'true' : null);
    }

    final id = text('conversationId');
    final known = id == null ? null : _chatCtrl.conversations.firstWhereOrNull((c) => c.id == id);
    _conversationId = id ?? '';
    _listingType = text('listingType') ?? known?.listingType ?? '';
    _invalidArgs = id == null || _listingType.isEmpty;
    _otherPartyId = text('otherPartyId') ?? known?.otherPartyId ?? '';
    _otherPartyName = text('otherPartyName') ?? known?.otherPartyName ?? 'User';
    _otherPartyPhotoUrl = ConversationModel.photo(text('otherPartyPhotoUrl')) ?? known?.otherPartyPhotoUrl;
    _listingTitle = text('listingTitle') ?? known?.listingTitle ?? '';
    _area = text('area') ?? known?.area;
    _isOwner = flag('isOwner') ?? known?.isOwner ?? false;
    _argListingId = text('listingId') ?? known?.listingId;
    _status.value = known?.status ?? text('status') ?? 'Active';
    _isBlockedByMe.value = known?.isBlockedByMe ?? flag('isBlockedByMe') ?? false;
    _focusEnquiryId = text('enquiryId');
    if (_invalidArgs) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Get.back();
        if (id == null) {
          Get.toNamed(AppRoutes.chatsList);
        } else {
          NotificationService.to.openActionRoute(AppRoutes.chatConversation, {'conversationId': id});
        }
      });
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
    _loadHistory();
    _refreshEnquiry();
    ChatHubService.to.joinConversation(_conversationId);
    _chatCtrl.markRead(_conversationId);
    // Runs regardless of how this screen was reached (notification tap or a plain manual
    // tap from the Chats list) — the one place that reliably fires every time this
    // conversation is actually opened, so a message already read in-app never resurfaces
    // stacked under a future chat notification for this same thread.
    NotificationService.to.dismissChatNotification(_conversationId);

    _incomingWorker = ever<MessageModel?>(_chatCtrl.incomingMessage, (m) {
      if (m == null || m.conversationId != _conversationId || !mounted) return;
      _insertIfNew(m);
      if (_affectsEnquiry(m)) _refreshEnquiry();
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
          .map((m) => (m.isMine && m.readAt == null) ? m.copyWith(readAt: now) : m)
          .toList();
    });

    // Live block/unblock by either party — reaches this device too when it's the one that
    // just blocked/unblocked (harmless, same value it already set optimistically), since both
    // sides share the conversation_{id} SignalR group while this screen is open.
    _statusWorker = ever<Map<String, dynamic>?>(_chatCtrl.conversationStatusChanged, (data) {
      if (data == null || !mounted) return;
      if (data['conversationId'] != _conversationId) return;
      _status.value = data['status'] as String;
      _isBlockedByMe.value = data['isBlockedByMe'] as bool? ?? false;
    });

    // Live "MessageUpdated" — an EXISTING message's state changed (e.g. a schedule proposal
    // marked "superseded" by a counter-offer) rather than a new one arriving. Without this,
    // the superseded card stayed looking pending/actionable until the screen was reopened.
    _messageUpdatedWorker = ever<MessageModel?>(_chatCtrl.messageUpdated, (m) {
      if (m == null || m.conversationId != _conversationId || !mounted) return;
      final idx = _messages.indexWhere((x) => x.id == m.id);
      if (idx != -1) _messages[idx] = m;
      if (_affectsEnquiry(m)) _refreshEnquiry();
    });

    // SignalR's automatic-reconnect gets a brand-new connection id, so anything sent by the
    // other party during the drop was missed entirely by this screen (not just delayed) —
    // catch up on exactly what was missed instead of waiting for a manual reopen.
    _reconnectWorker = ever<DateTime?>(_chatCtrl.hubReconnected, (_) {
      _catchUpAfterReconnect();
      _refreshEnquiry();
    });
  }

  bool _affectsEnquiry(MessageModel m) => _isStay && (m.type.startsWith('trip_') || m.type == 'system');

  Future<void> _refreshEnquiry() async {
    if (!_isStay) return;
    if (_enquiryBusy) {
      _enquiryDirty = true;
      return;
    }
    _enquiryBusy = true;
    try {
      do {
        _enquiryDirty = false;
        final e = await _loadEnquiry();
        if (!mounted) return;
        if (e != null) _enquiry.value = e;
      } while (_enquiryDirty);
    } finally {
      _enquiryBusy = false;
    }
  }

  Future<TripEnquiryModel?> _loadEnquiry() async {
    final ctrl = TripEnquiryController.to;
    final focus = _focusEnquiryId;
    if (focus != null) {
      final e = await ctrl.refreshOne(focus);
      if (e != null && e.conversationId == _conversationId) {
        if (e.isOpen) return e;
        final latest = await ctrl.forConversation(_conversationId);
        if (latest == null || !latest.isOpen) return e;
        _focusEnquiryId = null;
        return latest;
      }
    }
    return ctrl.forConversation(_conversationId);
  }

  String? get _listingId {
    if (_argListingId != null) return _argListingId;
    final fromEnquiry = _enquiry.value?.listingId;
    if (fromEnquiry != null && fromEnquiry.isNotEmpty) return fromEnquiry;
    final i = _chatCtrl.conversations.indexWhere((c) => c.id == _conversationId);
    return i == -1 ? null : _chatCtrl.conversations[i].listingId;
  }

  void _openStrip(TripEnquiryModel e) {
    Get.toNamed(_isOwner ? AppRoutes.stayEnquiries : AppRoutes.myEnquiries, arguments: {'enquiryId': e.id});
  }

  Future<void> _reportHost(String? listingId, {String? enquiryId}) async {
    if (listingId == null || listingId.isEmpty) {
      AppToast.error(TripStrings.couldNotLoad);
      return;
    }
    await TripReport.stay(context, listingId, tripEnquiryId: enquiryId ?? _enquiry.value?.id);
  }

  Future<void> _reportTraveller() async {
    final e = _enquiry.value;
    if (e == null) return;
    await TripReportTravellerSheet.show(context, enquiry: e);
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

  // If the newly-loaded content still doesn't fill/exceed the viewport, no scroll event will
  // ever fire to trigger _onScroll — a long conversation made entirely of short bubbles would
  // otherwise leave _hasMoreOlder stuck true forever with no way to reach the rest of its
  // history. Called after the first load and again after every successful older-history load
  // (see _loadOlderHistory), so it keeps pulling pages until the viewport is genuinely
  // scrollable or the server says there's no more — self-terminating via _hasMoreOlder.
  void _maybeFillViewportWithOlder() {
    if (!mounted || !_scrollCtrl.hasClients) return;
    if (_hasMoreOlder.value && _scrollCtrl.position.maxScrollExtent <= 150) {
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
    // Set right before scheduling the postFrameCallback below — tells the `finally` not to
    // clear _loadingOlder immediately, since the callback itself is now responsible for that.
    var deferred = false;
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
      _loadTemplatesIfNeeded();
      deferred = true;
      // _loadingOlder must stay true for the entire frame in which the list visually grows —
      // clearing it any earlier (e.g. synchronously right after just SCHEDULING this callback,
      // not after it actually runs) left a window where the growing maxScrollExtent could fire
      // _onScroll mid-layout, before the jump below had corrected position, re-triggering
      // another fetch on top of this one still in flight.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollCtrl.hasClients) {
          final delta = _scrollCtrl.position.maxScrollExtent - oldExtent;
          _scrollCtrl.jumpTo(_scrollCtrl.position.pixels + delta);
        }
        if (mounted) _loadingOlder.value = false;
        _maybeFillViewportWithOlder();
      });
    } finally {
      if (!deferred && mounted) _loadingOlder.value = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_invalidArgs) {
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
    if (!_invalidArgs) ChatHubService.to.leaveConversation(_conversationId);
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
    _loadTemplatesIfNeeded();
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
      // Scheduled after _scrollToBottom's own postFrameCallback (registered first, same
      // frame) so this reads settled scroll metrics — see _maybeFillViewportWithOlder's own
      // comment for why this check exists at all.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFillViewportWithOlder());
    }
  }

  // The backend pushes every new message over SignalR to the whole conversation group —
  // including the sender's own connection — *before* the sender's own REST call even
  // returns. So the same message can arrive twice: once via _incomingWorker's hub echo,
  // once via the awaited response below. Every insert site must dedup by id.
  void _insertIfNew(MessageModel msg) {
    if (_messages.any((x) => x.id == msg.id)) return;
    _messages.add(msg);
    _loadTemplatesIfNeeded();
    // Always follow our own messages to the bottom. For messages from the other party,
    // only follow if we're already near the bottom — otherwise someone scrolled up
    // reading history would get yanked back down by an unrelated incoming message.
    if (msg.isMine || _isNearBottom()) _scrollToBottom();
  }

  // Old quick_reply bubbles need the catalog to print their question text.
  void _loadTemplatesIfNeeded() {
    if (_messages.any((m) => m.type == 'quick_reply')) _chatCtrl.loadQuestionTemplates();
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
          curve: Curves.fastOutSlowIn,
        );
      } else {
        _scrollCtrl.jumpTo(target);
      }
    });
  }

  Future<void> _call(String phone) async {
    final url = Uri.parse('tel:+91$phone');
    if (await canLaunchUrl(url)) {
      launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // _buildHeader() now owns the top-safe-area itself (its gradient Container wraps a
    // SafeArea(bottom:false) internally, matching explore_screen.dart's header) — the
    // gradient genuinely extends behind the status bar, so this screen no longer needs an
    // AnnotatedRegion override; it inherits the same app-wide light-icon default every other
    // gradient-headed screen already renders correctly against.
    if (_invalidArgs) {
      return const Scaffold(
        backgroundColor: DesignColors.scaffold,
        body: Center(child: CircularProgressIndicator(color: DesignColors.primary)),
      );
    }
    return KitStatusBar(
      child: Scaffold(
        backgroundColor: _listingType == 'Taxi'
            ? ListingPalette.coral.page
            : ListingPalette.forest.page,
        body: StaggerHost(
          count: 3,
          child: Column(
            children: [
              StaggerItem(index: 0, offset: 30, child: _buildHeader(context)),
              const ToastSlot(),
              if (_isStay) StaggerItem(index: 1, child: _buildTripStrip()),
              StaggerItem(index: 2, child: _buildSafetyStrip()),
              Expanded(
                child: Obx(() {
                  if (_loading.value) {
                    return _buildSkeleton();
                  }
                  final renderList = _buildRenderList();
                  if (renderList.isEmpty) return _buildEmpty();
                  final bottom = _status.value != 'Active'
                      ? ChatNoticePanel3D.overhang + DS.s(8)
                      : DS.s(20) + MediaQuery.paddingOf(context).bottom;
                  return ChatThreadFade(
                    child: RefreshIndicator(
                      color: _tone.g2,
                      backgroundColor: DesignColors.surface,
                      onRefresh: _loadHistory,
                      child: ListView(
                        controller: _scrollCtrl,
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(8), DS.s(18), bottom),
                        children: renderList,
                      ),
                    ),
                  );
                }),
              ),
              Obx(() => _status.value != 'Active' ? _buildInactiveNotice() : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripStrip() => Obx(() {
    final e = _enquiry.value;
    if (e == null) return const SizedBox.shrink();
    return TripEnquiryStrip(
      enquiry: e,
      ownerSide: _isOwner,
      onTap: () => _openStrip(e),
    );
  });

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
        Padding(
          padding: EdgeInsets.only(top: DS.s(4), bottom: DS.s(12)),
          child: Center(
            child: SizedBox(
              width: DS.s(24),
              height: DS.s(24),
              child: CircularProgressIndicator(
                strokeWidth: DS.s(3),
                color: _tone.g2,
                backgroundColor: _tone.haloBase.withValues(alpha: Alpha.soft),
              ),
            ),
          ),
        ),
      );
    }
    for (final m in _messages) {
      if (answerMessageIds.contains(m.id)) {
        continue; // rendered attached to its question below
      }
      final answer = m.type == 'quick_reply' ? answerByQuestionId[m.id] : null;
      items.add(_animatedBubble(m.id, _buildBubble(m)));
      if (answer != null) {
        items.add(_animatedBubble(answer.id, _buildBubble(answer)));
      }
    }
    return items;
  }

  // Keys each bubble by its stable message id so Flutter's reconciliation reuses the same
  // Element/State across unrelated Obx rebuilds (e.g. a read-receipt flip) — ChatReveal only
  // (re)starts from initState, so a preserved State means the entrance plays exactly once,
  // on first mount, and never replays on messages that were already on screen.
  Widget _animatedBubble(String id, Widget child) => KeyedSubtree(
    key: ValueKey(id),
    child: ChatReveal(animate: !_loadingOlder.value, child: child),
  );

  Widget _buildSkeleton() {
    const widths = [180.0, 140.0, 220.0, 120.0, 190.0];
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(8), DS.s(18), DS.s(10)),
      itemCount: widths.length,
      itemBuilder: (_, i) => EntranceOnce(
        index: i,
        child: ChatSkeletonBubble3D(width: widths[i], mine: i.isOdd),
      ),
    );
  }

  // Always visible for both sides; the platform takes no part in off-app payments.
  Widget _buildSafetyStrip() {
    return const ChatSafetyNote3D(
      text: 'Bakhli never collects payment. Always meet and visit before paying.',
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ChatHeader3D(
      tone: _tone,
      initial: ChatLook3D.initialOf(_otherPartyName),
      name: _otherPartyName,
      subtitle: '$_listingTitle${_area != null && _area.isNotEmpty ? ' · $_area' : ''}',
      sticker: ChatLook3D.artFor(_listingType),
      art: ChatLook3D.artFor(_listingType),
      onBack: () => Get.back(),
      onMore: _openMoreMenu,
      photoUrl: _otherPartyPhotoUrl,
    );
  }

  void _openMoreMenu(Rect anchor) {
    final isBlocked = _isBlockedByMe.value;
    showMenu3D(
      context,
      anchor: anchor,
      items: [
        if (_isStay && (!_isOwner || _enquiry.value != null))
          MenuItem3D(
            label: TripStrings.report,
            art: ListingArt.pushpin,
            onTap: () => _isOwner ? _reportTraveller() : _reportHost(_listingId),
          ),
        MenuItem3D(
          label: isBlocked ? 'Unblock the user' : 'Block this user',
          icon: isBlocked ? Icons.check_circle_outline_rounded : Icons.block_rounded,
          danger: !isBlocked,
          positive: isBlocked,
          onTap: () => isBlocked ? _confirmUnblockUser() : _confirmBlockUser(),
        ),
      ],
    );
  }

  Future<void> _confirmBlockUser() async {
    if (_otherPartyId.isEmpty) return;
    bool blocking = false;
    final confirmed = await Dialog3D.show<bool>(
      context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog3D(
          tone: _tone,
          art: ListingArt.speechBalloon,
          title: 'Block this user?',
          body: '$_otherPartyName will no longer be able to message you in any conversation.',
          familyCorner: true,
          tight: true,
          secondaryNeutral: true,
          secondaryLabel: 'Cancel',
          onSecondary: blocking ? null : () => Navigator.pop(ctx, false),
          primaryLabel: 'Block',
          primaryDanger: true,
          primaryLoading: blocking,
          onPrimary: blocking
              ? null
              : () async {
                  setDialogState(() => blocking = true);
                  final ok = await _chatCtrl.blockUser(_otherPartyId);
                  if (ctx.mounted) Navigator.pop(ctx, ok);
                },
        ),
      ),
    );
    if (confirmed == true && mounted) {
      _status.value = 'Blocked';
      _isBlockedByMe.value = true;
    }
  }

  Future<void> _confirmUnblockUser() async {
    if (_otherPartyId.isEmpty) return;
    bool unblocking = false;
    final confirmed = await Dialog3D.show<bool>(
      context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog3D(
          tone: _tone,
          art: ListingArt.speechBalloon,
          title: 'Unblock this user?',
          body: '$_otherPartyName will be able to message you again.',
          familyCorner: true,
          tight: true,
          secondaryNeutral: true,
          secondaryLabel: 'Cancel',
          onSecondary: unblocking ? null : () => Navigator.pop(ctx, false),
          primaryLabel: 'Unblock',
          primaryLoading: unblocking,
          onPrimary: unblocking
              ? null
              : () async {
                  setDialogState(() => unblocking = true);
                  final ok = await _chatCtrl.unblockUser(_otherPartyId);
                  if (ctx.mounted) Navigator.pop(ctx, ok);
                },
        ),
      ),
    );
    if (confirmed == true && mounted) {
      _status.value = 'Active';
      _isBlockedByMe.value = false;
    }
  }

  Widget _buildEmpty() => ListView(
    physics: const NeverScrollableScrollPhysics(),
    children: [
      ChatStateCard3D(
        tone: _tone,
        art: ListingArt.speechBalloon,
        title: 'No messages in this conversation',
        margin: EdgeInsets.fromLTRB(DS.s(36), DS.s(90), DS.s(36), 0),
      ),
    ],
  );

  Widget _buildBubble(MessageModel m) {
    if (TripOfferCards.handles(m.type)) {
      return TripChatCards.build(context, m, isOwner: _isOwner, accent: _accent, callbacks: _tripCallbacks());
    }
    return ChatMessageBubble(
      message: m,
      tone: _tone,
      accent: _accent,
      gradient: _kind.gradient,
      templates: _chatCtrl.questionTemplates,
      onCall: () {
        final phone = m.payload['phone'] as String?;
        if (phone != null) _call(phone);
      },
      isOwner: _isOwner,
      trip: TripChatCards.handles(m.type) ? _tripCallbacks() : null,
    );
  }

  TripChatCallbacks _tripCallbacks() {
    final e = _enquiry.value;
    return TripChatCallbacks(
      listingTitle: _listingTitle,
      agreedTotal: e?.agreedTotalLocked,
      guestName: e?.traveller.name ?? (_isOwner ? _otherPartyName : null),
      guestPhone: e?.traveller.phone,
      hostPhone: e?.owner.phone,
      tripId: e?.tripId,
      day: e?.day,
    );
  }

  Widget _buildInactiveNotice() {
    final isBlockedByMe = _isBlockedByMe.value;
    final text = switch (_status.value) {
      'ListingRemoved' => 'This listing has been removed — you can no longer send messages here.',
      'ListingInactive' => 'This listing is currently inactive — you can no longer send messages here.',
      'Blocked' =>
        isBlockedByMe
            ? "You've blocked this user — they can no longer message you."
            : 'You can no longer message in this conversation.',
      _ => 'This conversation is no longer active.',
    };
    return ChatNoticePanel3D(
      tone: _tone,
      text: text,
      actionLabel: isBlockedByMe ? 'Unblock' : null,
      onAction: _confirmUnblockUser,
    );
  }
}
