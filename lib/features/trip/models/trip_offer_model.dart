import 'trip_enquiry_model.dart';

class TripOfferStatuses {
  static const String pending = 'Pending';
  static const String accepted = 'Accepted';
  static const String declined = 'Declined';
  static const String expired = 'Expired';
  static const String superseded = 'Superseded';
}

class TripOfferKinds {
  static const String offer = 'Offer';
  static const String counter = 'Counter';
  static const String revised = 'Revised';
  static const String changeRequest = 'ChangeRequest';
}

class TripOfferLine {
  final String? roomName;
  final int units;
  final int guests;
  final int pricePerNight;

  const TripOfferLine({this.roomName, required this.units, required this.guests, required this.pricePerNight});

  factory TripOfferLine.fromJson(Map<String, dynamic> json) => TripOfferLine(
        roomName: json['roomName'] as String?,
        units: (json['units'] as num?)?.toInt() ?? 1,
        guests: (json['guests'] as num?)?.toInt() ?? 0,
        pricePerNight: (json['pricePerNight'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'roomName': ?roomName,
        'units': units,
        'guests': guests,
        'pricePerNight': pricePerNight,
      };

  int get perNight => units * pricePerNight;
}

class TripOfferModel {
  final String id;
  final String kind;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int nights;
  final List<TripOfferLine> lines;
  final int total;
  final String? inclusions;
  final List<String> needsEchoed;
  final int? advanceAmount;
  final String? balanceNote;
  final String? cancellationText;
  final bool? gstInvoice;
  final String? note;
  final DateTime? validUntil;
  final String status;
  final DateTime? respondedAt;
  final String? messageId;
  final DateTime? createdAt;
  final bool datesDiffer;
  final int? adults;
  final int? kids;
  final int? oldTotal;
  final String? reason;
  final int? listedPerNight;

  const TripOfferModel({
    required this.id,
    this.kind = TripOfferKinds.offer,
    this.checkIn,
    this.checkOut,
    this.nights = 0,
    this.lines = const [],
    this.total = 0,
    this.inclusions,
    this.needsEchoed = const [],
    this.advanceAmount,
    this.balanceNote,
    this.cancellationText,
    this.gstInvoice,
    this.note,
    this.validUntil,
    this.status = TripOfferStatuses.pending,
    this.respondedAt,
    this.messageId,
    this.createdAt,
    this.datesDiffer = false,
    this.adults,
    this.kids,
    this.oldTotal,
    this.reason,
    this.listedPerNight,
  });

  bool get isCounter => kind == TripOfferKinds.counter;

  bool get isRevised => kind == TripOfferKinds.revised;

  bool get isChangeRequest => kind == TripOfferKinds.changeRequest;

  int get rooms => lines.fold(0, (s, l) => s + l.units);

  int get guests => lines.fold(0, (s, l) => s + l.guests);

  int? get pricePerNight => lines.isEmpty ? null : lines.first.pricePerNight;

  bool get isPending => status == TripOfferStatuses.pending;

  bool get isAccepted => status == TripOfferStatuses.accepted;

  bool isLive(DateTime now) {
    if (!isPending) return false;
    final v = validUntil;
    return v == null || v.isAfter(now);
  }

  factory TripOfferModel.fromJson(Map<String, dynamic> json) => TripOfferModel(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? TripOfferKinds.offer,
        checkIn: tripDate(json['checkIn']),
        checkOut: tripDate(json['checkOut']),
        nights: (json['nights'] as num?)?.toInt() ?? 0,
        lines: ((json['lines'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TripOfferLine.fromJson)
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        inclusions: json['inclusions'] as String?,
        needsEchoed: ((json['needsEchoed'] as List?) ?? const []).whereType<String>().toList(),
        advanceAmount: (json['advanceAmount'] as num?)?.toInt(),
        balanceNote: json['balanceNote'] as String?,
        cancellationText: json['cancellationText'] as String?,
        gstInvoice: json['gstInvoice'] as bool?,
        note: json['note'] as String?,
        validUntil: tripInstant(json['validUntil']),
        status: json['status'] as String? ?? TripOfferStatuses.pending,
        respondedAt: tripInstant(json['respondedAt']),
        messageId: json['messageId'] as String?,
        createdAt: tripInstant(json['createdAt']),
        datesDiffer: json['datesDiffer'] == true,
        adults: (json['adults'] as num?)?.toInt(),
        kids: (json['kids'] as num?)?.toInt(),
        oldTotal: (json['oldTotal'] as num?)?.toInt(),
        reason: json['reason'] as String? ?? (json['kind'] == TripOfferKinds.revised ? json['note'] as String? : null),
        listedPerNight: (json['listedPerNight'] as num?)?.toInt(),
      );
}
