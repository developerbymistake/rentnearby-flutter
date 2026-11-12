import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../design/design.dart';
import '../models/home_feed_model.dart';

class HomeStayRailCard extends StatelessWidget {
  static const double cellWidth = RailCard.width;
  static const EdgeInsets cellPadding = EdgeInsets.only(top: 4, bottom: 20);
  static const double railHeight = RailCard.height + 24;

  final HomeStayModel stay;
  final VoidCallback? onOpen;

  const HomeStayRailCard({super.key, required this.stay, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final item = stay.item;
    return Padding(
      padding: cellPadding,
      child: SizedBox(
        width: cellWidth,
        child: RailCard(
          thumbnailUrl: item.thumbnailUrl,
          tagLabel: item.tagLabel,
          title: item.title,
          locationLabel: item.locationLabel,
          facts: item.facts,
          priceCaption: item.priceCaption,
          priceValue: item.priceValue,
          priceUnit: item.priceUnit,
          isFeatured: item.isFeatured,
          onTap: onOpen ?? () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': item.id}),
        ),
      ),
    );
  }
}
