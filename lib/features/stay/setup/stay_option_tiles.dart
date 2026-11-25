import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import 'stay_option_sets.dart';

abstract final class StayOptionTiles {
  static List<OptionTileItem> stayTypes(List<String> names) => [for (var i = 0; i < names.length; i++) OptionTileItem(label: names[i], art: StayOwnerArt.stayType(names[i], i))];

  static List<OptionTileItem> get vehicleAccess => [for (final o in StayOptionSets.vehicleAccess) OptionTileItem(label: o.label, art: StayOwnerArt.vehicle[o.value] ?? ListingArt.taxi)];

  static List<OptionTileItem> get hostLivesHere => const [OptionTileItem(label: 'Yes', art: ListingArt.key), OptionTileItem(label: 'No', art: ListingArt.luggage)];

  static List<OptionTileItem> get cancellation => [for (final o in StayOptionSets.cancellation) OptionTileItem(label: o.label, art: StayOwnerArt.cancellation[o.value] ?? ListingArt.star)];

  static String? houseRuleArt(String key) => switch (key) {
        'pets' => ListingArt.paw,
        'smoking' => ListingArt.camping,
        'alcohol' => ListingArt.star,
        'couples' => ListingArt.key,
        'idProof' => ListingArt.clipboard,
        _ => null,
      };
}
