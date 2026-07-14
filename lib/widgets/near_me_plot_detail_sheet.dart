import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../models/plot_model.dart';

/// Detail sheet for a "Find Near Me" tour card — a SEPARATE widget from the
/// map-pin's _PlotBottomSheet (not reused), so it can be opened as a plain
/// overlay without disturbing the tour underneath. Deliberately mirrors that
/// real sheet's structure (drag handle, photo + Available badge, type chip,
/// area display, owner + distance row, single View Details button).
class NearMePlotDetailSheet extends StatelessWidget {
  final NearMePlotModel plot;
  const NearMePlotDetailSheet({super.key, required this.plot});

  Color _typeColor(String type) => switch (type) {
        'Residential' => const Color(0xFF3B82F6),
        'Commercial' => const Color(0xFFF59E0B),
        'Agricultural' => const Color(0xFF92400E),
        'Farmhouse' => const Color(0xFF16A34A),
        _ => AppColors.primary,
      };

  Widget _photoPlaceholder() => Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.landscape_rounded, size: 40, color: AppColors.textHint),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: plot.thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: plot.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: AppColors.surface),
                          errorWidget: (context, url, err) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: plot.isActive ? const Color(0xFF2E7D32) : Colors.red.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plot.isActive ? 'Available' : 'Not Available',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + AppInsets.bottomViewPadding(context)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor(plot.plotType).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plot.plotType,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _typeColor(plot.plotType),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    plot.areaDisplay,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(children: [
                    if (plot.ownerName != null && plot.ownerName!.isNotEmpty) ...[
                      const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textLight),
                      const SizedBox(width: 5),
                      Text(
                        plot.ownerName!,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13,
                            fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ] else
                      const SizedBox.shrink(),
                    const Spacer(),
                    const Icon(Icons.near_me_rounded, size: 13, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      '${plot.distanceKm.toStringAsFixed(1)} km away',
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.toNamed(AppRoutes.plotDetail, arguments: plot.id);
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'View Details',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _typeColor(plot.plotType),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
