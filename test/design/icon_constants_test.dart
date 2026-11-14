import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/design/extra/travel_icon.dart';
import 'package:bakhli/design/extra/trip_spot_look.dart';
import 'package:bakhli/design/tokens/listing_palette.dart';

void main() {
  test('every ListingArt and TravelIcon constant points to an existing file', () {
    const all = <String>[
      ListingArt.taxi, ListingArt.bus, ListingArt.stay, ListingArt.hotel, ListingArt.hotelBuilding,
      ListingArt.search, ListingArt.profile, ListingArt.guests, ListingArt.briefcase, ListingArt.flag,
      ListingArt.warning, ListingArt.bulb, ListingArt.antenna, ListingArt.paw, ListingArt.hotSprings,
      ListingArt.potOfFood, ListingArt.bed, ListingArt.key, ListingArt.luggage, ListingArt.compass,
      ListingArt.backpack, ListingArt.airplane, ListingArt.mountain, ListingArt.camping, ListingArt.fox,
      ListingArt.seedling, ListingArt.cardIndex, ListingArt.alarmClock, ListingArt.memo, ListingArt.shield,
      ListingArt.locked, ListingArt.mobilePhone, ListingArt.hinduTemple, ListingArt.sunriseMountains,
      ListingArt.canoe, ListingArt.ferrisWheel, ListingArt.classicalBuilding, ListingArt.tiger,
      ListingArt.droplet, ListingArt.rock, ListingArt.framedPicture, ListingArt.lion, ListingArt.bridge,
      ListingArt.castle, ListingArt.crown, ListingArt.diyaLamp, ListingArt.tree, ListingArt.tulip,
      ListingArt.tent, ListingArt.beach, ListingArt.worldMap, ListingArt.roundPushpin,
      TravelIcon.stay, TravelIcon.profile, TravelIcon.fox, TravelIcon.hinduTemple, TravelIcon.tulip,
    ];
    for (final a in all) {
      expect(File(a).existsSync(), isTrue, reason: a);
    }
  });

  test('Stays use camping and Profile uses fox', () {
    expect(ListingArt.stay, endsWith('/camping.png'));
    expect(ListingArt.hotel, ListingArt.stay);
    expect(TravelIcon.stay, endsWith('/camping.png'));
    expect(ListingArt.profile, endsWith('/fox.png'));
    expect(TravelIcon.profile, endsWith('/fox.png'));
  });

  test('TripSpotLook.assetOf maps every category', () {
    const expected = <String, String>{
      'temple': ListingArt.hinduTemple,
      'viewpoint': ListingArt.sunriseMountains,
      'lake': ListingArt.canoe,
      'attraction': ListingArt.ferrisWheel,
      'historic': ListingArt.classicalBuilding,
      'wildlife': ListingArt.tiger,
      'waterfall': ListingArt.droplet,
      'cave': ListingArt.rock,
      'museum': ListingArt.framedPicture,
      'zoo': ListingArt.lion,
      'bridge': ListingArt.bridge,
      'beach': ListingArt.beach,
      'fort': ListingArt.castle,
      'palace': ListingArt.crown,
      'ghat': ListingArt.diyaLamp,
      'park': ListingArt.tree,
      'garden': ListingArt.tulip,
      'other': ListingArt.roundPushpin,
      'unknown_category': ListingArt.roundPushpin,
    };
    expected.forEach((cat, asset) {
      expect(TripSpotLook.assetOf(cat), asset, reason: cat);
      expect(File(asset).existsSync(), isTrue, reason: asset);
    });
    expect(TripSpotLook.assetOf('park'), isNot(ListingArt.camping));
  });
}
