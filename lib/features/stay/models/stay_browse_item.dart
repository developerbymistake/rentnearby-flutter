import '../../../models/browse_item.dart';
import '../../../models/card_fact.dart';
import '../setup/stay_option_sets.dart';

abstract final class StayBrowseItem {
  static BrowseItem fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String?;
    final type = j['stayTypeName'] as String?;
    final min = j['minPricePerNight'] as num?;
    final meals = j['mealsChip'] as String?;
    final bath = j['bathroomChip'] as String?;
    final bathKey = StayOptionSets.bathroom.any((o) => o.value == bath);
    return BrowseItem(
      id: j['id'] as String,
      userId: j['userId'] as String? ?? '',
      thumbnailUrl: j['thumbnailUrl'] as String?,
      tagLabel: 'FOR STAY',
      title: (name == null || name.isEmpty) ? 'Stay' : name,
      locationLabel: [j['cityName'] as String?, j['districtName'] as String?]
          .where((s) => s != null && s.isNotEmpty)
          .join(', '),
      facts: [
        if (type != null && type.isNotEmpty) CardFact(type),
        if (meals != null && meals.isNotEmpty) CardFact(StayOptionSets.labelOf(StayOptionSets.meals, meals)),
        if (bath != null && bath.isNotEmpty)
          CardFact(bathKey ? '${StayOptionSets.labelOf(StayOptionSets.bathroom, bath)} bath' : bath),
      ],
      priceCaption: 'FROM',
      priceValue: min != null ? BrowseItem.inr(min) : 'On request',
      priceUnit: min != null ? '/night' : '',
    );
  }
}
