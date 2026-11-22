import '../../../../models/browse_item.dart';
import '../../../../models/stay_offer.dart';
import '../../../nearby/models/nearby_models.dart';
import '../../models/stay_browse_item.dart';
import '../../models/stay_price_chip.dart';

class StayFeedItem {
  final BrowseItem item;
  final NearbyDistance distance;
  final num? minPrice;
  final StayPriceChip? priceChip;
  final StayOffer? offer;

  const StayFeedItem({required this.item, required this.distance, this.minPrice, this.priceChip, this.offer});

  String get id => item.id;

  factory StayFeedItem.fromJson(Map<String, dynamic> j) => StayFeedItem(
        item: StayBrowseItem.fromJson(j),
        distance: NearbyDistance.fromJson(j) ?? const NearbyDistance(km: 0, label: NearbyLabel.near),
        minPrice: j['minPricePerNight'] as num?,
        priceChip: StayPriceChip.fromJson(j['priceChip']),
        offer: StayOffer.fromFeedJson(j),
      );
}
