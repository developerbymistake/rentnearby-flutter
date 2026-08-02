import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/service_category_model.dart';
import '../models/service_list_item_model.dart';
import '../utils/service_icons.dart';
import 'service_rail_card.dart';
import 'service_zone.dart';

class ServiceCategoryRail extends StatelessWidget {
  final ServiceCategoryModel category;
  final ServiceZone zone;
  final List<ServiceListItemModel> items;

  const ServiceCategoryRail({
    super.key,
    required this.category,
    required this.zone,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: zone.background,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(serviceIconFor(category.iconName), size: 16, color: zone.accent),
                    const SizedBox(width: 6),
                    Text(
                      category.name,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.serviceCategoryGrid, arguments: {
                    'categoryId': category.id,
                    'title': category.name,
                  }),
                  child: Text(
                    'View all',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: zone.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ServiceRailCard(service: items[i], zone: zone),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceRailShimmer extends StatelessWidget {
  const ServiceRailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            width: 150,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}
