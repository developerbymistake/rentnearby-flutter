import 'package:flutter/material.dart';
import '../design/design.dart';
import '../features/seeker_home/seeker_rail_art.dart';
import '../features/seeker_home/strings/seeker_home_strings.dart';
import '../features/taxi/guest/taxi_navigation.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../models/browse_item.dart';
import 'home_stay_rail_card.dart';

class HomeTaxiRailCard extends StatelessWidget {
  final TaxiBrowseItem taxi;
  final VoidCallback? onOpen;
  final int index;

  const HomeTaxiRailCard({super.key, required this.taxi, this.onOpen, this.index = 0});

  static ListingTone toneAt(int index) => index.isEven ? ListingTone.cF : ListingTone.cB;

  static String tagOf(TaxiBrowseItem t) {
    final type = t.vehicleTypeName.trim();
    return type.isEmpty ? SeekerHomeStrings.taxiTag : type.toUpperCase();
  }

  static ({String caption, String number, String unit}) priceOf(TaxiBrowseItem t) {
    final day = t.localDayRate;
    if (day != null && day > 0) return (caption: '', number: BrowseItem.inr(day), unit: SeekerHomeStrings.perDay);
    final fare = t.minFare;
    if (fare != null) return (caption: SeekerHomeStrings.fareFrom, number: BrowseItem.inr(fare), unit: '');
    return (caption: '', number: SeekerHomeStrings.localTaxi, unit: '');
  }

  static String placeLine(TaxiBrowseItem t) {
    final base = (t.baseCityName ?? t.cityName)?.trim() ?? '';
    final km = t.distanceKm;
    return [if (base.isNotEmpty) base, if (km != null) SeekerHomeStrings.kmOf(km)].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = taxi;
    final price = priceOf(t);
    return MealsCardV(
      rail: true,
      tone: toneAt(index),
      photoUrl: t.displayPhotoUrl,
      art: SeekerRailArt.forVehicle(t.vehicleTypeName),
      tag: tagOf(t),
      starBadge: t.isFeatured,
      title: t.driverName,
      description: placeLine(t),
      caption: price.caption,
      number: price.number,
      unit: price.unit,
      width: HomeStayRailCard.cellWidth,
      titleLines: 2,
      onTap: onOpen ?? () => TaxiNavigation.openDetail(t.id),
    );
  }
}
