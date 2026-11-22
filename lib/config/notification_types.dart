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
  static const String profilePhotoRemoved = 'ProfilePhotoRemoved';
  static const String profilePhotoRemovedWire = 'profile_photo_removed';

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

  static const String taxiRequestRingWire = 'taxi_request_ring';
  static const String taxiRequestRingEndedWire = 'taxi_request_ring_ended';
  static const String taxiSelected = 'TaxiSelected';
  static const String taxiSelectedWire = 'taxi_selected';
  static const String taxiNotSelected = 'TaxiNotSelected';
  static const String taxiNotSelectedWire = 'taxi_not_selected';
  static const String taxiRequestClosed = 'TaxiRequestClosed';
  static const String taxiRequestClosedWire = 'taxi_request_closed';
  static const String taxiBookingCancelled = 'TaxiBookingCancelled';
  static const String taxiBookingCancelledWire = 'taxi_booking_cancelled';
  static const String taxiRingsMissed = 'TaxiRingsMissed';
  static const String taxiRingsMissedWire = 'taxi_rings_missed';

  static const Set<String> driverTaxi = {
    taxiRequestRingWire,
    taxiRequestRingEndedWire,
    taxiSelected,
    taxiSelectedWire,
    taxiNotSelected,
    taxiNotSelectedWire,
    taxiRequestClosed,
    taxiRequestClosedWire,
    taxiBookingCancelled,
    taxiBookingCancelledWire,
    taxiRingsMissed,
    taxiRingsMissedWire,
    taxiTripEnded,
    taxiTripEndedWire,
  };

  static bool isDriverTaxi(String? type) => type != null && driverTaxi.contains(type);

  static bool isRingsMissed(String? type) => type == taxiRingsMissed || type == taxiRingsMissedWire;

  static const String stayEditApprovedWire = 'stay_edit_approved';
  static const String stayEditRejectedWire = 'stay_edit_rejected';
  static const String festivalReminderWire = 'festival_reminder';
  static const String planLimitsChangedWire = 'plan_limits_changed';
  static const String ownerMorningReminderWire = 'owner_morning_reminder';
  static const String plansStartingWire = 'plans_starting';

  static const Set<String> ownerShared = {
    festivalReminderWire,
    planLimitsChangedWire,
    ownerMorningReminderWire,
    plansStartingWire,
  };

  static const Set<String> ownerStay = {
    ...ownerShared,
    stayEditApprovedWire,
    stayEditRejectedWire,
    stayApprovedWire,
    stayRejectedWire,
  };

  static const Set<String> ownerTaxi = {
    ...ownerShared,
    taxiApprovedWire,
    taxiRejectedWire,
    ...driverTaxi,
  };

  static const Set<String> opensOwnerHome = {
    stayApprovedWire,
    stayRejectedWire,
    taxiApprovedWire,
    taxiRejectedWire,
    stayApproved,
    stayRejected,
    taxiApproved,
    taxiRejected,
  };

  static const Set<String> invalidatesPlan = {planLimitsChangedWire, plansStartingWire};

  // Hub events carry the PascalCase constant, FCM the snake wire value; owner seams speak wire.
  static String? toWire(String? type) {
    if (type == null || type.isEmpty || type.contains('_')) return type;
    final b = StringBuffer();
    for (var i = 0; i < type.length; i++) {
      final ch = type[i];
      final lower = ch.toLowerCase();
      if (ch != lower && i > 0) b.write('_');
      b.write(lower);
    }
    return b.toString();
  }

  static bool isOwnerWork(String? type) => type != null && (ownerStay.contains(type) || ownerTaxi.contains(type));
}
