import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../models/trip_model.dart';
import '../models/trip_spot_category.dart';
import '../trip_colors.dart';

class TripCard extends StatelessWidget {
  final TripSummaryModel trip;
  final VoidCallback onOpen;
  final VoidCallback onMap;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.onOpen,
    required this.onMap,
    required this.onShare,
    required this.onDelete,
  });

  static String _count(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: fg),
        ),
      );

  Widget _action(IconData icon, String label, VoidCallback onTap, {double opacity = 1}) => Expanded(
        child: Opacity(
          opacity: opacity,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 15, color: TripColors.accentDark),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final stayName = t.stayName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.06, blur: 10, offset: const Offset(0, 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: Icon(TripSpotCategory.iconOf(t.category), size: 22, color: TripColors.accentDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.cityName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                          ),
                          const SizedBox(width: 6),
                          t.isPlanned
                              ? _chip('Planned', AppColors.successSurface, AppColors.successText)
                              : _chip('Draft', AppColors.divider, AppColors.textMedium),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_count(t.dayCount, 'day')} · ${_count(t.spotCount, 'spot')}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (_) => onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(fontFamily: 'Poppins', color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ),
            if (t.taxiDays > 0 || (stayName != null && stayName.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (t.taxiDays > 0) _chip('🚗 Taxi: ${_count(t.taxiDays, 'day')}', TripColors.surface, TripColors.accentDark),
                  if (stayName != null && stayName.isNotEmpty) _chip('🏨 $stayName', TripColors.surface, TripColors.accentDark),
                ],
              ),
            ],
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.divider),
            Row(
              children: [
                _action(Iconsax.arrow_right_3, 'Open', onOpen),
                _action(Iconsax.map_1, 'Map', onMap),
                _action(Iconsax.share, 'Share', onShare, opacity: 0.4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
