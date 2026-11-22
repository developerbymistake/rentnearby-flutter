import 'package:flutter/foundation.dart';
import '../models/trip_spot_model.dart';
import '../utils/spot_gallery_cache.dart';
import 'trip_repository.dart';

class SpotDetail {
  final TripSpotModel? spot;
  final List<String> gallery;

  const SpotDetail({this.spot, this.gallery = const []});

  factory SpotDetail.fromJson(Map<String, dynamic> data) => SpotDetail(
        spot: TripSpotModel.tryFromJson(data),
        gallery: TripSpotModel.cleanUrls(data['gallery'], TripSpotModel.maxGallery),
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

  static Future<SpotDetail> load(int cityKey, String spotId, String version, {TripRepository? repo}) {
    final hit = SpotGalleryCache.get(cityKey, spotId, version);
    if (hit != null) return Future.value(hit);
    final key = '$cityKey:$spotId:$version';
    final running = _inFlight[key];
    if (running != null) return running;
    final future = _fetch(repo ?? _repository, cityKey, spotId, version).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  static Future<SpotDetail> _fetch(TripRepository repo, int cityKey, String spotId, String version) async {
    final detail = await repo.spotDetail(cityKey, spotId);
    SpotGalleryCache.put(cityKey, spotId, version, detail);
    return detail;
  }
}
