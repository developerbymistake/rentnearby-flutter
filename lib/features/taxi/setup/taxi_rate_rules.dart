import '../guest/v2/taxi_rate_strings.dart';

// Mirrors the server TaxiRateRules.
abstract final class TaxiRateRules {
  static const int minRate = 100;
  static const int maxRate = 9900000;
  static const int minKm = 1;
  static const int maxKm = 1000;

  static String? rateError(String? text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return TaxiRateStrings.addDayRate;
    final v = int.tryParse(t);
    if (v == null || v < minRate || v > maxRate) return TaxiRateStrings.rateRange;
    return null;
  }

  static String? kmError(String? text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return TaxiRateStrings.addKm;
    final v = int.tryParse(t);
    if (v == null || v < minKm || v > maxKm) return TaxiRateStrings.kmRange;
    return null;
  }

  static String? validate(String? rateText, String? kmText) => rateError(rateText) ?? kmError(kmText);

  static bool done({int? rate, int? km}) =>
      rate != null && km != null && rate >= minRate && rate <= maxRate && km >= minKm && km <= maxKm;
}
