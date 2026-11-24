import 'package:get/get.dart';
import '../../../models/place_result_model.dart';
import 'taxi_ways_controller.dart';
import 'taxi_ways_repository.dart';

enum WaysAvailability { idle, loading, available, unavailable, failed }

// Same date and people the ways feed opens with, so the entry card never promises a way the feed cannot show.
class TaxiWaysAvailabilityCheck {
  final TaxiWaysRepository _repo;

  TaxiWaysAvailabilityCheck({TaxiWaysRepository repo = const TaxiWaysRepository()}) : _repo = repo;

  final state = WaysAvailability.idle.obs;
  String? _key;
  int _gen = 0;

  bool get isAvailable => state.value == WaysAvailability.available;

  static String keyOf(PlaceResult from, PlaceResult to, bool fromMyLocation) =>
      '${from.latLng.latitude.toStringAsFixed(5)},${from.latLng.longitude.toStringAsFixed(5)}'
      '|${to.latLng.latitude.toStringAsFixed(5)},${to.latLng.longitude.toStringAsFixed(5)}|$fromMyLocation';

  void reset() {
    _gen++;
    _key = null;
    state.value = WaysAvailability.idle;
  }

  Future<void> check({required PlaceResult from, required PlaceResult to, bool fromMyLocation = false}) async {
    final key = keyOf(from, to, fromMyLocation);
    final same = key == _key;
    if (same && state.value == WaysAvailability.loading) return;
    _key = key;
    final myGen = ++_gen;
    if (!same) state.value = WaysAvailability.loading;
    try {
      final ok = await _repo.available(
        fromLat: from.latLng.latitude,
        fromLng: from.latLng.longitude,
        toLat: to.latLng.latitude,
        toLng: to.latLng.longitude,
        date: TaxiWaysController.defaultDate(),
        people: TaxiWaysController.defaultPeople,
        fromMyLocation: fromMyLocation,
      );
      if (myGen != _gen) return;
      state.value = ok ? WaysAvailability.available : WaysAvailability.unavailable;
    } catch (_) {
      if (myGen != _gen) return;
      if (!same) state.value = WaysAvailability.failed;
    }
  }
}
