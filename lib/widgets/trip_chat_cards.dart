import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../features/stay/enquiries/stay_enquiry_actions.dart';
import '../features/trip/controllers/trip_enquiry_controller.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/trip_strings_a5.dart';
import '../features/trip/trip_strings_f2.dart';
import '../features/trip/utils/trip_format.dart';
import '../utils/app_toast.dart';
import '../features/trip/widgets/trip_payment_line.dart';
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
        if (enquiryId == null || _range(p) == null) return _bubble(message, _str(p, 'text') ?? '', accent);
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
        return _bubble(message, _offerResponseText(p), accent);
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

    return _card(
      context,
      mine: m.isMine,
      readAt: m.readAt,
      createdAt: m.createdAt,
      accent: accent,
      icon: TravelIcon.money,
      title: title,
      pill: _offerPill(status, isOwner, validUntil),
      children: [
        if (differs && range != null) ...[
          _note(TripStrings.datesDiffer(range)),
          const SizedBox(height: 8),
        ],
        for (final l in lines) _offerLine(l),
        if (nights != null || range != null) ...[
          const SizedBox(height: 4),
          Text(
            [if (nights != null) TripStrings.nights(nights), if (range != null) range].join(' · '),
            style: _small,
          ),
        ],
        if (total != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Text(TripStrings.total, style: _small),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(BrowseItem.inr(total),
                      style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName, fontSize: 22, fontWeight: FontWeight.w700, color: DesignColors.primary)),
                ),
              ),
            ),
          ]),
        ],
        if (advance != null && advance > 0) ...[
          const SizedBox(height: 8),
          _kv(TripStrings.advance, BrowseItem.inr(advance)),
        ],
        if (balanceNote != null && balanceNote.isNotEmpty) _kv(TripStrings.balance, balanceNote),
        if (cancelText != null && cancelText.isNotEmpty) _kv(TripStrings.cancellationTerms, cancelText),
        if (gst) _kv(TripStrings.gstInvoice, TripStrings.yes),
        if (inclusions != null && inclusions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(inclusions, style: _body),
        ],
        const SizedBox(height: 8),
        const Text(TripStrings.termsByHost,
            style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: DesignColors.textMuted, height: 1.35)),
        if (canAct) ...[
          const SizedBox(height: 12),
          _button(TripStrings.acceptOffer,
              primary: true,
              accent: accent,
              onTap: cb.onAccept == null ? null : () => cb.onAccept!(enquiryId, offerId)),
          const SizedBox(height: 8),
          _button(TripStrings.decline,
              primary: false,
              accent: accent,
              negative: true,
              onTap: cb.onDecline == null ? null : () => cb.onDecline!(enquiryId, offerId)),
        ],
        if (canAskNew) ...[
          const SizedBox(height: 12),
          _button(TripStrings.askNewOffer, primary: false, accent: accent, onTap: cb.onAskNewOffer),
        ],
        const SizedBox(height: 10),
        const TripPaymentLine(),
      ],
    );
  }

  static Widget _offerPill(String status, bool isOwner, DateTime? validUntil) {
    switch (status) {
      case 'accepted':
        return TripStatusPill(TripDisplayStatus.confirmedByBoth, label: TripStrings.accepted);
      case 'declined':
        return TripStatusPill(TripDisplayStatus.declined, ownerSide: isOwner, label: TripStrings.declined);
      case 'expired':
        return const TripStatusPill(TripDisplayStatus.expired, label: TripStrings.expired);
      case 'superseded':
        return const TripStatusPill(TripDisplayStatus.closed, label: TripStrings.replaced);
      default:
        final t = validUntil == null ? null : _remaining(validUntil);
        return TripStatusPill(TripDisplayStatus.offered, label: t == null ? TripStrings.offer : TripStrings.validFor(t));
    }
  }

  static Widget _offerLine(Map line) {
    final room = (line['roomName'] as String?)?.trim();
    final units = (line['units'] as num?)?.toInt() ?? 1;
    final guests = (line['guests'] as num?)?.toInt();
    final price = line['pricePerNight'] as num?;
    final name = (room == null || room.isEmpty) ? TripStrings.room : room;
    final priceText = price == null ? '' : ' · ${TripStringsA5.unitsAtPrice(units, BrowseItem.inr(price))}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$name$priceText${guests == null ? '' : ' · ${TripStrings.guests} $guests'}',
        style: const TextStyle(
            fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: DesignColors.textStrong, height: 1.35),
      ),
    );
  }

  // ── building blocks ──────────────────────────────────────────────────────

  static const _body = TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, color: DesignColors.textSecondary, height: 1.35);
  static const _small = TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: DesignColors.textMuted, height: 1.35);

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: _small),
          const SizedBox(width: 10),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: DesignColors.textStrong)),
          ),
        ]),
      );

  static Widget _note(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: DesignColors.statusAskedSoft, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: const TextStyle(
                fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, fontWeight: FontWeight.w500, color: DesignColors.statusAttention, height: 1.35)),
      );

  static Widget _button(String label,
      {required bool primary, required Color accent, bool negative = false, VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      child: primary
          ? TripButton(color: accent, label: label, onPressed: onTap)
          : TripActionChip(
              height: 48,
              fontSize: 13,
              color: negative ? DesignColors.statusSaved : DesignColors.textSecondary,
              label: label,
              onTap: onTap,
            ),
    );
  }

  static Widget _card(
    BuildContext context, {
    required bool mine,
    required DateTime? readAt,
    DateTime? createdAt,
    required Color accent,
    required String icon,
    required String title,
    required Widget pill,
    required List<Widget> children,
  }) {
    final maxWidth = math.min(300.0, MediaQuery.sizeOf(context).width - 40);
    final recent = createdAt != null && DateTime.now().difference(createdAt).inSeconds.abs() < 10;
    return RepliesEntrance(
      animate: recent,
      child: Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: RepliesCard.radius,
          boxShadow: DesignShadows.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [accent.withValues(alpha: Alpha.scrim), accent.withValues(alpha: Alpha.hairline)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle),
              child: Padding(padding: const EdgeInsets.all(5), child: TravelIcon(icon, size: 20)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: DesignColors.textStrong)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: pill),
          const SizedBox(height: 10),
          ...children,
          if (mine) ...[
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: _tick(readAt != null, onDark: false)),
          ],
        ]),
      ),
      ),
    );
  }

  static Widget _bubble(MessageModel m, String text, Color accent) {
    final mine = m.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? null : DesignColors.surface,
          gradient: mine ? DesignGradients.brand : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          boxShadow: [ShadowTokens.tint(mine ? DesignColors.primary : DesignColors.shadowBase, mine ? ShadowSpec.chatMine : ShadowSpec.chatTheirs)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(text,
              style: TextStyle(
                  fontFamily: FitnessAppTheme.fontName, fontSize: 13.5, color: mine ? DesignColors.surface : DesignColors.textStrong)),
          if (mine) ...[const SizedBox(height: 2), _tick(m.readAt != null)],
        ]),
      ),
    );
  }

  static Widget _tick(bool read, {bool onDark = true}) => Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(
          read ? Icons.done_all_rounded : Icons.done_rounded,
          size: 14,
          color: read ? DesignColors.primaryLight : (onDark ? DesignColors.surface.withValues(alpha: Alpha.strong) : DesignColors.textMuted),
        ),
      );

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
    return TripChatCards._card(
      context,
      mine: widget.message.isMine,
      readAt: widget.message.readAt,
      createdAt: widget.message.createdAt,
      accent: widget.accent,
      icon: TravelIcon.stay,
      title: title,
      pill: TripStatusPill(display, ownerSide: widget.isOwner),
      children: [
        if (checkIn != null) TripChatCards._kv(TripStrings.checkIn, TripFormat.shortDate(checkIn)),
        if (checkOut != null)
          TripChatCards._kv(
              TripStrings.checkOut,
              nights != null && nights > 0
                  ? '${TripFormat.shortDate(checkOut)} · ${TripStrings.nights(nights)}'
                  : TripFormat.shortDate(checkOut)),
        if (adults != null) TripChatCards._kv(TripStrings.people, TripStrings.peopleCount(adults + kids)),
        if (rooms != null) TripChatCards._kv(TripStrings.rooms, TripStringsF2.roomsCount(rooms)),
        if (text != null && text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(text, maxLines: 6, overflow: TextOverflow.ellipsis, style: TripChatCards._small),
        ],
        if (canAct) ...[
          const SizedBox(height: 12),
          TripChatCards._button(
            display == TripDisplayStatus.offered ? TripStrings.sendNewOffer : TripStrings.sendOffer,
            primary: true,
            accent: widget.accent,
            onTap: _busy ? null : () => _run((x) => StayEnquiryActions.sendOffer(context, x)),
          ),
          const SizedBox(height: 8),
          TripChatCards._button(
            TripStrings.notAvailableAction,
            primary: false,
            accent: widget.accent,
            negative: true,
            onTap: _busy ? null : () => _run((x) => StayEnquiryActions.notAvailable(context, x)),
          ),
        ],
      ],
    );
  }
}
