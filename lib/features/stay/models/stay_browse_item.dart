import '../../../config/app_constants.dart';
import '../../../models/browse_item.dart';
import '../../../models/card_fact.dart';
import '../setup/stay_option_sets.dart';

abstract final class StayBrowseItem {
  static String? _url(String? u) => u == null || u.isEmpty || u.startsWith('http') ? u : '${AppConstants.serverUrl}$u';

  static BrowseItem fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String?;
    final type = j['stayTypeName'] as String?;
    final min = j['minPricePerNight'] as num?;
    final meals = j['mealsChip'] as String?;
    final roomName = j['roomNameChip'] as String?;
    return BrowseItem(
      id: j['id'] as String,
      userId: j['userId'] as String? ?? '',
      thumbnailUrl: _url(j['thumbnailUrl'] as String?),
      tagLabel: 'FOR STAY',
      title: (name == null || name.isEmpty) ? 'Stay' : name,
      locationLabel: {
        for (final s in [j['cityName'] as String?, j['districtName'] as String?])
          if (s != null && s.isNotEmpty) s,
      }.join(', '),
      facts: [
        if (type != null && type.isNotEmpty) CardFact(type),
        if (meals != null && meals.isNotEmpty) CardFact(StayOptionSets.labelOf(StayOptionSets.meals, meals)),
        if (roomName != null && roomName.isNotEmpty && roomName.toLowerCase() != (type ?? '').toLowerCase())
          CardFact(roomName),
      ],
      priceCaption: 'FROM',
      priceValue: min != null ? BrowseItem.inr(min) : 'On request',
      priceUnit: min != null ? '/night' : '',
      isFeatured: j['isFeatured'] == true,
    );
  }
}
