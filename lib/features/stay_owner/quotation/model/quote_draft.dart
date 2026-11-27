import '../data/quote_models.dart';

enum QuoteMeal { none, ep, cp, map, ap }

enum QuotePayKind { advance, bank, cash, upi }

abstract final class QuoteLimits {
  static const int maxLines = 30;
  static const int maxPayments = 6;
  static const int description = 80;
  static const int guestName = 60;
  static const int guestPhone = 20;
  static const int bookedBy = 60;
  static const int note = 400;
  static const int terms = 1200;
  static const int cancellation = 800;
  static const int payLabel = 40;
  static const int maxQty = 999;
  static const int maxNights = 99;
  static const int maxPeople = 99;
  static const int validDays = 7;
  static const int keepDocs = 50;
  static const int keepDays = 90;
}

abstract final class QuoteKinds {
  static String display(QuoteKind k, int number) => k.display(number);
  static QuoteKind parse(Object? v) => v == QuoteKind.proforma.name ? QuoteKind.proforma : QuoteKind.quotation;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
String _str(Object? v) => v is String ? v : '';
String? _day(DateTime? d) => d?.toIso8601String();

class QuoteLine {
  const QuoteLine({required this.id, required this.description, required this.rate, required this.qty, required this.nights});

  final String id;
  final String description;
  final int rate;
  final int qty;
  final int nights;

  int get amount => rate * qty * nights;

  QuoteLine copyWith({String? description, int? rate, int? qty, int? nights}) =>
      QuoteLine(id: id, description: description ?? this.description, rate: rate ?? this.rate, qty: qty ?? this.qty, nights: nights ?? this.nights);

  Map<String, dynamic> toJson() => {'id': id, 'description': description, 'rate': rate, 'qty': qty, 'nights': nights};

  factory QuoteLine.fromJson(Map<String, dynamic> j) =>
      QuoteLine(id: _str(j['id']), description: _str(j['description']), rate: _int(j['rate']), qty: _int(j['qty'], 1), nights: _int(j['nights'], 1));
}

class QuotePayment {
  const QuotePayment({required this.id, required this.kind, required this.label, required this.date, required this.amount});

  final String id;
  final QuotePayKind kind;
  final String label;
  final DateTime date;
  final int amount;

  QuotePayment copyWith({String? label, DateTime? date, int? amount}) =>
      QuotePayment(id: id, kind: kind, label: label ?? this.label, date: date ?? this.date, amount: amount ?? this.amount);

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind.name, 'label': label, 'date': _day(date), 'amount': amount};

  factory QuotePayment.fromJson(Map<String, dynamic> j) => QuotePayment(
        id: _str(j['id']),
        kind: QuotePayKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => QuotePayKind.cash),
        label: _str(j['label']),
        date: _date(j['date']) ?? DateTime(2000),
        amount: _int(j['amount']),
      );
}

class QuoteReservation {
  const QuoteReservation({
    required this.number,
    required this.display,
    required this.issuedAt,
    required this.freeUntil,
    required this.freeLeft,
    required this.businessName,
    this.fileUri,
    this.fileName,
    this.pages,
    this.savedAt,
  });

  final int number;
  final String display;
  final DateTime issuedAt;
  final DateTime freeUntil;
  final int freeLeft;
  final String businessName;
  final String? fileUri;
  final String? fileName;
  final int? pages;
  final DateTime? savedAt;

  bool freeAt(DateTime now) => freeUntil.isAfter(now) && freeLeft > 0;

  QuoteReservation withFile({required String uri, required String name, required int pages, required DateTime at}) => QuoteReservation(
        number: number,
        display: display,
        issuedAt: issuedAt,
        freeUntil: freeUntil,
        freeLeft: freeLeft,
        businessName: businessName,
        fileUri: uri,
        fileName: name,
        pages: pages,
        savedAt: at,
      );

  QuoteReservation withoutFile() =>
      QuoteReservation(number: number, display: display, issuedAt: issuedAt, freeUntil: freeUntil, freeLeft: freeLeft, businessName: businessName);

  Map<String, dynamic> toJson() => {
        'number': number,
        'display': display,
        'issuedAt': _day(issuedAt),
        'freeUntil': _day(freeUntil),
        'freeLeft': freeLeft,
        'businessName': businessName,
        'fileUri': fileUri,
        'fileName': fileName,
        'pages': pages,
        'savedAt': _day(savedAt),
      };

  factory QuoteReservation.fromJson(Map<String, dynamic> j) => QuoteReservation(
        number: _int(j['number']),
        display: _str(j['display']),
        issuedAt: _date(j['issuedAt']) ?? DateTime(2000),
        freeUntil: _date(j['freeUntil']) ?? DateTime(2000),
        freeLeft: _int(j['freeLeft']),
        businessName: _str(j['businessName']),
        fileUri: j['fileUri'] as String?,
        fileName: j['fileName'] as String?,
        pages: (j['pages'] as num?)?.toInt(),
        savedAt: _date(j['savedAt']),
      );
}

class QuoteDraft {
  const QuoteDraft({
    required this.documentId,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    required this.date,
    required this.validTill,
    this.guestName = '',
    this.guestPhone = '',
    this.bookedBy = '',
    this.checkIn,
    this.checkOut,
    this.adults = 1,
    this.kids = 0,
    this.rooms = 0,
    this.meal = QuoteMeal.none,
    this.lines = const [],
    this.discount = 0,
    this.gstBp = 0,
    this.payments = const [],
    this.note = '',
    this.useSavedTerms = true,
    this.termsText = '',
    this.useSavedCancellation = true,
    this.cancellationText = '',
    this.template = 'classic',
    this.reservations = const {},
    this.enquiryId,
  });

  final String documentId;
  final QuoteKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime date;
  final DateTime validTill;
  final String guestName;
  final String guestPhone;
  final String bookedBy;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int adults;
  final int kids;
  final int rooms;
  final QuoteMeal meal;
  final List<QuoteLine> lines;
  final int discount;
  final int gstBp;
  final List<QuotePayment> payments;
  final String note;
  final bool useSavedTerms;
  final String termsText;
  final bool useSavedCancellation;
  final String cancellationText;
  final String template;
  final Map<String, QuoteReservation> reservations;
  final String? enquiryId;

  factory QuoteDraft.blank({required String documentId, required DateTime today, String template = 'classic'}) {
    final d = DateTime(today.year, today.month, today.day);
    return QuoteDraft(
      documentId: documentId,
      kind: QuoteKind.quotation,
      createdAt: today,
      updatedAt: today,
      date: d,
      validTill: d.add(const Duration(days: QuoteLimits.validDays)),
      template: template,
    );
  }

  int get nights {
    final a = checkIn;
    final b = checkOut;
    if (a == null || b == null) return 0;
    final n = DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
    return n < 0 ? 0 : n;
  }

  QuoteReservation? reservationFor(QuoteKind k) => reservations[k.name];

  QuoteReservation? get reservation => reservationFor(kind);

  bool get downloaded => reservations.values.any((r) => r.fileUri != null);

  QuoteReservation? get lastFile {
    QuoteReservation? best;
    for (final r in reservations.values) {
      if (r.fileUri == null) continue;
      if (best == null || (r.savedAt ?? r.issuedAt).isAfter(best.savedAt ?? best.issuedAt)) best = r;
    }
    return best;
  }

  QuoteDraft copyWith({
    QuoteKind? kind,
    DateTime? updatedAt,
    DateTime? date,
    DateTime? validTill,
    String? guestName,
    String? guestPhone,
    String? bookedBy,
    DateTime? checkIn,
    DateTime? checkOut,
    bool clearDates = false,
    int? adults,
    int? kids,
    int? rooms,
    QuoteMeal? meal,
    List<QuoteLine>? lines,
    int? discount,
    int? gstBp,
    List<QuotePayment>? payments,
    String? note,
    bool? useSavedTerms,
    String? termsText,
    bool? useSavedCancellation,
    String? cancellationText,
    String? template,
    Map<String, QuoteReservation>? reservations,
    String? enquiryId,
  }) =>
      QuoteDraft(
        documentId: documentId,
        kind: kind ?? this.kind,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        date: date ?? this.date,
        validTill: validTill ?? this.validTill,
        guestName: guestName ?? this.guestName,
        guestPhone: guestPhone ?? this.guestPhone,
        bookedBy: bookedBy ?? this.bookedBy,
        checkIn: clearDates ? null : (checkIn ?? this.checkIn),
        checkOut: clearDates ? null : (checkOut ?? this.checkOut),
        adults: adults ?? this.adults,
        kids: kids ?? this.kids,
        rooms: rooms ?? this.rooms,
        meal: meal ?? this.meal,
        lines: lines ?? this.lines,
        discount: discount ?? this.discount,
        gstBp: gstBp ?? this.gstBp,
        payments: payments ?? this.payments,
        note: note ?? this.note,
        useSavedTerms: useSavedTerms ?? this.useSavedTerms,
        termsText: termsText ?? this.termsText,
        useSavedCancellation: useSavedCancellation ?? this.useSavedCancellation,
        cancellationText: cancellationText ?? this.cancellationText,
        template: template ?? this.template,
        reservations: reservations ?? this.reservations,
        enquiryId: enquiryId ?? this.enquiryId,
      );

  QuoteDraft withReservation(QuoteKind k, QuoteReservation r) => copyWith(reservations: {...reservations, k.name: r});

  Map<String, dynamic> toJson() => {
        'v': 1,
        'documentId': documentId,
        'kind': kind.name,
        'createdAt': _day(createdAt),
        'updatedAt': _day(updatedAt),
        'date': _day(date),
        'validTill': _day(validTill),
        'guestName': guestName,
        'guestPhone': guestPhone,
        'bookedBy': bookedBy,
        'checkIn': _day(checkIn),
        'checkOut': _day(checkOut),
        'adults': adults,
        'kids': kids,
        'rooms': rooms,
        'meal': meal.name,
        'lines': [for (final l in lines) l.toJson()],
        'discount': discount,
        'gstBp': gstBp,
        'payments': [for (final p in payments) p.toJson()],
        'note': note,
        'useSavedTerms': useSavedTerms,
        'termsText': termsText,
        'useSavedCancellation': useSavedCancellation,
        'cancellationText': cancellationText,
        'template': template,
        'reservations': {for (final e in reservations.entries) e.key: e.value.toJson()},
        'enquiryId': enquiryId,
      };

  static List<Map<String, dynamic>> _maps(Object? v) => v is List ? [for (final e in v) if (e is Map<String, dynamic>) e] : const [];

  factory QuoteDraft.fromJson(Map<String, dynamic> j) {
    final created = _date(j['createdAt']) ?? DateTime(2000);
    final res = <String, QuoteReservation>{};
    final raw = j['reservations'];
    if (raw is Map<String, dynamic>) {
      for (final e in raw.entries) {
        if (e.value is Map<String, dynamic>) res[e.key] = QuoteReservation.fromJson(e.value as Map<String, dynamic>);
      }
    }
    return QuoteDraft(
      documentId: _str(j['documentId']),
      kind: QuoteKinds.parse(j['kind']),
      createdAt: created,
      updatedAt: _date(j['updatedAt']) ?? created,
      date: _date(j['date']) ?? created,
      validTill: _date(j['validTill']) ?? created,
      guestName: _str(j['guestName']),
      guestPhone: _str(j['guestPhone']),
      bookedBy: _str(j['bookedBy']),
      checkIn: _date(j['checkIn']),
      checkOut: _date(j['checkOut']),
      adults: _int(j['adults'], 1),
      kids: _int(j['kids']),
      rooms: _int(j['rooms']),
      meal: QuoteMeal.values.firstWhere((m) => m.name == j['meal'], orElse: () => QuoteMeal.none),
      lines: [for (final m in _maps(j['lines'])) QuoteLine.fromJson(m)],
      discount: _int(j['discount']),
      gstBp: _int(j['gstBp']),
      payments: [for (final m in _maps(j['payments'])) QuotePayment.fromJson(m)],
      note: _str(j['note']),
      useSavedTerms: j['useSavedTerms'] != false,
      termsText: _str(j['termsText']),
      useSavedCancellation: j['useSavedCancellation'] != false,
      cancellationText: _str(j['cancellationText']),
      template: _str(j['template']).isEmpty ? 'classic' : _str(j['template']),
      reservations: res,
      enquiryId: j['enquiryId'] as String?,
    );
  }
}
