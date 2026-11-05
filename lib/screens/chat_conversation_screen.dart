import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/chat_controller.dart';
import '../features/stay/enquiries/host_confirm_dialog.dart';
import '../features/stay/enquiries/stay_enquiries_controller.dart';
import '../features/stay/enquiries/stay_enquiry_actions.dart';
import '../features/stay/enquiries/trip_owner_action_bar.dart';
import '../features/trip/controllers/trip_enquiry_controller.dart';
import '../features/trip/data/trip_enquiry_repository.dart';
import '../features/trip/controllers/trip_plan_controller.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_navigation.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/utils/trip_report.dart';
import '../features/trip/widgets/trip_accept_sheet.dart';
import '../features/trip/widgets/trip_cancel_sheet.dart';
import '../features/trip/widgets/trip_change_request_sheet.dart';
import '../features/trip/widgets/trip_counter_sheet.dart';
import '../features/trip/widgets/trip_enquiry_strip.dart';
import '../features/trip/widgets/trip_withdraw_sheet.dart';
import '../models/browse_item.dart';
import '../models/message_model.dart';
import '../models/question_template_model.dart';
import '../services/chat_hub_service.dart';
import '../services/notification_service.dart';
import '../utils/app_toast.dart';
import '../utils/contact_launcher.dart';
import '../utils/listing_kind_visuals.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_next_slot_bubble.dart';
import '../widgets/chat_plus_menu_sheet.dart';
import '../widgets/chat_schedule_picker_sheet.dart';
import '../widgets/trip_chat_cards.dart';
import '../widgets/trip_offer_cards.dart';
import '../widgets/trip_report_traveller_sheet.dart';

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
  Color get _accent => ListingKindVisuals.accentOf(_listingType);
  late final String? _roomTypeId;
  late final String? _plotTypeId;
  late final String? _stayTypeId;
  late final String _otherPartyId;
  late final String _otherPartyName;
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
  bool _movedOn = false;
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
    _roomTypeId = text('roomTypeId') ?? known?.roomTypeId;
    _plotTypeId = text('plotTypeId') ?? known?.plotTypeId;
    _stayTypeId = text('stayTypeId') ?? known?.stayTypeId;
    _otherPartyId = text('otherPartyId') ?? known?.otherPartyId ?? '';
    _otherPartyName = text('otherPartyName') ?? known?.otherPartyName ?? 'User';
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
    _chatCtrl.loadQuestionTemplates();
    // Runs regardless of how this screen was reached (notification tap or a plain manual
    // tap from the Chats list) — the one place that reliably fires every time this
    // conversation is actually opened, so a message already read in-app never resurfaces
    // stacked under a future chat notification for this same thread.
    NotificationService.to.dismissChatNotification(_conversationId);

    _incomingWorker = ever<MessageModel?>(_chatCtrl.incomingMessage, (m) {
      if (m == null || m.conversationId != _conversationId || !mounted) return;
      _insertIfNew(m);
      if (_affectsEnquiry(m)) _refreshEnquiry();
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

  Future<void> _openStrip(TripEnquiryModel e) async {
    if (_isOwner) {
      Get.toNamed(AppRoutes.stayEnquiries, arguments: {'enquiryId': e.id});
      return;
    }
    await _openReplies(e);
  }

  Future<void> _openReplies(TripEnquiryModel e) async {
    final tripId = e.tripId;
    if (tripId == null) {
      AppToast.info(TripStrings.closed);
      return;
    }
    final plan = TripPlanController.to;
    if (plan.trip.value?.id != tripId) await plan.open(tripId);
    if (!mounted) return;
    TripNavigation.openReplies(plan.dayOfDate(e.checkIn) ?? e.day ?? 1, enquiryId: e.id);
  }

  Future<void> _onStripAction(String id, TripEnquiryModel e) async {
    switch (id) {
      case TripStripAction.withdraw:
        if (await TripWithdrawSheet.show(context, enquiry: e)) _refreshEnquiry();
      case TripStripAction.phoneBooking:
      case TripStripAction.editBooking:
        await _openReplies(e);
      case TripStripAction.copyLink when _cachedLink(e.id) != null:
        await Clipboard.setData(ClipboardData(text: _cachedLink(e.id)!.confirmLink));
        AppToast.success(TripStrings.linkCopied);
      case TripStripAction.resendLink:
      case TripStripAction.copyLink:
        final res = await TripEnquiryController.to.resendLink(e.id);
        if (res == null) return;
        if (Get.isRegistered<TripPlanController>()) Get.find<TripPlanController>().rememberLink(res);
        _refreshEnquiry();
        final phone = e.phoneBooking?.hostPhone;
        if (id == TripStripAction.resendLink && phone != null && phone.isNotEmpty) {
          await ContactLauncher.whatsApp(phone, message: res.whatsAppText);
        } else {
          await Clipboard.setData(ClipboardData(text: res.confirmLink));
          AppToast.success(TripStrings.linkCopied);
        }
      case TripStripAction.cancel:
        if (await TripCancelSheet.show(context, enquiry: e, ownerSide: false)) _refreshEnquiry();
      case TripStripAction.callHost:
        final phone = e.owner.phone;
        if (phone != null && phone.isNotEmpty) await ContactLauncher.call(phone);
      case TripStripAction.report:
        await _reportHost(e.listingId, enquiryId: e.id);
      case TripStripAction.counter:
        if (await TripCounterSheet.show(context, enquiry: e)) _refreshEnquiry();
      case TripStripAction.changeRequest:
        if (await TripChangeRequestSheet.show(context, enquiry: e)) _refreshEnquiry();
    }
  }

  TripPhoneBookingResult? _cachedLink(String enquiryId) =>
      Get.isRegistered<TripPlanController>() ? Get.find<TripPlanController>().confirmLinks[enquiryId] : null;

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

  Future<TripEnquiryModel?> _freshEnquiry(String enquiryId) async {
    final enq = await TripEnquiryController.to.refreshOne(enquiryId);
    if (!mounted) return null;
    if (enq == null) {
      AppToast.warning(TripStrings.noNetwork);
      return null;
    }
    if (enq.conversationId == _conversationId) _enquiry.value = enq;
    return enq;
  }

  void _changed() {
    AppToast.warning(TripStrings.justChanged);
    _refreshEnquiry();
  }

  Future<void> _guardAction(String key, Future<void> Function() run) async {
    if (!_pendingActionMessageIds.add(key)) return;
    try {
      await run();
    } finally {
      _pendingActionMessageIds.remove(key);
    }
  }

  Future<void> _hostAcceptPrice(String messageId, String enquiryId, String offerId) => _guardAction(messageId, () async {
        final enq = await _freshEnquiry(enquiryId);
        if (enq == null || !mounted) return;
        final counter = enq.pendingCounter;
        if (counter == null || counter.id != offerId) {
          _changed();
          return;
        }
        if (await StayEnquiryActions.sendOffer(context, enq, counter: counter)) _refreshEnquiry();
      });

  Future<void> _hostDifferentOffer(String messageId, String enquiryId, String offerId) => _guardAction(messageId, () async {
        final enq = await _freshEnquiry(enquiryId);
        if (enq == null || !mounted) return;
        final change = enq.pendingChange;
        if (change != null && change.id == offerId) {
          if (await StayEnquiryActions.revisedOffer(context, enq, changeRequest: change)) _refreshEnquiry();
          return;
        }
        final counter = enq.pendingCounter;
        if (counter == null || counter.id != offerId || !enq.isUnconfirmed) {
          _changed();
          return;
        }
        if (await StayEnquiryActions.sendOffer(context, enq)) _refreshEnquiry();
      });

  Future<void> _hostAcceptChange(String messageId, String enquiryId, String offerId) => _guardAction(messageId, () async {
        final enq = await _freshEnquiry(enquiryId);
        if (enq == null || !mounted) return;
        final change = enq.pendingChange;
        if (change == null || change.id != offerId) {
          _changed();
          return;
        }
        if (await StayEnquiryActions.acceptChange(context, enq, offerId)) _refreshEnquiry();
      });

  Future<void> _acceptNewPrice(String messageId, String enquiryId, String offerId) => _guardAction(messageId, () async {
        final enq = await _freshEnquiry(enquiryId);
        if (enq == null || !mounted) return;
        final revised = enq.pendingRevised;
        if (revised == null || revised.id != offerId) {
          _changed();
          return;
        }
        if (await TripAcceptSheet.show(context, enquiry: enq, offer: revised)) _refreshEnquiry();
      });

  Future<void> _keepPrice(String messageId, String enquiryId, String offerId) => _guardAction(messageId, () async {
        final cached = _enquiry.value;
        final enq = cached != null && cached.id == enquiryId ? cached : await _freshEnquiry(enquiryId);
        if (enq == null || !mounted) return;
        final money = BrowseItem.inr(enq.agreedTotalLocked ?? 0);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(TripStrings.keepPriceQ(money),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
            content: const Text(TripStrings.keepPriceBody,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.4)),
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(TripStrings.cancelAction, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(TripStrings.keepPrice(money),
                    style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textDark, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        if (await TripEnquiryController.to.keepPrice(enquiryId, offerId)) _refreshEnquiry();
      });

  Future<void> _cancelStay(String messageId, String enquiryId) => _guardAction(messageId, () async {
        final cached = _enquiry.value;
        final enq = cached != null && cached.id == enquiryId ? cached : await _freshEnquiry(enquiryId);
        if (enq == null || !mounted) return;
        if (await TripCancelSheet.show(context, enquiry: enq, ownerSide: false)) _refreshEnquiry();
      });

  Future<void> _acceptOffer(String messageId, String enquiryId, String offerId) async {
    if (!_pendingActionMessageIds.add(messageId)) return;
    try {
      final enq = await TripEnquiryController.to.refreshOne(enquiryId);
      if (!mounted) return;
      final offer = enq?.openOffer;
      if (enq == null || offer == null || offer.id != offerId) {
        AppToast.warning(enq == null ? TripStrings.noNetwork : TripStrings.justChanged);
        _refreshEnquiry();
        return;
      }
      if (await TripAcceptSheet.show(context, enquiry: enq, offer: offer)) _refreshEnquiry();
    } finally {
      _pendingActionMessageIds.remove(messageId);
    }
  }

  Future<void> _declineOffer(String messageId, String enquiryId, String offerId) async {
    if (!_pendingActionMessageIds.add(messageId)) return;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(TripStrings.declineQuestion,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
          content: const Text(TripStrings.declineNote,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.4)),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(TripStrings.keep, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(TripStrings.decline,
                  style: TextStyle(fontFamily: 'Poppins', color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      if (await TripEnquiryController.to.decline(enquiryId, offerId)) _refreshEnquiry();
    } finally {
      _pendingActionMessageIds.remove(messageId);
    }
  }

  Future<void> _hostAnswer(String messageId, String enquiryId, bool confirm) async {
    if (!_pendingActionMessageIds.add(messageId)) return;
    try {
      final cached = _enquiry.value;
      final enq = cached != null && cached.id == enquiryId ? cached : await TripEnquiryController.to.refreshOne(enquiryId);
      if (enq == null || !mounted) return;
      final ok = await HostConfirmDialog.show(context, confirm: confirm, enquiry: enq);
      if (ok != true) return;
      final done = await StayEnquiriesController.ensure().hostConfirm(enquiryId, confirm: confirm);
      if (done) _refreshEnquiry();
    } finally {
      _pendingActionMessageIds.remove(messageId);
    }
  }

  Future<void> _proofSent(String enquiryId) async {
    if (!_pendingActionMessageIds.add('proof:$enquiryId')) return;
    try {
      if (await TripEnquiryController.to.proofSent(enquiryId)) _refreshEnquiry();
    } finally {
      _pendingActionMessageIds.remove('proof:$enquiryId');
    }
  }

  Future<void> _markReceived(String enquiryId) async {
    if (!_pendingActionMessageIds.add('recv:$enquiryId')) return;
    try {
      final ctrl = StayEnquiriesController.ensure();
      if (await ctrl.markReceived(enquiryId)) {
        if (mounted) setState(() => _movedOn = false);
      } else if (ctrl.lastErrorType == TripEnquiryErrorTypes.travellerMovedOn && mounted) {
        setState(() => _movedOn = true);
      }
      _refreshEnquiry();
    } finally {
      _pendingActionMessageIds.remove('recv:$enquiryId');
    }
  }

  Future<void> _notYet(String enquiryId) async {
    if (!_pendingActionMessageIds.add('notyet:$enquiryId')) return;
    try {
      if (await StayEnquiriesController.ensure().notYet(enquiryId)) _refreshEnquiry();
    } finally {
      _pendingActionMessageIds.remove('notyet:$enquiryId');
    }
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
                    targetStayTypeId: _stayTypeId,
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
        accent: _accent,
      );
    } finally {
      _openingPlusMenu = false;
    }
  }

  Future<void> _send(String type, Map<String, dynamic> payload) async {
    // The "single-flight" claim on _sending's own field comment only held because every
    // CALLER happened to gate its own trigger (ChatNextSlotBubble's sending-disabled tap, the
    // plus-menu sheet dismissing before firing) — a fast double-tap on the same still-open
    // sheet item before it's actually removed from the hit-test tree could invoke this twice
    // concurrently, each minting its own clientMessageId, so the server-side idempotency key
    // couldn't collapse them into one message. This guard makes the method actually enforce
    // the invariant instead of trusting every caller to.
    if (_sending.value) return;
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
      'proposedAts': picked.map((d) => d.toUtc().toIso8601String()).toList(),
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
        backgroundColor: AppColors.surfaceWarm,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      body: Column(
        children: [
          _buildHeader(context),
          if (_isStay) _buildTripStrip(),
          _buildSafetyStrip(),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: Obx(() {
                      if (_loading.value) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: _accent,
                          ),
                        );
                      }
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
                        color: _accent,
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

  Widget _buildTripStrip() => Obx(() {
        final e = _enquiry.value;
        if (e == null) return const SizedBox.shrink();
        return TripEnquiryStrip(
          enquiry: e,
          ownerSide: _isOwner,
          onTap: () => _openStrip(e),
          actions: _isOwner ? const [] : TripStripAction.forTraveller(e, linkCached: _cachedLink(e.id) != null),
          onAction: _isOwner ? null : (id) => _onStripAction(id, e),
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
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
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
      items.add(
        _animatedBubble(m.id, _buildBubble(m, answered: answer != null)),
      );
      if (answer != null) {
        items.add(_animatedBubble(answer.id, _buildBubble(answer)));
      }
    }
    // The "next slot" bubble — the inline replacement for the old fixed composer — goes
    // last, chronologically after every message currently in the thread, for both roles
    // alike. On a short/new conversation this is what makes it sit right under the last
    // message near the TOP of the screen (matching chat-live-demo-v4.html's plain
    // flex-column thread) instead of being glued to the bottom of the screen.
    if (_status.value == 'Active') {
      final enquiry = _enquiry.value;
      if (_isOwner && enquiry != null) {
        items.add(
          KeyedSubtree(
            key: const ValueKey('trip-owner-bar'),
            child: TripOwnerActionBar(enquiry: enquiry, onChanged: _refreshEnquiry),
          ),
        );
      }
      items.add(
        KeyedSubtree(
          key: const ValueKey('ghost-slot'),
          child: Obx(
            () => ChatNextSlotBubble(
              onTap: _openPlusMenu,
              sending: _sending.value,
              accent: _accent,
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
      decoration: BoxDecoration(gradient: ListingKindVisuals.gradientOf(_listingType)),
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
                      '${_listingType == 'Plot' ? '📍' : _listingType == 'Stay' ? '🏡' : '🏠'} $_listingTitle'
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
              // Either party can block the other (the backend has no owner/renter
              // restriction on BlockUser) — no _isOwner gate here.
              Obx(() {
                  // Keyed off whether THIS user did the blocking, not the generic Blocked
                  // status — if the other party blocked me, offering me a "Block this user"
                  // action (an independent, still-meaningful choice) is correct; offering
                  // "Unblock" would be wrong (and a no-op server-side, since UnblockUser
                  // only ever undoes a block the caller themselves placed).
                  final isBlocked = _isBlockedByMe.value;
                  return PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                    ),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (v) {
                      if (v == 'report') {
                        _isOwner ? _reportTraveller() : _reportHost(_listingId);
                      } else {
                        isBlocked ? _confirmUnblockUser() : _confirmBlockUser();
                      }
                    },
                    itemBuilder: (_) => [
                      if (_isStay && (!_isOwner || _enquiry.value != null))
                        const PopupMenuItem(
                          value: 'report',
                          height: 48,
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, size: 18, color: AppColors.textMedium),
                              SizedBox(width: 10),
                              Text(TripStrings.report, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textDark)),
                            ],
                          ),
                        ),
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
    if (confirmed == true && mounted) {
      _status.value = 'Blocked';
      _isBlockedByMe.value = true; // this device is the one that just did the blocking
    }
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
    if (confirmed == true && mounted) {
      _status.value = 'Active';
      _isBlockedByMe.value = false;
    }
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
    // A blocked/inactive conversation must disable every response action, not just show a
    // notice below the list — the backend now rejects these calls too (see RespondContact/
    // RespondSchedule's Status check), so a stale-rendered button must never stay tappable.
    final conversationActive = _status.value == 'Active';
    // ChatMessageBubble has no case for these card types, so they are built here.
    if (TripOfferCards.handles(m.type)) {
      return TripChatCards.build(
        context,
        m,
        isOwner: _isOwner,
        accent: _accent,
        callbacks: _tripCallbacks(m, pending: pending, active: conversationActive),
      );
    }
    final canAnswer =
        !answered && !pending && conversationActive && m.type == 'quick_reply' && (_isOwner || !m.isMine);
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
      accent: _accent,
      templates: _chatCtrl.questionTemplates,
      onAnswerQuestion: canAnswer
          ? (answerKey, answerText) =>
                _answerQuestion(m.id, answerKey, answerText)
          : null,
      // No owner/renter restriction — either side can send a contact request and whoever
      // receives it can respond, same shape as the schedule gating below.
      onApproveContact: (isContactRequest && !m.isMine && !contactAlreadyResponded && !pending && conversationActive)
          ? () => _respondContact(m.id, true)
          : null,
      onDeclineContact: (isContactRequest && !m.isMine && !contactAlreadyResponded && !pending && conversationActive)
          ? () => _respondContact(m.id, false)
          : null,
      onAcceptSlot: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded && !pending && conversationActive
          ? (dt) => _acceptScheduleSlot(m.id, dt)
          : null,
      onDeclineSchedule: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded && !pending && conversationActive
          ? () => _declineSchedule(m.id)
          : null,
      onCounterSchedule: isScheduleProposal && !m.isMine && !scheduleAlreadyResponded && !pending && conversationActive
          ? () => _counterSchedule(m.id)
          : null,
      onCall: () {
        final phone = m.payload['phone'] as String?;
        if (phone != null) _call(phone);
      },
      isOwner: _isOwner,
      trip: TripChatCards.handles(m.type) ? _tripCallbacks(m, pending: pending, active: conversationActive) : null,
    );
  }

  TripChatCallbacks _tripCallbacks(MessageModel m, {required bool pending, required bool active}) {
    final enabled = active && !pending;
    return TripChatCallbacks(
      listingTitle: _listingTitle,
      onAccept: enabled && !_isOwner ? (e, o) => _acceptOffer(m.id, e, o) : null,
      onDecline: enabled && !_isOwner ? (e, o) => _declineOffer(m.id, e, o) : null,
      onAskNewOffer: active && !_isOwner ? _openPlusMenu : null,
      onHostYes: enabled && _isOwner ? (e) => _hostAnswer(m.id, e, true) : null,
      onHostNotMe: enabled && _isOwner ? (e) => _hostAnswer(m.id, e, false) : null,
      onProofSent: enabled && !_isOwner ? _proofSent : null,
      onMarkReceived: enabled && _isOwner ? _markReceived : null,
      onNotYet: enabled && _isOwner ? _notYet : null,
      onAcceptPrice: enabled && _isOwner ? (e, o) => _hostAcceptPrice(m.id, e, o) : null,
      onSendDifferentOffer: enabled && _isOwner ? (e, o) => _hostDifferentOffer(m.id, e, o) : null,
      onAcceptChange: enabled && _isOwner ? (e, o) => _hostAcceptChange(m.id, e, o) : null,
      onAcceptNewPrice: enabled && !_isOwner ? (e, o) => _acceptNewPrice(m.id, e, o) : null,
      onKeepPrice: enabled && !_isOwner ? (e, o) => _keepPrice(m.id, e, o) : null,
      onCancelStay: enabled && !_isOwner ? (e) => _cancelStay(m.id, e) : null,
      agreedTotal: _enquiry.value?.agreedTotalLocked,
      advance: _enquiry.value?.advance,
      guestName: _enquiry.value?.traveller.name ?? (_isOwner ? _otherPartyName : null),
      guestPhone: _enquiry.value?.traveller.phone,
      hostPhone: _enquiry.value?.owner.phone,
      tripId: _enquiry.value?.tripId,
      day: _enquiry.value?.day,
      movedOn: _movedOn,
    );
  }

  Widget _buildInactiveNotice() {
    final isBlockedByMe = _isBlockedByMe.value;
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
        color: AppColors.cardBg,
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
