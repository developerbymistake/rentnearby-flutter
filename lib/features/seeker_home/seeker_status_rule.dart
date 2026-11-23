import 'seeker_feed_model.dart';
import 'strings/seeker_home_strings.dart';

abstract final class SeekerStatusRule {
  static bool visible(SeekerStatus? status, String? seenKey) => status != null && status.key.isNotEmpty && status.key != seenKey;

  static String? line(SeekerStatus? status) => switch (status?.kind) {
        SeekerStatusKind.reply => SeekerHomeStrings.replied(status?.count ?? 0),
        SeekerStatusKind.confirmed => SeekerHomeStrings.confirmed(status?.listingName ?? ''),
        _ => null,
      };
}

abstract final class SeekerTripWords {
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _dm(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String? dates(DateTime? from, DateTime? to) {
    if (from == null) return null;
    final end = to == null || to.isBefore(from) ? from : to;
    if (from.year == end.year && from.month == end.month) {
      return from.day == end.day ? _dm(from) : SeekerHomeStrings.dateRange('${from.day}', _dm(end));
    }
    return SeekerHomeStrings.dateRange(_dm(from), _dm(end));
  }

  static String? step(SeekerNextStep? next) {
    if (next == null || next.key.isEmpty) return null;
    final city = next.cityName?.trim() ?? '';
    return switch (next.kind) {
      SeekerStepKind.taxi => SeekerHomeStrings.stepTaxi,
      SeekerStepKind.stay => city.isEmpty ? SeekerHomeStrings.stepStayAny : SeekerHomeStrings.stepStay(city),
      SeekerStepKind.journey => SeekerHomeStrings.stepJourney,
      SeekerStepKind.plan => SeekerHomeStrings.stepPlan,
      SeekerStepKind.unknown => null,
    };
  }

  static String eyebrow(SeekerTripCard card) {
    final today = card.today;
    if (card.state == SeekerTripState.onTrip && today != null && today.dayNumber > 0 && today.totalDays > 0) {
      return SeekerHomeStrings.eyebrow(card.displayTitle, SeekerHomeStrings.dayOf(today.dayNumber, today.totalDays));
    }
    return SeekerHomeStrings.eyebrow(card.displayTitle, dates(card.startDate, card.endDate));
  }

  static String todayCity(SeekerTripCard card) {
    final c = card.today?.cityName?.trim() ?? '';
    if (c.isNotEmpty) return c;
    final d = card.destinationName?.trim() ?? '';
    return d.isNotEmpty ? d : card.displayTitle;
  }
}
