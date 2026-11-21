import '../../owner_core/json/owner_json.dart';
import '../../trip/models/trip_enquiry_model.dart';

enum StayClosedKind {
  expired,
  offerDeclined,
  offerExpired,
  travellerLeft,
  bookedElsewhere,
  bookedByPhone,
  cancelledByGuest,
  cancelledByOwner,
  closedByAdmin,
  notAvailable,
  unknown,
}

class StayListedPart {
  const StayListedPart({this.roomName, this.units = 1, this.nights = 0, this.perNight = 0, this.specialLabel});

  final String? roomName;
  final int units;
  final int nights;
  final int perNight;
  final String? specialLabel;

  factory StayListedPart.fromJson(Map<String, dynamic> j) => StayListedPart(
        roomName: OwnerJson.strOrNull(j['roomName']),
        units: OwnerJson.integer(j['units'], 1),
        nights: OwnerJson.integer(j['nights']),
        perNight: OwnerJson.integer(j['perNight']),
        specialLabel: OwnerJson.strOrNull(j['specialLabel']),
      );
}

class StayEnquiryOwnerView {
  const StayEnquiryOwnerView({
    this.listedStayTotal,
    this.listedBreakdown = const [],
    this.calendarEntryId,
    this.closedKindWire,
    this.problemReported = false,
    this.confirmedAt,
    this.cancelledAt,
  });

  static const empty = StayEnquiryOwnerView();

  final int? listedStayTotal;
  final List<StayListedPart> listedBreakdown;
  final String? calendarEntryId;
  final String? closedKindWire;
  final bool problemReported;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;

  static const Map<String, StayClosedKind> _kinds = {
    'Expired': StayClosedKind.expired,
    'OfferDeclined': StayClosedKind.offerDeclined,
    'OfferExpired': StayClosedKind.offerExpired,
    'TravellerLeft': StayClosedKind.travellerLeft,
    'BookedElsewhere': StayClosedKind.bookedElsewhere,
    'BookedByPhone': StayClosedKind.bookedByPhone,
    'CancelledByGuest': StayClosedKind.cancelledByGuest,
    'CancelledByOwner': StayClosedKind.cancelledByOwner,
    'ClosedByAdmin': StayClosedKind.closedByAdmin,
    'NotAvailable': StayClosedKind.notAvailable,
  };

  factory StayEnquiryOwnerView.fromJson(Map<String, dynamic> j) {
    final total = OwnerJson.intOrNull(j['listedStayTotal']);
    return StayEnquiryOwnerView(
      listedStayTotal: total != null && total > 0 ? total : null,
      listedBreakdown: OwnerJson.list(j['listedBreakdown'], StayListedPart.fromJson).where((p) => p.nights > 0 && p.perNight > 0).toList(),
      calendarEntryId: OwnerJson.strOrNull(j['calendarEntryId']),
      closedKindWire: OwnerJson.strOrNull(j['closedKind']),
      problemReported: OwnerJson.boolean(j['problemReported']),
      confirmedAt: OwnerJson.time(j['confirmedAt']),
      cancelledAt: OwnerJson.time(j['cancelledAt']),
    );
  }

  StayClosedKind closedKind(TripEnquiryModel e) {
    final wire = closedKindWire;
    if (wire != null) return OwnerJson.pick(wire, _kinds, StayClosedKind.unknown);
    return switch (e.status) {
      TripEnquiryStatuses.expired => e.offerCount > 0 ? StayClosedKind.offerExpired : StayClosedKind.expired,
      TripEnquiryStatuses.declined => StayClosedKind.offerDeclined,
      TripEnquiryStatuses.notAvailable => StayClosedKind.notAvailable,
      TripEnquiryStatuses.cancelledByTraveller => StayClosedKind.cancelledByGuest,
      TripEnquiryStatuses.cancelledByOwner => StayClosedKind.cancelledByOwner,
      TripEnquiryStatuses.bookedByTraveller => StayClosedKind.bookedByPhone,
      TripEnquiryStatuses.closed when e.cancelledBy == 'Admin' => StayClosedKind.closedByAdmin,
      _ => StayClosedKind.unknown,
    };
  }
}
