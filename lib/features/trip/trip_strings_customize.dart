import 'models/trip_spot_category.dart';
import 'trip_constants.dart';
import 'utils/trip_format.dart';

class TripStringsCustomize {
  static const String full = 'Full';
  static const String busyDay = 'Busy day';
  static const String placeMovedAway = 'Place moved away';
  static const String dayFullDrop = 'Day is full. Places cannot be dropped here.';
  static const String addPlaces = 'Add places';
  static const String deleteDay = 'Delete day';
  static const String noPlacesYet = 'No places yet';
  static const String addOrDelete = 'Add places or delete this day.';
  static const String restDay = 'Rest day';
  static const String dayMenu = 'Day options';
  static const String holdToMove = 'Hold to move';
  static const String removeFromTrip = 'Remove from trip';
  static const String removeBody = 'It leaves this day. You can add it again later.';
  static const String keepIt = 'Keep it';

  static const String hintDrag = 'Drag places to reorder or move them to another day.';
  static const String hintCity = 'Places stay in this city. Other cities are not changed.';
  static const String addDay = 'Add day';
  static const String newDayEmpty = 'New day starts empty';
  static const String reset = 'Reset';
  static const String update = 'Update plan';
  static const String planUpdated = 'Plan updated';
  static const String planChanged = 'Plan changed. Open Customize again.';
  static const String discardTitle = 'Discard changes?';
  static const String discardBody = 'Your changes to this city are not saved yet.';
  static const String keepEditing = 'Keep editing';
  static const String discard = 'Discard';
  static const String cannotApply = 'These places do not fit these days. Add a day or remove places.';
  static const String readOnly = 'Past days and finished trips cannot be changed.';
  static const String running = 'This city has started. Its days cannot be cut.';
  static const String missingCity = 'City not found. Open Customize again.';
  static const String maxDays = 'No more days can be added to this trip.';

  static String title(String city) => 'Customize $city';

  static String bookingsFirst(String city) => 'Cancel the bookings in $city first.';

  static String blockedTitle(int days) => 'Too many places for $days ${days == 1 ? 'day' : 'days'}. Move or remove places first.';

  static String blockedDetail(int places, int days, int fit) =>
      '$places ${places == 1 ? 'place' : 'places'}. $days ${days == 1 ? 'day fits' : 'days fit'} $fit.';

  static String deletedDone(int day, int moved, List<int> intoDayNumbers) {
    if (moved == 0 || intoDayNumbers.isEmpty) return 'Day $day deleted.';
    final into = intoDayNumbers.length == 1
        ? 'Day ${intoDayNumbers.first}'
        : '${intoDayNumbers.take(intoDayNumbers.length - 1).map((d) => 'Day $d').join(', ')} and Day ${intoDayNumbers.last}';
    return 'Day $day deleted. Its $moved ${moved == 1 ? 'place' : 'places'} moved into $into.';
  }

  static String summary(int days, int places, {String? dates}) {
    final core = '$days ${days == 1 ? 'day' : 'days'} · $places ${places == 1 ? 'place' : 'places'}';
    return dates == null ? core : '$dates · $core';
  }

  static String dayTitle(int day, DateTime? date) => date == null ? 'Day $day' : 'Day $day · ${TripFormat.shortDate(date)}';

  static String dayLabel(int day) => 'Day $day';

  static String placesChip(int n) => '$n/${TripConstants.maxSpotsPerDay} places';

  static String emptyDayError(int day) => 'Day $day is empty. Delete it or add places.';

  static String removeTitle(String name) => 'Remove $name?';

  static String span(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return m == 0 ? '0 h' : '$m m';
    return m == 0 ? '$h h' : '$h h $m m';
  }

  static String spotLine(String category, int visitMinutes) => '${TripSpotCategory.label(category)} · ${span(visitMinutes)}';
}
