import '../json/owner_dates.dart';

class PriceRule {
  const PriceRule({required this.from, required this.to, required this.lower, required this.percent});

  final DateTime from;
  final DateTime to;
  final bool lower;
  final int percent;

  bool covers(DateTime night) => OwnerDates.within(night, from, to);
}

class DateRange {
  const DateRange(this.from, this.to);

  final DateTime from;
  final DateTime to;
}

abstract final class SpecialPriceMath {
  static const int minPrice = 100;
  static const int maxPrice = 9900000;

  static int adjust(int base, bool lower, int percent) {
    final raw = base * (lower ? 100 - percent : 100 + percent);
    final price = ((raw + 500) ~/ 1000) * 10;
    return price.clamp(minPrice, maxPrice);
  }

  static int priceOn(int base, DateTime night, List<PriceRule> rules) {
    for (final r in rules) {
      if (r.covers(night)) return adjust(base, r.lower, r.percent);
    }
    return base;
  }

  static List<DateTime> nightsOf(DateTime checkIn, int nights) =>
      [for (var i = 0; i < nights; i++) OwnerDates.addDays(checkIn, i)];

  static int total(int base, DateTime checkIn, int nights, List<PriceRule> rules) {
    var sum = 0;
    for (final n in nightsOf(checkIn, nights)) {
      sum += priceOn(base, n, rules);
    }
    return sum;
  }

  static int perNight(int total, int nights) {
    if (nights <= 0) return 0;
    return ((total + 5 * nights) ~/ (10 * nights)) * 10;
  }

  static int? lowerPercentFor(int base, DateTime checkIn, int nights, List<PriceRule> rules) {
    var signed = 0;
    int? best;
    for (final n in nightsOf(checkIn, nights)) {
      for (final r in rules) {
        if (!r.covers(n)) continue;
        if (r.lower) {
          signed -= r.percent;
          if (best == null || r.percent > best) best = r.percent;
        } else {
          signed += r.percent;
        }
      }
    }
    return best != null && signed < 0 ? best : null;
  }

  static bool touchesBlock(DateTime checkIn, int nights, List<DateRange> blocks) {
    for (final n in nightsOf(checkIn, nights)) {
      for (final b in blocks) {
        if (OwnerDates.within(n, b.from, b.to)) return true;
      }
    }
    return false;
  }
}
