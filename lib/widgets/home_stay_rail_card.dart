import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../design/design.dart';
import '../features/seeker_home/seeker_rail_art.dart';
import '../features/seeker_home/strings/seeker_home_strings.dart';
import '../models/home_feed_model.dart';

class HomeStayRailCard extends StatelessWidget {
  static double get cellWidth => DS.s(160);

  final HomeStayModel stay;
  final VoidCallback? onOpen;
  final int index;

  const HomeStayRailCard({super.key, required this.stay, this.onOpen, this.index = 0});

  static ListingTone toneAt(int index) => index.isEven ? ListingTone.forest : ListingTone.teal;

  static String tagOf(HomeStayModel stay) {
    final type = stay.stayTypeName?.trim() ?? '';
    return type.isEmpty ? SeekerHomeStrings.stayTag : type.toUpperCase();
  }

  static String placeLine(HomeStayModel stay) {
    final item = stay.item;
    final place = (item.placeName ?? item.locationLabel).trim();
    final km = SeekerHomeStrings.kmShort(item.distanceLabel);
    return [if (place.isNotEmpty) place, if (km.isNotEmpty) km].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final item = stay.item;
    return MealsCardV(
      rail: true,
      tone: toneAt(index),
      tag: tagOf(stay),
      title: item.title,
      description: placeLine(stay),
      photoUrl: item.thumbnailUrl,
      art: SeekerRailArt.forStay(stay.stayTypeName),
      caption: SeekerHomeStrings.from,
      number: item.priceValue.isEmpty ? null : item.priceValue,
      unit: item.priceUnit,
      width: cellWidth,
      titleLines: 2,
      onTap: onOpen ?? () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': item.id}),
    );
  }
}
