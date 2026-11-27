import '../../../trip/models/trip_enquiry_model.dart';
import '../../enquiries_tab/stay_work_format.dart';
import '../../strings/stay_quote_strings.dart';
import 'quote_draft.dart';
import 'quote_text_clean.dart';

class QuotePrefillLine {
  const QuotePrefillLine({required this.description, required this.rate, required this.qty, required this.nights});

  final String description;
  final int rate;
  final int qty;
  final int nights;
}

// Only what the owner enquiry card shows; it never leaves the phone.
class QuotePrefill {
  const QuotePrefill({
    required this.enquiryId,
    this.guestName = '',
    this.guestPhone = '',
    this.checkIn,
    this.checkOut,
    this.adults,
    this.kids,
    this.rooms,
    this.lines = const [],
  });

  final String enquiryId;
  final String guestName;
  final String guestPhone;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? adults;
  final int? kids;
  final int? rooms;
  final List<QuotePrefillLine> lines;

  factory QuotePrefill.fromEnquiry(TripEnquiryModel e) {
    final c = e.context;
    final offer = e.acceptedOffer ?? e.openOffer;
    final nights = e.nights > 0 ? e.nights : 1;
    return QuotePrefill(
      enquiryId: e.id,
      guestName: QuoteTextClean.line(e.traveller.name ?? c.travellerName, QuoteLimits.guestName),
      guestPhone: QuoteTextClean.line(e.traveller.phone, QuoteLimits.guestPhone),
      checkIn: e.checkIn,
      checkOut: e.checkOut,
      adults: c.adults,
      kids: c.kids,
      rooms: StayWorkFormat.rooms(e),
      lines: [
        if (offer != null)
          for (final l in offer.lines)
            if (l.pricePerNight > 0)
              QuotePrefillLine(
                description: QuoteTextClean.line((l.roomName ?? '').trim().isEmpty ? StayQuoteStrings.quickRoomText : l.roomName, QuoteLimits.description),
                rate: l.pricePerNight,
                qty: l.units < 1 ? 1 : l.units,
                nights: nights.clamp(1, QuoteLimits.maxNights),
              ),
      ],
    );
  }

  Map<String, dynamic> toArgs() => {
        'enquiryId': enquiryId,
        'guestName': guestName,
        'guestPhone': guestPhone,
        'checkIn': checkIn?.toIso8601String(),
        'checkOut': checkOut?.toIso8601String(),
        'adults': adults,
        'kids': kids,
        'rooms': rooms,
        'lines': [for (final l in lines) {'description': l.description, 'rate': l.rate, 'qty': l.qty, 'nights': l.nights}],
      };

  static QuotePrefill? fromArgs(Object? raw) {
    if (raw is! Map) return null;
    final m = raw['prefill'] is Map ? raw['prefill'] as Map : raw;
    final id = m['enquiryId'];
    if (id is! String || id.isEmpty) return null;
    DateTime? d(Object? v) => v is String ? DateTime.tryParse(v) : null;
    int? i(Object? v) => v is num ? v.toInt() : null;
    final lines = <QuotePrefillLine>[];
    final rawLines = m['lines'];
    if (rawLines is List) {
      for (final l in rawLines) {
        if (l is! Map) continue;
        lines.add(QuotePrefillLine(
          description: '${l['description'] ?? ''}',
          rate: i(l['rate']) ?? 0,
          qty: i(l['qty']) ?? 1,
          nights: i(l['nights']) ?? 1,
        ));
      }
    }
    return QuotePrefill(
      enquiryId: id,
      guestName: '${m['guestName'] ?? ''}',
      guestPhone: '${m['guestPhone'] ?? ''}',
      checkIn: d(m['checkIn']),
      checkOut: d(m['checkOut']),
      adults: i(m['adults']),
      kids: i(m['kids']),
      rooms: i(m['rooms']),
      lines: lines,
    );
  }

  QuoteDraft applyTo(QuoteDraft draft, String Function() newId) {
    final a = checkIn;
    final b = checkOut;
    final datesOk = a != null && b != null && b.isAfter(a);
    final room = QuoteLimits.maxLines - draft.lines.length;
    return draft.copyWith(
      guestName: guestName.isEmpty ? null : guestName,
      guestPhone: guestPhone.isEmpty ? null : guestPhone,
      checkIn: datesOk ? DateTime(a.year, a.month, a.day) : null,
      checkOut: datesOk ? DateTime(b.year, b.month, b.day) : null,
      adults: adults != null && adults! > 0 ? adults!.clamp(1, QuoteLimits.maxPeople) : null,
      kids: kids != null && kids! >= 0 ? kids!.clamp(0, QuoteLimits.maxPeople) : null,
      rooms: rooms != null && rooms! >= 0 ? rooms!.clamp(0, QuoteLimits.maxPeople) : null,
      lines: [
        ...draft.lines,
        for (final l in lines.take(room < 0 ? 0 : room))
          QuoteLine(
            id: newId(),
            description: l.description,
            rate: l.rate.clamp(0, 9999999),
            qty: l.qty.clamp(1, QuoteLimits.maxQty),
            nights: l.nights.clamp(1, QuoteLimits.maxNights),
          ),
      ],
      enquiryId: enquiryId,
    );
  }
}
