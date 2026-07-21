import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/service_list_item_model.dart';
import '../utils/service_icons.dart';
import 'service_zone.dart';

/// Rich card for one Service — cover photo + name + 2-line short description.
/// Tapping goes straight to Service Detail (there are no intermediate list
/// screens in the catalog anymore). Used at a fixed [width] inside the
/// horizontal category rails and with `width: null` (cell-sized) inside the
/// View-all grid — the ONE card design the user sees everywhere, extracted
/// from the formerly duplicated `_ServiceRailCard` in home_screen.dart and
/// local_services_screen.dart.
class ServiceRailCard extends StatelessWidget {
  final ServiceListItemModel service;
  final ServiceZone zone;
  final double? width; // 150 in rails; null = expand to the grid cell
  final double imageHeight; // 90 in rails; taller in the grid

  const ServiceRailCard({
    super.key,
    required this.service,
    required this.zone,
    this.width = 150,
    this.imageHeight = 90,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.serviceDetail, arguments: {'id': service.id}),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: zone.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: service.coverPhotoUrl.isEmpty
                        ? _placeholder()
                        : CachedNetworkImage(
                            imageUrl: service.coverPhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: zone.imgBg),
                            errorWidget: (_, __, ___) => _placeholder(),
                          ),
                  ),
                  if (service.isFeatured)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.93), borderRadius: BorderRadius.circular(20)),
                        child: const Text(
                          'Featured',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(serviceIconFor(service.iconName), size: 12, color: zone.accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          service.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, color: AppColors.textLight, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: zone.imgBg,
        child: Center(child: Icon(Icons.travel_explore_rounded, size: 26, color: zone.accent)),
      );
}
