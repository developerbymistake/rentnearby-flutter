import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../features/stay/enquiries/stay_enquiry_actions.dart';
import '../features/trip/controllers/trip_enquiry_controller.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/trip_strings_a5.dart';
import '../features/trip/trip_strings_f2.dart';
import '../features/trip/utils/trip_format.dart';
import '../utils/app_toast.dart';
import '../features/trip/widgets/trip_status.dart';
import '../models/browse_item.dart';
import '../models/message_model.dart';
import 'trip_advance_cards.dart';
import 'trip_offer_cards.dart';

class TripChatCallbacks {
  final void Function(String enquiryId, String offerId)? onAccept;
  final void Function(String enquiryId, String offerId)? onDecline;
  final VoidCallback? onAskNewOffer;
  final void Function(String phone)? onCall;
  final void Function(String enquiryId)? onProofSent;
  final void Function(String enquiryId)? onMarkReceived;
  final void Function(String enquiryId)? onNotYet;
  final TripAdvanceModel? advance;
  final String? guestName;
  final String? guestPhone;
  final String? hostPhone;
  final String? tripId;
  final int? day;
  final bool movedOn;
  final String listingTitle;
  final void Function(String enquiryId, String offerId)? onAcceptPrice;
  final void Function(String enquiryId, String offerId)? onSendDifferentOffer;
  final void Function(String enquiryId, String offerId)? onAcceptNewPrice;
  final void Function(String enquiryId, String offerId)? onKeepPrice;
  final void Function(String enquiryId)? onCancelStay;
  final void Function(String enquiryId, String offerId)? onAcceptChange;
  final VoidCallback? onEnquiryChanged;
  final int? agreedTotal;

  const TripChatCallbacks({
    this.onAccept,
    this.onDecline,
    this.onAskNewOffer,
    this.onCall,
    this.onProofSent,
    this.onMarkReceived,
    this.onNotYet,
    this.advance,
    this.guestName,
    this.guestPhone,
    this.hostPhone,
    this.tripId,
    this.day,
    this.movedOn = false,
    this.listingTitle = '',
    this.onAcceptPrice,
    this.onSendDifferentOffer,
    this.onAcceptNewPrice,
    this.onKeepPrice,
    this.onCancelStay,
    this.onAcceptChange,
    this.onEnquiryChanged,
    this.agreedTotal,
  });

  bool get ownerActionsEnabled => onAcceptPrice != null;
}

class TripChatCards {
  static const _types = {
    'trip_enquiry',
    'trip_offer',
    'trip_offer_response',
    TripAdvanceCards.requestType,
    TripAdvanceCards.proofType,
    TripOfferCards.counterType,
    TripOfferCards.revisedType,
    TripOfferCards.changeType,
  };

  static bool handles(String type) => _types.contains(type);

  static Widget build(
    BuildContext context,
    MessageModel message, {
    required bool isOwner,
    required Color accent,
    TripChatCallbacks? callbacks,
  }) {
    final cb = callbacks ?? const TripChatCallbacks();
    final p = message.payload;
    switch (message.type) {
      case 'trip_enquiry':
        final enquiryId = _str(p, 'enquiryId');
        if (enquiryId == null || _range(p) == null) return bubble(message, _str(p, 'text') ?? '');
        return _EnquiryCard(
          key: ValueKey('trip-enquiry-${message.id}'),
          message: message,
          enquiryId: enquiryId,
          isOwner: isOwner,
          accent: accent,
          callbacks: cb,
        );
      case 'trip_offer':
        return _offer(context, message, p, isOwner, accent, cb);
      case 'trip_offer_response':
        return bubble(message, _offerResponseText(p));
      case TripAdvanceCards.requestType:
        return TripAdvanceCards.request(context, message, isOwner: isOwner, accent: accent, callbacks: cb);
      case TripAdvanceCards.proofType:
        return TripAdvanceCards.proofSent(context, message, isOwner: isOwner, accent: accent, callbacks: cb);
      case TripOfferCards.counterType:
        return TripOfferCards.counter(context, message, isOwner: isOwner, accent: accent, callbacks: cb);
      case TripOfferCards.revisedType:
        return TripOfferCards.revised(context, message, isOwner: isOwner, accent: accent, callbacks: cb);
      case TripOfferCards.changeType:
        return TripOfferCards.changeRequest(context, message, isOwner: isOwner, accent: accent, callbacks: cb);
      default:
        return const SizedBox.shrink();
    }
  }

  static String _offerResponseText(Map<String, dynamic> p) {
    if (_str(p, 'answer') != 'accepted') return TripStrings.offerDeclined;
    final total = _num(p, 'total');
    final range = _range(p);
    return TripStrings.offerAccepted(total == null ? '' : BrowseItem.inr(total), range ?? '');
  }

  static Widget wrap(MessageModel m, Widget card) {
    final recent = DateTime.now().difference(m.createdAt).inSeconds.abs() < 10;
    return RepliesEntrance(
      animate: recent,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: card),
    );
  }

  static Widget bubble(MessageModel m, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: ChatBubble3D(
          tone: ListingTone.forest,
          text: text,
          mine: m.isMine,
          ticks: m.isMine ? (m.readAt != null ? ChatTicks.read : ChatTicks.sent) : ChatTicks.none,
        ),
      );

  // ── offer ────────────────────────────────────────────────────────────────

  static Widget _offer(BuildContext context, MessageModel m, Map<String, dynamic> p, bool isOwner, Color accent,
      TripChatCallbacks cb) {
    final wireStatus = _str(p, 'status') ?? 'pending';
    final validUntil = DateTime.tryParse(_str(p, 'validUntil') ?? '');
    final clockExpired = wireStatus == 'pending' && validUntil != null && !validUntil.isAfter(DateTime.now().toUtc());
    final status = clockExpired ? 'expired' : wireStatus;
    final enquiryId = _str(p, 'enquiryId');
    final offerId = _str(p, 'offerId');
    final lines = _list(p, 'lines').whereType<Map>().toList();
    final total = _num(p, 'total');
    final nights = _int(p, 'nights');
    final range = _range(p);
    final advance = _num(p, 'advanceAmount');
    final balanceNote = _str(p, 'balanceNote');
    final cancelText = _str(p, 'cancellationText');
    final inclusions = _str(p, 'inclusions');
    final gst = p['gstInvoice'] == true;
    final differs = p['datesDiffer'] == true;
    final pending = status == 'pending';

    final canAct = !isOwner && pending && enquiryId != null && offerId != null;
    final canAskNew = !isOwner && status == 'expired' && cb.onAskNewOffer != null;

    final title = cb.listingTitle.isEmpty ? TripStrings.offer : '${TripStrings.offer} · ${cb.listingTitle}';
    final pill = _offerPill(status, isOwner, validUntil);

    final ReplyAction primary;
    final ReplyAction secondary;
    if (canAskNew) {
      primary = ReplyAction(label: TripStrings.askNewOffer, onTap: cb.onAskNewOffer);
      secondary = const ReplyAction(label: TripStrings.decline);
    } else {
      primary = ReplyAction(
          label: TripStrings.acceptOffer, onTap: canAct && cb.onAccept != null ? () => cb.onAccept!(enquiryId, offerId) : null);
      secondary = ReplyAction(
          label: TripStrings.decline, onTap: canAct && cb.onDecline != null ? () => cb.onDecline!(enquiryId, offerId) : null);
    }

    return wrap(
      m,
      ChatTripCard3D(
        status: pill.$1,
        art: ListingArt.hotel,
        pill: pill.$2,
        title: title,
        line: [if (nights != null) TripStrings.nights(nights), ?range].join(' · '),
        rows: [
          if (total != null) ReplyRow(TripStrings.total, BrowseItem.inr(total)),
          if (advance != null && advance > 0) ReplyRow(TripStrings.advance, BrowseItem.inr(advance)),
          if (balanceNote != null && balanceNote.isNotEmpty) ReplyRow(TripStrings.balance, balanceNote),
          if (cancelText != null && cancelText.isNotEmpty) ReplyRow(TripStrings.cancellationTerms, cancelText),
          if (gst) const ReplyRow(TripStrings.gstInvoice, TripStrings.yes),
        ],
        extra: [
          if (differs && range != null) TripStrings.datesDiffer(range),
          for (final l in lines) _offerLine(l),
          if (inclusions != null && inclusions.isNotEmpty) inclusions,
          TripStrings.stayPayLine,
        ],
        note: TripStrings.termsByHost,
        primary: primary,
        secondary: secondary,
        showActions: !isOwner,
        mine: m.isMine,
        read: m.readAt != null,
      ),
    );
  }

  static (StatusTone3D, String) _offerPill(String status, bool isOwner, DateTime? validUntil) {
    switch (status) {
      case 'accepted':
        return (StatusTone3D.both, TripStrings.accepted);
      case 'declined':
        return (StatusTone3D.red, TripStrings.declined);
      case 'expired':
        return (StatusTone3D.red, TripStrings.expired);
      case 'superseded':
        return (StatusTone3D.closed, TripStrings.replaced);
      default:
        final t = validUntil == null ? null : _remaining(validUntil);
        return (StatusTone3D.waiting, t == null ? TripStrings.offer : TripStrings.validFor(t));
    }
  }

  static String _offerLine(Map line) {
    final room = (line['roomName'] as String?)?.trim();
    final units = (line['units'] as num?)?.toInt() ?? 1;
    final guests = (line['guests'] as num?)?.toInt();
    final price = line['pricePerNight'] as num?;
    final name = (room == null || room.isEmpty) ? TripStrings.room : room;
    final priceText = price == null ? '' : ' · ${TripStringsA5.unitsAtPrice(units, BrowseItem.inr(price))}';
    return '$name$priceText${guests == null ? '' : ' · ${TripStrings.guests} $guests'}';
  }

  static String? _str(Map<String, dynamic> p, String k) {
    final v = p[k];
    return v is String ? v : null;
  }

  static num? _num(Map<String, dynamic> p, String k) {
    final v = p[k];
    return v is num ? v : null;
  }

  static int? _int(Map<String, dynamic> p, String k) => _num(p, k)?.toInt();

  static List<dynamic> _list(Map<String, dynamic> p, String k) {
    final v = p[k];
    return v is List ? v : const [];
  }

  static String? _range(Map<String, dynamic> p) {
    final a = DateTime.tryParse(_str(p, 'checkIn') ?? '');
    final b = DateTime.tryParse(_str(p, 'checkOut') ?? '');
    if (a == null || b == null) return null;
    return TripFormat.dateRange(a, b);
  }

  static String _remaining(DateTime until) {
    final left = until.difference(DateTime.now().toUtc());
    if (left.inMinutes < 1) return '1 min';
    if (left.inHours < 1) return '${left.inMinutes} min';
    return '${left.inHours} h';
  }
}

class _EnquiryCard extends StatefulWidget {
  const _EnquiryCard({
    super.key,
    required this.message,
    required this.enquiryId,
    required this.isOwner,
    required this.accent,
    required this.callbacks,
  });

  final MessageModel message;
  final String enquiryId;
  final bool isOwner;
  final Color accent;
  final TripChatCallbacks callbacks;

  @override
  State<_EnquiryCard> createState() => _EnquiryCardState();
}

class _EnquiryCardState extends State<_EnquiryCard> {
  static const _fresh = Duration(seconds: 60);
  static final _cache = <String, ({TripEnquiryModel enquiry, DateTime at})>{};

  TripEnquiryModel? _enquiry;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final hit = _cache[widget.enquiryId];
    _enquiry = hit?.enquiry;
    if (hit == null || DateTime.now().difference(hit.at) > _fresh) _load();
  }

  Future<TripEnquiryModel?> _load() async {
    final e = await TripEnquiryController.to.refreshOne(widget.enquiryId);
    if (e != null) _cache[widget.enquiryId] = (enquiry: e, at: DateTime.now());
    if (mounted && e != null) setState(() => _enquiry = e);
    return e;
  }

  Future<void> _run(Future<bool> Function(TripEnquiryModel e) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final e = await _load();
      if (!mounted) return;
      if (e == null) {
        AppToast.warning(TripStrings.noNetwork);
        return;
      }
      if (!e.isUnconfirmed) {
        AppToast.warning(TripStrings.justChanged);
        widget.callbacks.onEnquiryChanged?.call();
        return;
      }
      if (await action(e)) {
        await _load();
        widget.callbacks.onEnquiryChanged?.call();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.message.payload;
    final cb = widget.callbacks;
    final e = _enquiry;
    final checkIn = DateTime.tryParse(TripChatCards._str(p, 'checkIn') ?? '');
    final checkOut = DateTime.tryParse(TripChatCards._str(p, 'checkOut') ?? '');
    final nights = TripChatCards._int(p, 'nights') ??
        (checkIn != null && checkOut != null ? checkOut.difference(checkIn).inDays : null);
    final adults = TripChatCards._int(p, 'adults');
    final kids = TripChatCards._int(p, 'kids') ?? 0;
    final rooms = TripChatCards._int(p, 'rooms');
    final text = TripChatCards._str(p, 'text');
    final title =
        cb.listingTitle.isEmpty ? TripStringsF2.stayEnquiry : '${TripStringsF2.stayEnquiry} · ${cb.listingTitle}';
    final display = e?.display ?? TripDisplayStatus.asked;
    final canAct = widget.isOwner && cb.ownerActionsEnabled && e != null && !e.isTaxi && e.isUnconfirmed;
    final live = canAct && !_busy;
    return TripChatCards.wrap(
      widget.message,
      ChatTripCard3D(
        status: StatusTone3D.of(display.name),
        art: ListingArt.luggage,
        pill: TripStatusVisuals.label(display, ownerSide: widget.isOwner),
        title: title,
        line: [
          if (nights != null && nights > 0) TripStrings.nights(nights),
          if (rooms != null) TripStringsF2.roomsCount(rooms),
        ].join(' · '),
        rows: [
          if (checkIn != null) ReplyRow(TripStrings.checkIn, TripFormat.shortDate(checkIn)),
          if (checkOut != null) ReplyRow(TripStrings.checkOut, TripFormat.shortDate(checkOut)),
          if (adults != null) ReplyRow(TripStrings.people, TripStrings.peopleCount(adults + kids)),
        ],
        note: text != null && text.isNotEmpty ? text : null,
        noteArt: ListingArt.roundPushpin,
        primary: ReplyAction(
          label: display == TripDisplayStatus.offered ? TripStrings.sendNewOffer : TripStrings.sendOffer,
          busy: canAct && _busy,
          onTap: live ? () => _run((x) => StayEnquiryActions.sendOffer(context, x)) : null,
        ),
        secondary: ReplyAction(
          label: TripStrings.notAvailableAction,
          onTap: live ? () => _run((x) => StayEnquiryActions.notAvailable(context, x)) : null,
        ),
        showActions: widget.isOwner,
        mine: widget.message.isMine,
        read: widget.message.readAt != null,
      ),
    );
  }
}
