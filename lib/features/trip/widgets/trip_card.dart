import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
import '../models/trip_model.dart';
import '../models/trip_spot_category.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../utils/trip_format.dart';
import 'trip_status.dart';

class TripCard extends StatelessWidget {
  final TripSummaryModel trip;
  final VoidCallback onOpen;
  final VoidCallback onSummary;
  final VoidCallback? onShare;
  final VoidCallback onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.onOpen,
    required this.onSummary,
    required this.onShare,
    required this.onDelete,
  });

  static TripBookingState stateOf(TripSummaryModel t) {
    final s = t.state;
    if (s == TripBookingState.completed) return s;
    if (s == TripBookingState.draft && t.isPlanned) return TripBookingState.planOnly;
    final settled = t.staysTotal + t.taxisTotal + t.staysOwn + t.taxisOwn;
    if (s == TripBookingState.ready && settled == 0) return TripBookingState.planOnly;
    return s;
  }

  Widget _chip(String label, IconData icon, {Color? color, Color? surface}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: surface ?? TripColors.surface, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? TripColors.accentDark),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: color ?? TripColors.accentDark),
              ),
            ),
          ],
        ),
      );

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    final c = onTap == null ? AppColors.textHint : TripColors.accentDark;
    return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: c),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: c),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final hasOwn = t.staysOwn + t.taxisOwn > 0;
    final hasChips = t.staysTotal > 0 || t.taxisTotal > 0 || t.agreedTotal > 0 || hasOwn;
    final dates = t.startDate == null
        ? TripStringsA5.noDatesYet
        : TripStrings.joinDots([
            TripFormat.dayMonthRange(t.startDate!, t.endDate ?? t.startDate!),
            TripStrings.peopleText((t.adults ?? 0) + (t.kids ?? 0)),
          ]);
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
                          Flexible(child: TripBookingStatePill(stateOf(t))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        TripStringsA5.cardMeta(t.dayCount, t.spotCount),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      ),
                      Text(
                        dates,
                        maxLines: 2,
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
                  if (hasOwn)
                    _chip(TripStringsA5.ownBooking, Iconsax.home_2,
                        color: AppColors.tripBooked, surface: TripStatusColors.bookedSurface),
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
                _action(Iconsax.share, TripStringsA5.share, onShare),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
