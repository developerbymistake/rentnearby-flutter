import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../design/design.dart';
import '../models/home_feed_model.dart';

class HomeStayRailCard extends StatelessWidget {
  static double get cellWidth => DS.s(160);

  final HomeStayModel stay;
  final VoidCallback? onOpen;
  final int index;

  const HomeStayRailCard({super.key, required this.stay, this.onOpen, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final item = stay.item;
    final url = item.thumbnailUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    return MealsCardV(
      tone: ListingTone.list(ListingTone.forest, index),
      tag: item.tagLabel,
      title: item.title,
      description: item.placeName ?? item.locationLabel,
      chips: item.distanceLabel == null ? null : [item.distanceLabel!],
      photo: hasPhoto ? KitPhoto(url: url, width: DS.s(100), height: DS.s(100), asset: TravelIcon.stay, iconSize: 40) : null,
      sticker: hasPhoto ? ListingArt.stay : null,
      art: hasPhoto ? null : ListingArt.stay,
      caption: item.priceCaption,
      number: item.priceValue.isEmpty ? null : item.priceValue,
      unit: item.priceUnit,
      width: cellWidth,
      titleLines: 2,
      uniformSlots: true,
      onTap: onOpen ?? () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': item.id}),
    );
  }
}
