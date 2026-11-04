import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
import '../models/trip_model.dart';
import '../models/trip_spot_category.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';
import 'trip_status.dart';

class TripCard extends StatelessWidget {
  final TripSummaryModel trip;
  final VoidCallback onOpen;
  final VoidCallback onMap;
  final VoidCallback onSummary;
  final VoidCallback onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.onOpen,
    required this.onMap,
    required this.onSummary,
    required this.onDelete,
  });

  static String _count(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

  Widget _chip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: TripColors.accentDark),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: TripColors.accentDark),
              ),
            ),
          ],
        ),
      );

  Widget _action(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: TripColors.accentDark),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TripColors.accentDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final hasChips = t.staysTotal > 0 || t.taxisTotal > 0 || t.agreedTotal > 0;
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
                          Flexible(child: TripBookingStatePill(t.state)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_count(t.dayCount, 'day')} · ${_count(t.spotCount, 'spot')}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      ),
                      if (t.startDate != null)
                        Text(
                          TripFormat.dateRange(t.startDate!, t.endDate ?? t.startDate!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  constraints: const BoxConstraints(minWidth: 120),
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (_) => onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      height: 44,
                      child: Text(TripStrings.delete, style: TextStyle(fontFamily: 'Poppins', color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ),
            if (hasChips) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (t.staysTotal > 0) _chip(TripStrings.stayCount(t.staysConfirmed, t.staysTotal), Iconsax.building_4),
                  if (t.taxisTotal > 0) _chip(TripStrings.taxiCount(t.taxisConfirmed, t.taxisTotal), Iconsax.car),
                  if (t.agreedTotal > 0) _chip(TripStrings.agreedChip(BrowseItem.inr(t.agreedTotal)), Iconsax.wallet_2),
                ],
              ),
            ],
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.divider),
            Row(
              children: [
                _action(Iconsax.arrow_right_3, TripStrings.open, onOpen),
                _action(Iconsax.document_text, TripStrings.summary, onSummary),
                _action(Iconsax.map_1, TripStrings.map, onMap),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
