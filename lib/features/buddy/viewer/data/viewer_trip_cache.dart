import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../buddy_live.dart';
import '../../shared/buddy_json.dart';
import '../models/viewer_models.dart';

abstract class ViewerCacheStore {
  Object? read(String key);
  void write(String key, Object value);
  void remove(String key);
}

class _BoxStore implements ViewerCacheStore {
  GetStorage get _box => GetStorage();

  @override
  Object? read(String key) => _box.read<Object?>(key);

  @override
  void write(String key, Object value) => _box.write(key, value);

  @override
  void remove(String key) => _box.remove(key);
}

class MemoryViewerCacheStore implements ViewerCacheStore {
  final Map<String, Object> data = {};

  @override
  Object? read(String key) => data[key];

  @override
  void write(String key, Object value) => data[key] = value;

  @override
  void remove(String key) => data.remove(key);
}

class ViewerCachedTrip {
  const ViewerCachedTrip({required this.trip, this.etag});

  final ViewerTrip trip;
  final String? etag;
}

abstract final class ViewerTripCache {
  static ViewerCacheStore store = _BoxStore();
  static Worker? _goneWorker;

  static String keyOf(String tripId) => 'viewer_trip_cache:$tripId';

  static ViewerCachedTrip? read(String tripId) {
    try {
      final raw = BuddyJson.mapOrNull(store.read(keyOf(tripId)));
      if (raw == null) return null;
      final trip = BuddyJson.mapOrNull(raw['trip']);
      if (trip == null) return null;
      return ViewerCachedTrip(trip: ViewerTrip.fromJson(trip), etag: BuddyJson.strOrNull(raw['etag']));
    } catch (_) {
      remove(tripId);
      return null;
    }
  }

  static void write(String tripId, ViewerTrip trip, String? etag) {
    try {
      store.write(keyOf(tripId), {'etag': etag, 'trip': trip.toJson()});
    } catch (_) {}
  }

  static void remove(String tripId) {
    try {
      store.remove(keyOf(tripId));
    } catch (_) {}
  }

  static void watchGone() {
    _goneWorker ??= ever<String?>(BuddyLive.goneTrip, (id) {
      if (id != null && id.isNotEmpty) remove(id);
    });
  }

  static void debugReset() {
    _goneWorker?.dispose();
    _goneWorker = null;
    store = _BoxStore();
  }
}
