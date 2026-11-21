import '../shared/buddy_format.dart';

enum TripLimitReason { plan, invite }

abstract final class TripLimitStrings {
  static const String title = 'Trip limit reached';
  static const String delete = 'Delete';
  static const String leave = 'Leave';
  static const String ended = 'Ended';
  static const String notNow = 'Not now';
  static const String inviteWaits = 'Your invite stays waiting.';
  static const String noDates = 'No dates yet';

  static String body(TripLimitReason reason, int limit) => switch (reason) {
        TripLimitReason.plan => 'You can keep $limit trips. Delete one to plan a new trip.',
        TripLimitReason.invite => 'You can keep $limit trips. Delete or leave one to join this trip.',
      };

  static String ownLine(DateTime? start, DateTime? end) => 'Your plan · ${_dates(start, end)}';

  static String viewerLine(String? owner, DateTime? start, DateTime? end) {
    final name = (owner ?? '').trim();
    return '${name.isEmpty ? 'Shared' : '$name’s'} trip · ${_dates(start, end)}';
  }

  static String _dates(DateTime? start, DateTime? end) {
    final r = BuddyFormat.dateRange(start, end);
    return r.isEmpty ? noDates : r;
  }
}
