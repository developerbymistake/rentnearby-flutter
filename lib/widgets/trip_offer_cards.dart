import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/trip_strings_a5.dart';
import '../features/trip/trip_strings_f2.dart';
import '../features/trip/trip_strings_h4.dart';
import '../features/trip/utils/trip_format.dart';
import '../models/browse_item.dart';
import '../models/message_model.dart';
import 'trip_chat_cards.dart';

class TripOfferCards {
  static const String counterType = 'trip_counter';
  static const String revisedType = 'trip_revised_offer';
  static const String changeType = 'trip_change_request';

  static bool handles(String type) => type == counterType || type == revisedType || type == changeType;

  static const String _pending = 'pending';
  static const String _accepted = 'accepted';
  static const String _superseded = 'superseded';
  static const String _expired = 'expired';
  static const String _kept = 'kept';

  // ── counter ──────────────────────────────────────────────────────────────

  static Widget counter(
    BuildContext context,
    MessageModel m, {
    required bool isOwner,
    required Color accent,
    required TripChatCallbacks callbacks,
  }) {
    final p = m.payload;
    final cb = callbacks;
    final status = _str(p, 'status') ?? _pending;
    final enquiryId = _str(p, 'enquiryId');
    final offerId = _str(p, 'offerId');
    final price = _num(p, 'proposedPerNight') ?? _num(p, 'pricePerNight');
    final listed = _num(p, 'listedPerNight');
    final nights = _int(p, 'nights') ?? 1;
    final units = _int(p, 'units') ?? 1;
    final total = _num(p, 'total') ?? (price == null ? null : price * units * nights);
    final note = _str(p, 'note')?.trim();
    final name = _firstName(cb.guestName);
    final title = isOwner
        ? (name == null ? TripStringsA5.priceProposedTitle : '$name ${TripStringsA5.proposesPriceOwner}')
        : TripStringsA5.yourPriceTitle;
    final pending = status == _pending;
    final canAct = isOwner && pending && enquiryId != null && offerId != null;
    final onAccept = cb.onAcceptPrice;
    final onDifferent = cb.onSendDifferentOffer;
    final pill = _counterPill(status, stayConfirmed: cb.agreedTotal != null);

    return TripChatCards.wrap(
      m,
      ChatTripCard3D(
        status: pill.$1,
        art: ListingArt.moneyBag,
        pill: pill.$2,
        title: title,
        line: [
          if (price != null) TripStringsA5.priceRoomNight(BrowseItem.inr(price)),
          if (listed != null && listed > 0) TripStringsA5.listedAmount(BrowseItem.inr(listed)),
          if (cb.listingTitle.isNotEmpty) cb.listingTitle,
        ].join(' · '),
        rows: [
          ReplyRow(TripStrings.rooms, TripStringsF2.roomsCount(units)),
          ReplyRow(TripStrings.nights(nights), ''),
          if (total != null) ReplyRow(TripStrings.total, BrowseItem.inr(total)),
        ],
        extra: [if (note != null && note.isNotEmpty) note],
        note: isOwner ? (canAct ? TripStrings.acceptPriceOpens : null) : TripStrings.noPaymentLine,
        noteArt: isOwner ? ListingArt.clipboard : ListingArt.moneyBag,
        primary: ReplyAction(
            label: TripStrings.acceptPrice,
            onTap: canAct && onAccept != null ? () => onAccept(enquiryId, offerId) : null),
        secondary: ReplyAction(
            label: TripStrings.sendDifferentOffer,
            onTap: canAct && onDifferent != null ? () => onDifferent(enquiryId, offerId) : null),
        showActions: isOwner,
        mine: m.isMine,
        read: m.readAt != null,
      ),
    );
  }

  // An accepted counter only means the host sent an offer at that price; green waits for the confirmed stay.
  static (StatusTone3D, String) _counterPill(String status, {required bool stayConfirmed}) => switch (status) {
        _accepted when stayConfirmed => (StatusTone3D.both, TripStrings.priceAccepted),
        _accepted => (StatusTone3D.waiting, TripStringsH4.hostSentAtYourPrice),
        _superseded => (StatusTone3D.closed, TripStrings.priceReplaced),
        _expired => (StatusTone3D.red, TripStrings.expired),
        _ => (StatusTone3D.waiting, TripStringsA5.priceProposedTitle),
      };

  // ── revised offer ────────────────────────────────────────────────────────

  static Widget revised(
    BuildContext context,
    MessageModel m, {
    required bool isOwner,
    required Color accent,
    required TripChatCallbacks callbacks,
  }) {
    final p = m.payload;
    final cb = callbacks;
    final wire = _str(p, 'status') ?? _pending;
    final validUntil = DateTime.tryParse(_str(p, 'validUntil') ?? '');
    final clockExpired = wire == _pending && validUntil != null && !validUntil.isAfter(DateTime.now().toUtc());
    final status = clockExpired ? _expired : wire;
    final pending = status == _pending;
    final enquiryId = _str(p, 'enquiryId');
    final offerId = _str(p, 'offerId');
    final oldTotal = _num(p, 'oldTotal');
    final total = _num(p, 'total');
    final locked = cb.agreedTotal ?? oldTotal;
    final lockedMoney = locked == null ? '' : BrowseItem.inr(locked);
    final reason = _str(p, 'reason')?.trim();
    final lines = _list(p, 'lines').whereType<Map>().toList();
    final nights = _int(p, 'nights');
    final range = _range(p);
    final advanceAgreed = _num(p, 'advanceAgreed');
    final cancelText = _str(p, 'cancellationText');
    final differs = p['datesDiffer'] == true;
    final canAct = !isOwner && pending && enquiryId != null && offerId != null;
    final onAccept = cb.onAcceptNewPrice;
    final onKeep = cb.onKeepPrice;
    final onCancel = cb.onCancelStay;
    final pill = _revisedPill(status, oldTotal == null ? lockedMoney : BrowseItem.inr(oldTotal));
    final when = [if (nights != null) TripStrings.nights(nights), ?range].join(' · ');

    return TripChatCards.wrap(
      m,
      ChatTripCard3D(
        status: pill.$1,
        art: ListingArt.moneyBag,
        pill: pill.$2,
        title: TripStrings.revisedOffer,
        line: [
          if (cb.listingTitle.isNotEmpty) cb.listingTitle,
          if (reason != null && reason.isNotEmpty) TripStrings.reasonLine(reason),
        ].join(' · '),
        rows: [
          if (total != null)
            ReplyRow(TripStrings.totalArrow(oldTotal == null ? lockedMoney : BrowseItem.inr(oldTotal), BrowseItem.inr(total)), ''),
          if (advanceAgreed != null && advanceAgreed > 0) ReplyRow(TripStrings.advanceStays(BrowseItem.inr(advanceAgreed)), ''),
          if (when.isNotEmpty) ReplyRow(TripStrings.dates, when),
          if (cancelText != null && cancelText.isNotEmpty) ReplyRow(TripStrings.cancellationTerms, cancelText),
        ],
        extra: [
          if (differs && range != null) TripStrings.datesDiffer(range),
          for (final l in lines) _line(l),
          TripStrings.stayPayLine,
        ],
        note: pending ? (isOwner ? TripStrings.revisedFooter : TripStrings.priceStaysUntil(lockedMoney)) : null,
        noteAction: isOwner ? null : TripStrings.cancelStay,
        onNoteAction: canAct && onCancel != null ? () => onCancel(enquiryId) : null,
        primary: ReplyAction(
            label: TripStrings.acceptNewPrice, onTap: canAct && onAccept != null ? () => onAccept(enquiryId, offerId) : null),
        secondary: ReplyAction(
            label: TripStrings.keepPrice(lockedMoney), onTap: canAct && onKeep != null ? () => onKeep(enquiryId, offerId) : null),
        showActions: !isOwner,
        mine: m.isMine,
        read: m.readAt != null,
      ),
    );
  }

  static (StatusTone3D, String) _revisedPill(String status, String oldMoney) => switch (status) {
        _accepted => (StatusTone3D.both, TripStrings.newPriceAccepted),
        _kept => (StatusTone3D.closed, TripStrings.keptPrice(oldMoney)),
        _expired => (StatusTone3D.red, TripStrings.expired),
        _superseded => (StatusTone3D.closed, TripStrings.replaced),
        _ => (StatusTone3D.waiting, TripStrings.notAcceptedYet),
      };

  // ── change request ───────────────────────────────────────────────────────

  static Widget changeRequest(
    BuildContext context,
    MessageModel m, {
    required bool isOwner,
    required Color accent,
    required TripChatCallbacks callbacks,
  }) {
    final p = m.payload;
    final cb = callbacks;
    final status = _str(p, 'status') ?? _pending;
    final pending = status == _pending;
    final enquiryId = _str(p, 'enquiryId');
    final offerId = _str(p, 'offerId');
    final total = _num(p, 'total');
    final note = _str(p, 'note')?.trim();
    final oldRange = _dayMonth(p, 'oldCheckIn', 'oldCheckOut');
    final newRange = _dayMonth(p, 'checkIn', 'checkOut');
    final oldPeople = TripEnquiryContext(adults: _int(p, 'oldAdults'), kids: _int(p, 'oldKids')).peopleLabel;
    final newPeople = TripEnquiryContext(adults: _int(p, 'adults'), kids: _int(p, 'kids')).peopleLabel;
    final oldRooms = TripEnquiryContext(rooms: _int(p, 'oldRooms')).roomsLabel;
    final newRooms = TripEnquiryContext(rooms: _int(p, 'rooms')).roomsLabel;
    final canAct = isOwner && pending && enquiryId != null && offerId != null;
    final onAccept = cb.onAcceptChange;
    final onDifferent = cb.onSendDifferentOffer;
    final name = _firstName(cb.guestName);
    final pill = _changePill(status);
    final subtitle = isOwner ? name : (cb.listingTitle.isEmpty ? null : cb.listingTitle);

    final String? footnote;
    if (isOwner) {
      footnote = canAct && total != null ? TripStrings.acceptKeepsPrice(BrowseItem.inr(total)) : null;
    } else {
      footnote = pending ? TripStrings.bookingStaysUntilHost : null;
    }

    return TripChatCards.wrap(
      m,
      ChatTripCard3D(
        status: pill.$1,
        art: ListingArt.calendar,
        pill: pill.$2,
        title: isOwner ? TripStrings.changeRequest : TripStrings.changeRequestSent,
        line: subtitle,
        rows: [
          if (newRange != null) ReplyRow(TripStrings.dates, _diff(oldRange, newRange)),
          if (newPeople != null) ReplyRow(TripStrings.people, _diff(oldPeople, newPeople)),
          if (newRooms != null) ReplyRow(TripStrings.rooms, _diff(oldRooms, newRooms)),
        ],
        extra: [
          if (!isOwner && pending && total != null) TripStrings.newTotal(BrowseItem.inr(total)),
          if (note != null && note.isNotEmpty) note,
        ],
        note: footnote,
        noteArt: ListingArt.calendar,
        primary: ReplyAction(
            label: TripStrings.acceptChange, onTap: canAct && onAccept != null ? () => onAccept(enquiryId, offerId) : null),
        secondary: ReplyAction(
            label: TripStrings.sendDifferentOffer,
            onTap: canAct && onDifferent != null ? () => onDifferent(enquiryId, offerId) : null),
        showActions: isOwner,
        mine: m.isMine,
        read: m.readAt != null,
      ),
    );
  }

  static (StatusTone3D, String) _changePill(String status) => switch (status) {
        _accepted => (StatusTone3D.both, TripStrings.changeAccepted),
        _superseded => (StatusTone3D.closed, TripStrings.hostSentDifferent),
        _expired => (StatusTone3D.red, TripStrings.expired),
        _ => (StatusTone3D.waiting, TripStrings.notAcceptedYet),
      };

  static String _diff(String? oldValue, String newValue) {
    final old = oldValue != null && oldValue != newValue ? oldValue : null;
    return old == null ? newValue : '$old → $newValue';
  }

  // ── building blocks ──────────────────────────────────────────────────────

  static String? _firstName(String? name) {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }

  static String _line(Map line) {
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
    final a = tripDate(p['checkIn']);
    final b = tripDate(p['checkOut']);
    if (a == null || b == null) return null;
    return TripFormat.dateRange(a, b);
  }

  static String? _dayMonth(Map<String, dynamic> p, String from, String to) {
    final a = tripDate(p[from]);
    final b = tripDate(p[to]);
    if (a == null || b == null) return null;
    return TripFormat.dayMonthRange(a, b);
  }
}
