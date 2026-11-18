class NotificationTypeKeys {
  const NotificationTypeKeys._();

  static const String roleRequestApproved = 'RoleRequestApproved';
  static const String roleRequestApprovedWire = 'role_request_approved';
  static const String roleRequestRejected = 'RoleRequestRejected';
  static const String roleRequestRejectedWire = 'role_request_rejected';
  static const String stayApproved = 'StayApproved';
  static const String stayApprovedWire = 'stay_approved';
  static const String stayRejected = 'StayRejected';
  static const String stayRejectedWire = 'stay_rejected';
  static const String taxiApproved = 'TaxiApproved';
  static const String taxiApprovedWire = 'taxi_approved';
  static const String taxiRejected = 'TaxiRejected';
  static const String taxiRejectedWire = 'taxi_rejected';

  static const String taxiDriverAccepted = 'TaxiDriverAccepted';
  static const String taxiDriverAcceptedWire = 'taxi_driver_accepted';
  static const String taxiSelectionLapsed = 'TaxiSelectionLapsed';
  static const String taxiSelectionLapsedWire = 'taxi_selection_lapsed';
  static const String taxiBooked = 'TaxiBooked';
  static const String taxiBookedWire = 'taxi_booked';
  static const String taxiRequestEnded = 'TaxiRequestEnded';
  static const String taxiRequestEndedWire = 'taxi_request_ended';
  static const String taxiDriverWithdrew = 'TaxiDriverWithdrew';
  static const String taxiDriverWithdrewWire = 'taxi_driver_withdrew';
  static const String taxiRateDriver = 'TaxiRateDriver';
  static const String taxiRateDriverWire = 'taxi_rate_driver';
  static const String taxiTripEnded = 'TaxiTripEnded';
  static const String taxiTripEndedWire = 'taxi_trip_ended';

  // Hub events carry the type constant, FCM pushes the wire value.
  static const Set<String> travellerTaxi = {
    taxiDriverAccepted,
    taxiDriverAcceptedWire,
    taxiSelectionLapsed,
    taxiSelectionLapsedWire,
    taxiBooked,
    taxiBookedWire,
    taxiRequestEnded,
    taxiRequestEndedWire,
    taxiDriverWithdrew,
    taxiDriverWithdrewWire,
    taxiRateDriver,
    taxiRateDriverWire,
    taxiTripEnded,
    taxiTripEndedWire,
  };

  static bool isTravellerTaxi(String? type) => type != null && travellerTaxi.contains(type);
}
