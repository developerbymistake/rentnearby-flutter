import 'models/taxi_request_models.dart';

class TripStringsTaxiStatus {
  static const String title = 'Request status';
  static const String taxiRequest = 'Taxi request';
  static const String done = 'Done';
  static const String loading = 'Loading your request';
  static const String loadFailed = 'Could not load this request';
  static const String tryAgain = 'Try again';
  static const String neutralTitle = 'Checking your request';
  static const String neutralSub = 'Open the app again in a moment to see the latest.';
  static const String numberNote = 'Your number is shown only to drivers who accept.';

  static const String stepFinding = 'Finding driver';
  static const String stepChoose = 'Choose your driver';
  static const String stepChooseSub = 'Talk to the drivers who accepted';
  static const String stepBooked = 'Booked';
  static const String stepBookedSub = 'The driver confirms your booking';
  static const String waitingSub = 'Drivers are busy with other requests. Please wait.';
  static const String noReplySub = 'No reply yet. Still asking drivers.';

  static const String notAgreed = 'Not agreed';
  static const String call = 'Call';
  static const String select = 'Select';
  static const String onCall = 'On a call';
  static const String selected = 'Selected';
  static const String onHold = 'On hold';
  static const String stillAsking = 'Still asking more drivers';
  static const String askMore = 'Ask more drivers';
  static const String cancelRequest = 'Cancel request';

  static const String booked = 'Booked';
  static const String cancelBooking = 'Cancel booking';
  static const String inProgress = 'Trip in progress';
  static const String endTrip = 'End trip';
  static const String rateTitle = 'Rate your driver';
  static const String submit = 'Submit';
  static const String thankYou = 'Thank you';

  static const String cancelSheetTitle = 'Cancel booking';
  static const String cancelRequestTitle = 'Cancel request';
  static const String cancelRequestSub = 'Drivers will stop getting this request.';
  static const String confirmCancel = 'Confirm cancel';

  static const String busyTitle = 'All drivers are busy right now';
  static const String busySub = 'Please try again in a little while.';
  static const String changePickup = 'Change pickup';
  static const String endedTitle = 'Request closed';
  static const String endedSub = 'You can send a new taxi request any time.';
  static const String requestAgain = 'Request again';
  static const String actionFailed = 'Something went wrong. Please try again.';
  static const String actionOffline = 'No connection. Please try again.';

  static String asked(int n, String pickup) {
    final drivers = n == 1 ? '1 driver' : '$n drivers';
    return pickup.isEmpty ? 'We asked $drivers' : 'We asked $drivers at $pickup';
  }

  static String requestLine(TaxiRequest r) {
    final parts = <String>[
      if (r.sections.pickup && r.pickup != null) 'Pickup at ${r.pickup!.name}',
      if (r.sections.sightseeing) _days(r.sightseeingDays.length),
      if (r.sections.drop) 'Drop',
    ];
    return parts.join(' · ');
  }

  static String _days(int n) => '$n sightseeing ${n == 1 ? 'day' : 'days'}';

  static String waitingFor(String name) => 'Waiting for $name to confirm';

  static String rides(int n) => '$n ${n == 1 ? 'ride' : 'rides'}';

  static String vehicleLine(String vehicle, int seats) =>
      [if (vehicle.isNotEmpty) vehicle, if (seats > 0) '$seats seater'].join(' · ');

  static String dayOf(int day, int total) => 'Day $day of $total';

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _dm(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String dates(DateTime? a, DateTime? b) {
    if (a == null) return '';
    if (b == null || (a.year == b.year && a.month == b.month && a.day == b.day)) return _dm(a);
    return '${_dm(a)} to ${_dm(b)}';
  }

  static String reasonLabel(ReasonChip c) => switch (c) {
        ReasonChip.changedPlan => 'Changed plan',
        ReasonChip.notReachable => 'Not reachable',
        ReasonChip.priceNotAgreed => 'Price not agreed',
        ReasonChip.vehicleIssue => 'Vehicle issue',
        ReasonChip.other => 'Other',
        ReasonChip.unknown => '',
      };

  static const List<ReasonChip> reasons = [
    ReasonChip.changedPlan,
    ReasonChip.notReachable,
    ReasonChip.priceNotAgreed,
    ReasonChip.vehicleIssue,
    ReasonChip.other,
  ];
}
