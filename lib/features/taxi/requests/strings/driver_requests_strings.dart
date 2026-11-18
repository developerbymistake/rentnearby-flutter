import '../../../trip/trip_strings_taxi_driver.dart';
import '../models/driver_request_models.dart';

class DriverRequestsStrings {
  static const String title = 'Taxi requests';
  static const String subtitle = 'Today';

  static const String groupNew = 'New';
  static const String groupBooked = 'Booked';
  static const String groupEarlier = 'Earlier';

  static const String showMore = 'Show more';
  static const String loadingMore = 'Loading';
  static const String loading = 'Loading requests';

  static const String emptyTitle = 'No requests yet';
  static const String emptyLine = 'New taxi requests will show up here.';

  static const String errorTitle = 'Could not load requests';
  static const String errorLine = 'Check your connection and try again.';
  static const String tryAgain = 'Try again';

  static const String pausedTitle = 'Requests are paused right now';
  static const String pausedLine = 'New requests will come back soon. Pull down to check again.';
  static const String pausedBanner = 'Requests are paused right now';
  static const String refreshFailed = 'Could not refresh. Showing your last list.';

  static const String actionFailed = 'That did not work. Please try again.';
  static const String actionOffline = 'No connection. Please try again.';
  static const String actionMissed = 'This request went to the next drivers.';
  static const String actionDatesBooked = 'You already have a booking on these dates.';
  static const String actionPaused = 'Requests are paused right now.';

  static const String waitingForTraveller = 'Waiting for the traveller';
  static const String confirmNow = 'Traveller chose you';
  static const String stateAccepted = 'Accepted';
  static const String youDeclined = 'You declined';
  static const String youWithdrew = 'You withdrew';
  static const String notAgreed = 'Price not agreed';
  static const String requestClosed = 'Request closed';
  static const String rideEnded = 'This ride has ended';

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String timeLeft(String time) => '$time left';

  static String travellerName(DriverOffer o) {
    final name = o.traveller?.name.trim() ?? '';
    return name.isEmpty ? TripStringsTaxiDriver.traveller : name;
  }

  static String dateRange(DateTime? from, DateTime? to) {
    if (from == null) return '';
    final end = to ?? from;
    if (end.year == from.year && end.month == from.month) {
      return from.day == end.day ? '${from.day} ${_months[from.month - 1]}' : '${from.day} to ${end.day} ${_months[end.month - 1]}';
    }
    return '${from.day} ${_months[from.month - 1]} to ${end.day} ${_months[end.month - 1]}';
  }

  static String lengthLine(DriverOffer o) {
    final days = '${o.dayCount} ${o.dayCount == 1 ? 'day' : 'days'}';
    final nights = '${o.nightCount} ${o.nightCount == 1 ? 'night' : 'nights'}';
    final range = dateRange(o.fromDay, o.toDay);
    return range.isEmpty ? '$days · $nights' : '$days · $nights · $range';
  }

  static bool isEndedBooking(DriverOffer o) => o.state == OfferState.confirmed && o.bucket == OfferBucket.earlier;

  static String subtitleFor(DriverOffer o) => switch (o.state) {
        OfferState.ringing => TripStringsTaxiDriver.pickupCity(o.pickupName),
        OfferState.accepted => waitingForTraveller,
        OfferState.selected => confirmNow,
        OfferState.confirmed => isEndedBooking(o) ? rideEnded : dateRange(o.fromDay, o.toDay),
        OfferState.missed => TripStringsTaxiDriver.missedNote,
        OfferState.notSelected => TripStringsTaxiDriver.notSelectedNote,
        OfferState.declined => youDeclined,
        OfferState.withdrawn => youWithdrew,
        OfferState.notAgreed => notAgreed,
        _ => requestClosed,
      };

  static String? chipFor(DriverOffer o) => switch (o.state) {
        OfferState.accepted => stateAccepted,
        OfferState.confirmed => isEndedBooking(o) ? TripStringsTaxiDriver.stateClosed : TripStringsTaxiDriver.stateBooked,
        OfferState.missed => TripStringsTaxiDriver.stateMissed,
        OfferState.notSelected => TripStringsTaxiDriver.stateNotSelected,
        OfferState.ringing || OfferState.selected => null,
        _ => TripStringsTaxiDriver.stateClosed,
      };
}
