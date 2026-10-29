import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../config/module_palette.dart';
import '../models/home_feed_model.dart';
import 'listing_grid_card.dart';

class HomeStayRailCard extends StatelessWidget {
  final HomeStayModel stay;

  const HomeStayRailCard({super.key, required this.stay});

  @override
  Widget build(BuildContext context) {
    final item = stay.item;
    return SizedBox(
      width: 160,
      child: ListingGridCard(
        thumbnailUrl: item.thumbnailUrl,
        tagLabel: item.tagLabel,
        title: item.title,
        locationLabel: item.locationLabel,
        facts: item.facts,
        priceCaption: item.priceCaption,
        priceValue: item.priceValue,
        priceUnit: item.priceUnit,
        isPlot: false,
        accent: ModulePalette.stays.accent,
        accentDark: ModulePalette.stays.accentDark,
        isFeatured: item.isFeatured,
        onViewDetails: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': item.id}),
      ),
    );
  }
}
