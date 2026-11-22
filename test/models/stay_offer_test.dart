import 'package:bakhli/models/stay_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StayOffer.of', () {
    test('needs both prices above zero and offer below old', () {
      final o = StayOffer.of(old: 1500, offer: 1275, percent: 15)!;
      expect((o.oldPerNight, o.offerPerNight, o.percent), (1500, 1275, 15));
      expect(StayOffer.of(old: 1500, offer: 1500), isNull);
      expect(StayOffer.of(old: 1500, offer: 1600), isNull);
      expect(StayOffer.of(old: null, offer: 1000), isNull);
      expect(StayOffer.of(old: 1500, offer: null), isNull);
      expect(StayOffer.of(old: 0, offer: -1), isNull);
      expect(StayOffer.of(old: 1500, offer: 0), isNull);
    });

    test('percent is kept only in 1..99', () {
      expect(StayOffer.of(old: 1500, offer: 1275, percent: 0)!.percent, isNull);
      expect(StayOffer.of(old: 1500, offer: 1275, percent: 100)!.percent, isNull);
      expect(StayOffer.of(old: 1500, offer: 1275, percent: -5)!.percent, isNull);
      expect(StayOffer.of(old: 1500, offer: 1275, percent: 1)!.percent, 1);
      expect(StayOffer.of(old: 1500, offer: 1275, percent: 99)!.percent, 99);
      expect(StayOffer.of(old: 1500, offer: 1275)!.percent, isNull);
    });
  });

  group('StayOffer.fromFeedJson', () {
    test('reads the three feed fields, numbers or numeric strings', () {
      final o = StayOffer.fromFeedJson({'oldPricePerNight': 1500, 'offerPricePerNight': 1275.0, 'offerPercent': 15})!;
      expect((o.oldPerNight, o.offerPerNight, o.percent), (1500, 1275, 15));
      final s = StayOffer.fromFeedJson({'oldPricePerNight': '1500', 'offerPricePerNight': '1275', 'offerPercent': ' 15 '})!;
      expect((s.oldPerNight, s.offerPerNight, s.percent), (1500, 1275, 15));
    });

    test('missing, null, wrong type or a higher price gives null', () {
      expect(StayOffer.fromFeedJson(const {}), isNull);
      expect(StayOffer.fromFeedJson({'oldPricePerNight': null, 'offerPricePerNight': null}), isNull);
      expect(StayOffer.fromFeedJson({'oldPricePerNight': 'abc', 'offerPricePerNight': 1275}), isNull);
      expect(StayOffer.fromFeedJson({'oldPricePerNight': true, 'offerPricePerNight': const [1]}), isNull);
      expect(StayOffer.fromFeedJson({'oldPricePerNight': 1200, 'offerPricePerNight': 1500, 'offerPercent': 20}), isNull);
      expect(StayOffer.fromFeedJson({'minPricePerNight': 1500, 'basePerNight': 1800}), isNull);
    });

    test('a bad percent drops only the percent', () {
      final o = StayOffer.fromFeedJson({'oldPricePerNight': 1500, 'offerPricePerNight': 1275, 'offerPercent': 'x'})!;
      expect(o.percent, isNull);
      expect(o.offerPerNight, 1275);
    });
  });
}
