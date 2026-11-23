import 'package:flutter/foundation.dart';
import '../models/trip_spot_model.dart';
import '../utils/spot_gallery_cache.dart';
import 'trip_repository.dart';

class SpotDetail {
  final TripSpotModel? spot;
  final List<String> gallery;
  final String version;

  const SpotDetail({this.spot, this.gallery = const [], this.version = ''});

  factory SpotDetail.fromJson(Map<String, dynamic> data) => SpotDetail(
        spot: TripSpotModel.tryFromJson(data),
        gallery: TripSpotModel.cleanUrls(data['gallery'], TripSpotModel.maxGallery),
        version: DateTime.tryParse(data['generatedAt'] as String? ?? '')?.toIso8601String() ?? '',
      );
}

abstract final class SpotGalleryLoader {
  static TripRepository _repository = const TripRepository();
  static final Map<String, Future<SpotDetail>> _inFlight = {};

  @visibleForTesting
  static set repository(TripRepository repo) => _repository = repo;

  @visibleForTesting
  static void debugReset() {
    _repository = const TripRepository();
    _inFlight.clear();
  }

  // revalidate: skip the cache read and store the answer under its own version.
  static Future<SpotDetail> load(int cityKey, String spotId, String version, {TripRepository? repo, bool revalidate = false}) {
    if (!revalidate) {
      final hit = SpotGalleryCache.get(cityKey, spotId, version);
      if (hit != null) return Future.value(hit);
    }
    final key = revalidate ? '$cityKey:$spotId' : '$cityKey:$spotId:$version';
    final running = _inFlight[key];
    if (running != null) return running;
    final future = _fetch(repo ?? _repository, cityKey, spotId, revalidate ? null : version).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  static Future<SpotDetail> _fetch(TripRepository repo, int cityKey, String spotId, String? version) async {
    final detail = await repo.spotDetail(cityKey, spotId);
    SpotGalleryCache.put(cityKey, spotId, version ?? detail.version, detail);
    return detail;
  }
}
