import '../../../../models/browse_item.dart';
import '../../../nearby/models/nearby_models.dart';
import '../../models/stay_browse_item.dart';

class StayFeedItem {
  final BrowseItem item;
  final NearbyDistance distance;

  const StayFeedItem({required this.item, required this.distance});

  String get id => item.id;

  factory StayFeedItem.fromJson(Map<String, dynamic> j) => StayFeedItem(
        item: StayBrowseItem.fromJson(j),
        distance: NearbyDistance.fromJson(j) ?? const NearbyDistance(km: 0, label: NearbyLabel.near),
      );
}
