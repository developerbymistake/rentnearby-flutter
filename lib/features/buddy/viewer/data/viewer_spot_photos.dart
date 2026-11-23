import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:get/get.dart';

import '../../../map_discovery/data/map_pack_service.dart';
import '../../../map_discovery/pack/map_pack_index.dart';

abstract final class ViewerSpotPhotos {
  @visibleForTesting
  static MapPackIndex? Function()? indexForTest;

  static MapPackIndex? _index() {
    final test = indexForTest;
    if (test != null) return test();
    return Get.isRegistered<MapPackService>() ? Get.find<MapPackService>().index : null;
  }

  static String? urlFor(String spotId) {
    if (spotId.isEmpty) return null;
    final spot = _index()?.byId(spotId);
    return spot != null && spot.hasThumb ? spot.thumbUrl : null;
  }
}
