import '../features/stay/models/stay_price_chip.dart';

class StayOffer {
  const StayOffer({required this.oldPerNight, required this.offerPerNight, this.percent});

  final int oldPerNight;
  final int offerPerNight;
  final int? percent;

  static StayOffer? fromFeedJson(Map<String, dynamic> j) {
    try {
      final p = j['offerPercent'];
      final pct = p is num ? p.toInt() : (p is String ? int.tryParse(p.trim()) : null);
      return of(
        old: StayPriceChip.money(j['oldPricePerNight']),
        offer: StayPriceChip.money(j['offerPricePerNight']),
        percent: pct,
      );
    } catch (_) {
      return null;
    }
  }

  static StayOffer? of({int? old, int? offer, int? percent}) {
    if (old == null || offer == null || old <= 0 || offer <= 0 || offer >= old) return null;
    final pct = percent != null && percent >= 1 && percent <= 99 ? percent : null;
    return StayOffer(oldPerNight: old, offerPerNight: offer, percent: pct);
  }
}
