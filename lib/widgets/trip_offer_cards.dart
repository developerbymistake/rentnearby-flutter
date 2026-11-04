import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/trip_strings_a5.dart';
import '../features/trip/utils/trip_format.dart';
import '../features/trip/widgets/trip_payment_line.dart';
import '../features/trip/widgets/trip_status.dart';
import '../models/browse_item.dart';
import '../models/message_model.dart';
import 'trip_chat_cards.dart';

enum _Btn { primary, positive, plain, negative }

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
    final price = _num(p, 'pricePerNight');
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
    final canAct = isOwner && pending;
    final onAccept = cb.onAcceptPrice;
    final onDifferent = cb.onSendDifferentOffer;

    return _card(
      context,
      m,
      accent: accent,
      icon: Icons.currency_rupee_rounded,
      title: title,
      subtitle: cb.listingTitle.isEmpty ? null : cb.listingTitle,
      pill: _counterPill(status),
      children: [
        if (price != null)
          Text(TripStringsA5.priceRoomNight(BrowseItem.inr(price)),
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        if (total != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(TripStringsA5.roomsNightsTotalLine(units, nights, BrowseItem.inr(total)), style: _body),
          ),
        if (listed != null && listed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(TripStringsA5.listedAmount(BrowseItem.inr(listed)), style: _small),
          ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(note, maxLines: 4, overflow: TextOverflow.ellipsis, style: _body),
        ],
        if (canAct && enquiryId != null && offerId != null) ...[
          const SizedBox(height: 12),
          _pair(
            _button(TripStrings.acceptPrice,
                kind: _Btn.positive,
                accent: accent,
                onTap: onAccept == null ? null : () => onAccept(enquiryId, offerId)),
            _button(TripStrings.sendDifferentOffer,
                kind: _Btn.plain,
                accent: accent,
                onTap: onDifferent == null ? null : () => onDifferent(enquiryId, offerId)),
          ),
          const SizedBox(height: 8),
          const Text(TripStrings.acceptPriceOpens, style: _fine),
        ],
        if (!isOwner) ...[
          const SizedBox(height: 8),
          const TripPaymentLine(text: TripStrings.noPaymentLine),
        ],
      ],
    );
  }

  static Widget? _counterPill(String status) => switch (status) {
        _accepted => const TripStatusPill(TripDisplayStatus.confirmedByBoth, label: TripStrings.priceAccepted),
        _superseded => const TripStatusPill(TripDisplayStatus.closed, label: TripStrings.priceReplaced),
        _expired => const TripStatusPill(TripDisplayStatus.expired, label: TripStrings.expired),
        _ => null,
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
    final canAct = !isOwner && pending;
    final onAccept = cb.onAcceptNewPrice;
    final onKeep = cb.onKeepPrice;
    final onCancel = cb.onCancelStay;

    return _card(
      context,
      m,
      accent: accent,
      icon: Icons.autorenew_rounded,
      title: TripStrings.revisedOffer,
      subtitle: cb.listingTitle.isEmpty ? null : cb.listingTitle,
      pill: _revisedPill(status, oldTotal == null ? lockedMoney : BrowseItem.inr(oldTotal)),
      children: [
        if (total != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              TripStrings.totalArrow(oldTotal == null ? lockedMoney : BrowseItem.inr(oldTotal), BrowseItem.inr(total)),
              maxLines: 1,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(TripStrings.reasonLine(reason), maxLines: 3, overflow: TextOverflow.ellipsis, style: _small),
        ],
        if (differs && range != null) ...[
          const SizedBox(height: 8),
          _warn(TripStrings.datesDiffer(range)),
        ],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final l in lines) _line(l),
        ],
        if (nights != null || range != null)
          Text([if (nights != null) TripStrings.nights(nights), if (range != null) range].join(' · '),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: _small),
        if (advanceAgreed != null && advanceAgreed > 0) ...[
          const SizedBox(height: 6),
          Text(TripStrings.advanceStays(BrowseItem.inr(advanceAgreed)), style: _body),
        ],
        if (cancelText != null && cancelText.isNotEmpty) _kv(TripStrings.cancellationTerms, cancelText),
        if (canAct && enquiryId != null && offerId != null) ...[
          const SizedBox(height: 12),
          _button(TripStrings.acceptNewPrice,
              kind: _Btn.primary, accent: accent, onTap: onAccept == null ? null : () => onAccept(enquiryId, offerId)),
          const SizedBox(height: 8),
          _pair(
            _button(TripStrings.keepPrice(lockedMoney),
                kind: _Btn.plain, accent: accent, onTap: onKeep == null ? null : () => onKeep(enquiryId, offerId)),
            _button(TripStrings.cancelStay,
                kind: _Btn.negative, accent: accent, onTap: onCancel == null ? null : () => onCancel(enquiryId)),
          ),
        ],
        if (pending) ...[
          const SizedBox(height: 8),
          Text(isOwner ? TripStrings.revisedFooter : TripStrings.priceStaysUntil(lockedMoney), style: _fine),
        ],
        const SizedBox(height: 8),
        const TripPaymentLine(),
      ],
    );
  }

  static Widget _revisedPill(String status, String oldMoney) => switch (status) {
        _accepted => const TripStatusPill(TripDisplayStatus.confirmedByBoth, label: TripStrings.newPriceAccepted),
        _kept => TripStatusPill(TripDisplayStatus.closed, label: TripStrings.keptPrice(oldMoney)),
        _expired => const TripStatusPill(TripDisplayStatus.expired, label: TripStrings.expired),
        _superseded => const TripStatusPill(TripDisplayStatus.closed, label: TripStrings.replaced),
        _ => const TripStatusPill(TripDisplayStatus.offered, label: TripStrings.notAcceptedYet),
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
    final canAct = isOwner && pending;
    final onAccept = cb.onAcceptChange;
    final onDifferent = cb.onSendDifferentOffer;
    final name = _firstName(cb.guestName);

    return _card(
      context,
      m,
      accent: accent,
      icon: Icons.edit_calendar_rounded,
      title: isOwner ? TripStrings.changeRequest : TripStrings.changeRequestSent,
      subtitle: isOwner ? name : (cb.listingTitle.isEmpty ? null : cb.listingTitle),
      pill: _changePill(status),
      children: [
        if (newRange != null) _diff(oldRange, newRange),
        if (newPeople != null) _diff(oldPeople, newPeople),
        if (newRooms != null) _diff(oldRooms, newRooms),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(note, maxLines: 4, overflow: TextOverflow.ellipsis, style: _small),
        ],
        if (canAct && enquiryId != null && offerId != null) ...[
          const SizedBox(height: 12),
          _pair(
            _button(TripStrings.acceptChange,
                kind: _Btn.positive, accent: accent, onTap: onAccept == null ? null : () => onAccept(enquiryId, offerId)),
            _button(TripStrings.sendDifferentOffer,
                kind: _Btn.plain,
                accent: accent,
                onTap: onDifferent == null ? null : () => onDifferent(enquiryId, offerId)),
          ),
          if (total != null) ...[
            const SizedBox(height: 8),
            Text(TripStrings.acceptKeepsPrice(BrowseItem.inr(total)), style: _fine),
          ],
        ],
        if (!isOwner && pending) ...[
          const SizedBox(height: 8),
          if (total != null) Text(TripStrings.newTotal(BrowseItem.inr(total)), style: _body),
          const Text(TripStrings.bookingStaysUntilHost, style: _fine),
        ],
      ],
    );
  }

  static Widget _changePill(String status) => switch (status) {
        _accepted => const TripStatusPill(TripDisplayStatus.confirmedByBoth, label: TripStrings.changeAccepted),
        _superseded => const TripStatusPill(TripDisplayStatus.closed, label: TripStrings.hostSentDifferent),
        _expired => const TripStatusPill(TripDisplayStatus.expired, label: TripStrings.expired),
        _ => const TripStatusPill(TripDisplayStatus.offered, label: TripStrings.notAcceptedYet),
      };

  static Widget _diff(String? oldValue, String newValue) {
    final old = oldValue != null && oldValue != newValue ? oldValue : null;
    final changed = old != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (old != null) ...[
            Text(old,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  color: AppColors.textLight,
                  decoration: TextDecoration.lineThrough,
                )),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textHint),
          ],
          Text(newValue,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: changed ? FontWeight.w700 : FontWeight.w500,
                color: changed ? AppColors.textDark : AppColors.textMedium,
              )),
        ],
      ),
    );
  }

  // ── building blocks ──────────────────────────────────────────────────────

  static const _body = TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textMedium, height: 1.35);
  static const _small = TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, height: 1.35);
  static const _fine = TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35);

  static String? _firstName(String? name) {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }

  static Widget _line(Map line) {
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark, height: 1.35),
      ),
    );
  }

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: _small),
          const SizedBox(width: 10),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ),
        ]),
      );

  static Widget _warn(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.warningText, height: 1.35)),
      );

  static Widget _pair(Widget a, Widget b) => LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 340) {
            return Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 8), b]);
        },
      );

  static Widget _button(String label, {required _Btn kind, required Color accent, VoidCallback? onTap}) {
    final disabled = onTap == null;
    final filled = kind == _Btn.primary || kind == _Btn.positive;
    final fill = kind == _Btn.positive ? AppColors.successDark : accent;
    final text = Text(label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600));
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: disabled ? AppColors.divider : fill,
                foregroundColor: disabled ? AppColors.textHint : Colors.white,
                disabledBackgroundColor: AppColors.divider,
                disabledForegroundColor: AppColors.textHint,
                elevation: 0,
                shape: shape,
              ),
              child: text,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: kind == _Btn.negative ? AppColors.error : AppColors.textMedium,
                side: BorderSide(
                    color: kind == _Btn.negative && !disabled ? AppColors.error.withValues(alpha: 0.4) : AppColors.divider),
                shape: shape,
              ),
              child: text,
            ),
    );
  }

  static Widget _card(
    BuildContext context,
    MessageModel m, {
    required Color accent,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? pill,
    required List<Widget> children,
  }) {
    final maxWidth = math.min(300.0, MediaQuery.sizeOf(context).width - 40);
    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                if (subtitle != null) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _small),
              ]),
            ),
          ]),
          if (pill != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: pill),
          ],
          if (children.isNotEmpty) const SizedBox(height: 10),
          ...children,
          if (m.isMine) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                m.readAt != null ? Icons.done_all_rounded : Icons.done_rounded,
                size: 14,
                color: m.readAt != null ? AppColors.readTick : AppColors.textHint,
              ),
            ),
          ],
        ]),
      ),
    );
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
