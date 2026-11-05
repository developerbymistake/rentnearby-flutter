import '../../models/browse_item.dart';
import 'utils/trip_format.dart';

class TripStringsStepsA2 {
  static const String stepsHint = 'Each step is optional. Skip any of them.';

  static String howGetTo(String city) => city.isEmpty ? 'How will you get there?' : 'How will you get to $city?';
  static String howComeBack(String city) => city.isEmpty ? 'How will you come back?' : 'How will you come back from $city?';

  static const String startingFrom = 'STARTING FROM';
  static const String backTo = 'BACK TO';
  static const String change = 'Change';
  static const String whereStart = 'Where are you starting from?';
  static const String whereStartBody = 'We use it to show drivers for this trip.';
  static const String pickCity = 'Pick a city';
  static const String startFromHelp = 'Starting from is used for Getting there and Coming back. It never limits the plan.';
  static const String notSet = 'Not set';

  static String feedHint(DateTime? date, int people) {
    final parts = [
      if (date != null) TripFormat.dayMonth(date),
      if (people > 0) '$people ${people == 1 ? 'person' : 'people'}',
    ];
    const tail = 'We show drivers who go all the way, or in parts.';
    return parts.isEmpty ? tail : '${parts.join(' · ')}. $tail';
  }

  static const String seeWays = 'See ways to go';
  static const String arrangeMyself = 'I will arrange it myself';
  static const String differentWayBack = 'Need a different way back?';

  static String fromTo(String from, String to) => '$from to $to';

  static String cars(int n) => '$n ${n == 1 ? 'car' : 'cars'}';
  static String aboutTotal(int total) => 'about ${BrowseItem.inr(total)}';
  static const String checkOutMorning = 'check-out morning';

  static String journeyMeta({required int cars, int? total, DateTime? date, bool checkOut = false}) => [
        if (date != null) checkOut ? TripFormat.shortDate(date) : TripFormat.dayMonth(date),
        if (date != null && checkOut) checkOutMorning,
        TripStringsStepsA2.cars(cars),
        if (total != null && total > 0) cars > 1 ? aboutTotal(total) : BrowseItem.inr(total),
      ].join(' · ');

  static const String changeCar = 'change car';
  static String carDriver(int n) => 'Car $n';
  static const String driverFallback = 'Driver';
  static const String call = 'Call';
  static const String whatsApp = 'WhatsApp';
  static String vehicleLine(String? from, String? to, String? vehicle) => [
        if ((from ?? '').isNotEmpty && (to ?? '').isNotEmpty) '$from → $to',
        if (vehicle != null && vehicle.isNotEmpty) vehicle,
      ].join(' · ');
  static String driverPaused(String driver, String? backup) =>
      backup == null || backup.isEmpty ? '$driver paused his taxi.' : '$driver paused his taxi. Backup: $backup';

  static String askDrivers(int cars) => switch (cars) {
        <= 1 => 'Ask the driver',
        2 => 'Ask both drivers',
        _ => 'Ask all drivers',
      };

  static const String openJourney = 'Open journey';
  static const String iBookedIt = 'I booked it';
  static const String notBookedYet = 'Not booked yet';
  static const String undo = 'Undo';

  static const String dateChanged = 'Date changed, check drivers';
  static const String startChanged = 'Start city changed';
  static const String searchAgain = 'Search again';
  static String searchFromAgain(String city) => 'Search ways from $city again?';
  static const String later = 'Later';

  static const String notArranged = 'Not arranged';
  static String arrangedByYou(String? note) =>
      note == null || note.trim().isEmpty ? 'Arranged by you' : 'Arranged by you · ${note.trim()}';
  static const String skippedLine = 'Skipped for now. You can come back to it.';
  static String notNeededLine(String city) => city.isEmpty ? 'You start in the trip city.' : 'You start in $city.';

  static const String arrangeTitle = 'Arrange it yourself?';
  static const String arrangeBody = 'We will stop reminders for this step.';
  static const String noteOptional = 'Note (optional)';
  static const String markArranged = 'Mark as arranged';
  static const String skipForNow = 'Skip for now';
}
