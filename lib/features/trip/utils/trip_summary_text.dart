import '../../../models/browse_item.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_summary_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../widgets/trip_status.dart';
import 'trip_format.dart';

class TripSummaryText {
  static String roomLine(TripSummaryRoom r) {
    final name = r.roomName == null || r.roomName!.isEmpty ? TripStrings.room : r.roomName!;
    final units = r.units > 1 ? ' x${r.units}' : '';
    return r.guests > 0 ? '$name$units · ${TripStrings.peopleCount(r.guests)}' : '$name$units';
  }

  static String advanceLine(TripSummaryNight n) {
    final amount = n.advanceAmount;
    if (amount == null || amount <= 0) return TripStrings.advanceNone;
    final p = BrowseItem.inr(amount);
    return switch (n.advanceStatus) {
      TripAdvanceStatuses.received => TripStrings.advanceReceivedShort(p),
      TripAdvanceStatuses.pending || TripAdvanceStatuses.proofSent => TripStrings.advanceAskedShort(p),
      _ => TripStrings.advanceNone,
    };
  }

  static String statusLabel(TripDisplayStatus s, String? cancelledBy, {bool taxi = false}) {
    if (cancelledBy != null) {
      return cancelledBy == 'traveller' ? TripStrings.youCancelled : TripStrings.hostCancelled;
    }
    return TripStatusVisuals.label(s, taxi: taxi);
  }

  static String fareLine(TripSummaryTaxi t) {
    final fare = t.agreedFare;
    if (fare == null) return '';
    final p = BrowseItem.inr(fare);
    return t.tollExtra ? '$p · ${TripStrings.tollExtraShort}' : p;
  }

  static String taxiDays(TripSummaryTaxi t) {
    final a = t.checkIn;
    final b = t.checkOut;
    if (a == null) return '';
    return TripFormat.dayMonthRange(a, b ?? a);
  }

  static String datesOf(TripSummaryRecord r) {
    final a = r.startDate;
    if (a == null) return '';
    return TripFormat.dayMonthRange(a, r.endDate ?? a);
  }

  static String build(TripSummaryRecord r) {
    var level = 0;
    var out = _compose(r, level);
    while (out.length > TripConstants.summaryShareMax && level < 3) {
      out = _compose(r, ++level);
    }
    if (out.length > TripConstants.summaryShareMax) {
      final footer = _footer(r);
      final room = TripConstants.summaryShareMax - footer.length - 1;
      out = '${out.substring(0, room.clamp(0, out.length))}\n$footer';
    }
    return out;
  }

  static String _footer(TripSummaryRecord r) =>
      [TripStrings.summaryFooter, if (r.taxis.isNotEmpty) TripStrings.taxiPayLine].join('\n');

  static String _compose(TripSummaryRecord r, int level) {
    final lines = <String>[
      TripStrings.summaryHeader('${r.city} trip', datesOf(r), TripStrings.peopleCount(r.people)),
      '',
    ];
    for (final n in r.nights) {
      final d = n.date == null ? '' : TripFormat.shortDate(n.date!);
      final title = [
        TripStrings.nightCard(n.night, d),
        n.listingName,
        n.isOwn ? TripStrings.ownBookingShort : statusLabel(n.display, n.cancelledBy),
      ].where((e) => e.isNotEmpty).join(' · ');
      lines.add(title);
      if (n.isOwn && (n.ownPhone ?? '').isNotEmpty) lines.add('  ${n.ownPhone}');
      if (level < 2) {
        for (final room in n.roomLines) {
          lines.add('  ${TripStrings.room}: ${roomLine(room)}');
        }
      }
      if (n.agreedTotal != null) lines.add('  ${TripStrings.agreed}: ${BrowseItem.inr(n.agreedTotal!)}');
      if (level < 2 && !n.isOwn) lines.add('  ${TripStrings.advance}: ${advanceLine(n)}');
      if (level < 1) {
        final c = n.cancellationText;
        if (c != null && c.isNotEmpty) lines.add('  ${TripStrings.cancellationTerms}: $c');
        if (n.gstInvoice != null) {
          lines.add('  ${TripStrings.gstInvoice}: ${n.gstInvoice! ? TripStrings.yes : TripStrings.no}');
        }
      }
      if (level < 3 && !n.isOwn) lines.add('  ${TripStrings.confirmedLabel}: ${n.confirmedLine()}');
      lines.add('');
    }
    for (final t in r.taxis) {
      final title = [
        TripStrings.taxiCardTitle(taxiDays(t)),
        t.listingName,
        if (t.vehicleTypeName != null && t.vehicleTypeName!.isNotEmpty) t.vehicleTypeName!,
        t.isOwn ? TripStrings.ownBookingShort : statusLabel(t.display, t.cancelledBy, taxi: true),
      ].where((e) => e.isNotEmpty).join(' · ');
      lines.add(title);
      if (t.isOwn && (t.ownPhone ?? '').isNotEmpty) lines.add('  ${t.ownPhone}');
      final fare = fareLine(t);
      if (fare.isNotEmpty) lines.add('  ${TripStrings.fare}: $fare');
      final pickup = [
        if (t.pickupTime != null && t.pickupTime!.isNotEmpty) TripFormat.time12(t.pickupTime!),
        if (level < 1 && t.pickupPlace != null && t.pickupPlace!.isNotEmpty) t.pickupPlace!,
      ].join(', ');
      if (pickup.isNotEmpty) lines.add('  ${TripStrings.pickup}: $pickup');
      if (level < 3 && !t.isOwn) lines.add('  ${TripStrings.confirmedLabel}: ${t.confirmedLine()}');
      lines.add('');
    }
    if (r.agreedTotal > 0) lines.add(TripStrings.agreedInTotal(BrowseItem.inr(r.agreedTotal)));
    lines.add(_footer(r));
    return lines.join('\n');
  }
}
