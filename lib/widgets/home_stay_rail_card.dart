import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../design/design.dart';
import '../models/home_feed_model.dart';

class HomeStayRailCard extends StatelessWidget {
  static const double cellWidth = 160;
  static const List<String> stickers = [ListingArt.key, ListingArt.bed, ListingArt.hotel];

  final HomeStayModel stay;
  final VoidCallback? onOpen;
  final int index;

  const HomeStayRailCard({super.key, required this.stay, this.onOpen, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final item = stay.item;
    final url = item.thumbnailUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final sticker = stickers[index % stickers.length];
    return MealsCardV(
      tone: ListingTone.list(ListingTone.forest, index),
      tag: item.tagLabel,
      title: item.title,
      description: item.locationLabel,
      photo: hasPhoto ? KitPhoto(url: url, width: 100, height: 100, asset: TravelIcon.stay, iconSize: 40) : null,
      sticker: hasPhoto ? sticker : null,
      art: hasPhoto ? null : ListingArt.hotel,
      caption: item.priceCaption,
      number: item.priceValue.isEmpty ? null : item.priceValue,
      unit: item.priceUnit,
      width: cellWidth,
      titleLines: 2,
      onTap: onOpen ?? () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': item.id}),
    );
  }
}
