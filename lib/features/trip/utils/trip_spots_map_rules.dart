import '../models/trip_spot_model.dart';

class TripSpotsMapRules {
  TripSpotsMapRules._();

  static const int maxPins = 40;

  // Selected first (in pick order), then the rest in list order, capped.
  static List<TripSpotModel> pickPins({
    required List<TripSpotModel> all,
    required List<TripSpotModel> visible,
    required List<String> selectedOrder,
    int cap = maxPins,
  }) {
    final byId = {for (final s in all) s.id: s};
    final out = <TripSpotModel>[];
    final seen = <String>{};
    for (final id in selectedOrder) {
      final s = byId[id];
      if (s != null && seen.add(id)) out.add(s);
    }
    for (final s in visible) {
      if (out.length >= cap) break;
      if (seen.add(s.id)) out.add(s);
    }
    return out.length > cap ? out.sublist(0, cap) : out;
  }

  // 1-based pick number, or 0 when not selected.
  static int numberOf(List<String> selectedOrder, String id) => selectedOrder.indexOf(id) + 1;
}
