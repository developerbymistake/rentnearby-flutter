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

/// One horizontal catalog rail = one ServiceCategory (the catalog's top
/// level): color-zoned band, category header with a "View all" link into the
/// card grid, and a horizontal strip of [ServiceRailCard]s. Shared verbatim
/// by Home and the Services tab — extracted from the formerly duplicated
/// `_buildServiceSectionRail` in both screens.
///
/// [items] semantics (preserved from the original `containsKey` check):
///   null  = this category's preview hasn't come back from the backend yet
///           (show the shimmer strip);
///   empty = it came back and there's genuinely nothing to show (render
///           nothing at all).
class ServiceCategoryRail extends StatelessWidget {
  final ServiceCategoryModel category;
  final ServiceZone zone;
  final List<ServiceListItemModel>? items;

  const ServiceCategoryRail({
    super.key,
    required this.category,
    required this.zone,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final loaded = items;
    if (loaded != null && loaded.isEmpty) return const SizedBox.shrink();
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
          if (loaded == null)
            const ServiceRailShimmer()
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: loaded.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => ServiceRailCard(service: loaded[i], zone: zone),
              ),
            ),
        ],
      ),
    );
  }
}

/// The 3-card loading strip shown while a rail's preview (or the whole
/// catalog) is still in flight — extracted from the formerly duplicated
/// `_buildServiceSectionShimmer`.
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
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(
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
