import '../../../models/my_plan_model.dart';

enum PlanKey { photos, roomTypes, jobsPosts, routes, ringWeight, calendarEntries, blockedRanges, upcomingDays, monthsAhead, monthSummary, reminders, specialPrices, quotationsPerMonth }

extension PlanKeyWire on PlanKey {
  String get wire => switch (this) {
        PlanKey.photos => 'Photos',
        PlanKey.roomTypes => 'RoomTypes',
        PlanKey.jobsPosts => 'JobsPosts',
        PlanKey.routes => 'Routes',
        PlanKey.ringWeight => 'RingWeight',
        PlanKey.calendarEntries => 'CalendarEntries',
        PlanKey.blockedRanges => 'BlockedRanges',
        PlanKey.upcomingDays => 'UpcomingDays',
        PlanKey.monthsAhead => 'MonthsAhead',
        PlanKey.monthSummary => 'MonthSummary',
        PlanKey.reminders => 'Reminders',
        PlanKey.specialPrices => 'SpecialPrices',
        PlanKey.quotationsPerMonth => 'StayQuotationsPerMonth',
      };

  bool get isSwitch => this == PlanKey.monthSummary || this == PlanKey.reminders;
}

abstract final class PlanKeys {
  static PlanKey? fromWire(String? wire) {
    for (final k in PlanKey.values) {
      if (k.wire == wire) return k;
    }
    return null;
  }

  static const Map<PlanKey, int> freeSeed = {
    PlanKey.photos: 2,
    PlanKey.roomTypes: 2,
    PlanKey.jobsPosts: 1,
    PlanKey.routes: 1,
    PlanKey.ringWeight: 1,
    PlanKey.calendarEntries: 4,
    PlanKey.blockedRanges: 1,
    PlanKey.upcomingDays: 15,
    PlanKey.monthsAhead: 0,
    PlanKey.monthSummary: 0,
    PlanKey.reminders: 0,
    PlanKey.specialPrices: 1,
    PlanKey.quotationsPerMonth: 2,
  };

  static const Map<PlanKey, int> plusSeed = {
    PlanKey.photos: 8,
    PlanKey.roomTypes: 6,
    PlanKey.jobsPosts: 4,
    PlanKey.routes: 5,
    PlanKey.ringWeight: 2,
    PlanKey.calendarEntries: 50,
    PlanKey.blockedRanges: 10,
    PlanKey.upcomingDays: 183,
    PlanKey.monthsAhead: 6,
    PlanKey.monthSummary: 1,
    PlanKey.reminders: 1,
    PlanKey.specialPrices: 5,
    PlanKey.quotationsPerMonth: 30,
  };

  static int valueOf(PlanLimitsModel l, PlanKey key) => switch (key) {
        PlanKey.photos => l.photos,
        PlanKey.roomTypes => l.roomTypes,
        PlanKey.jobsPosts => l.jobsPosts,
        PlanKey.routes => l.routes,
        PlanKey.ringWeight => l.ringWeight,
        PlanKey.calendarEntries => l.calendarEntries,
        PlanKey.blockedRanges => l.blockedRanges,
        PlanKey.upcomingDays => l.upcomingDays,
        PlanKey.monthsAhead => l.monthsAhead,
        PlanKey.monthSummary => l.monthSummary ? 1 : 0,
        PlanKey.reminders => l.reminders ? 1 : 0,
        PlanKey.specialPrices => l.specialPrices,
        PlanKey.quotationsPerMonth => l.quotationsPerMonth,
      };
}
