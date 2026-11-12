import '../features/nearby/models/nearby_models.dart';
import '../features/nearby/widgets/nearby_label_text.dart';
import '../features/stay/models/stay_browse_item.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import 'home_feed_model.dart';

abstract final class HomeFeedModelV2 {
  static HomeFeedModel fromJson(Map<String, dynamic> json) => HomeFeedModel(
        tabs: {
          for (final e in (json['tabs'] as Map? ?? const {}).entries)
            if (e.value is bool) e.key.toString(): e.value as bool,
        },
        stays: _list(json['stays'], stay),
        taxis: _list(json['taxis'], taxi),
        recentStays: _list(json['recentStays'], HomeStayModel.fromJson),
      );

  static HomeStayModel stay(Map<String, dynamic> j) {
    final line = labelLine(j);
    final shown = line == null ? j : {...j, 'cityName': line, 'districtName': ''};
    return HomeStayModel(
      item: StayBrowseItem.fromJson(shown),
      districtName: j['districtName'] as String? ?? '',
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    );
  }

  static TaxiBrowseItem taxi(Map<String, dynamic> j) {
    final line = labelLine(j, taxi: true);
    return TaxiBrowseItem.fromJson(line == null ? j : {...j, 'cityName': line});
  }

  static String? labelLine(Map<String, dynamic> j, {bool taxi = false}) {
    final d = NearbyDistance.fromJson(j);
    if (d == null) return null;
    final shown = NearbyDistance(
      km: d.km,
      label: d.label,
      city: d.city ?? _text(j['districtName']),
      state: d.state,
    );
    return NearbyLabelText.textFor(shown, taxi: taxi);
  }

  static String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;

  static List<T>? _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
      raw is List ? raw.whereType<Map<String, dynamic>>().map(parse).toList() : null;
}
