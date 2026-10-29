import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_shadows.dart';
import '../config/module_palette.dart';
import '../features/taxi/guest/taxi_navigation.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../features/taxi/taxi_option_sets.dart';
import '../models/browse_item.dart';
import 'listing_grid_card.dart';
import 'plan_badge_chip.dart';

class HomeTaxiRailCard extends StatelessWidget {
  final TaxiBrowseItem taxi;

  const HomeTaxiRailCard({super.key, required this.taxi});

  static const _palette = ModulePalette.taxi;

  @override
  Widget build(BuildContext context) {
    final t = taxi;
    final facts = <String>[
      if (t.vehicleTypeName.isNotEmpty) t.vehicleTypeName,
      if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
    ];
    final hasFare = t.minFare != null;
    return SizedBox(
      width: 160,
      height: ListingGridCard.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: AppShadows.premium(AppColors.primary, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => TaxiNavigation.openDetail(t.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 104,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: _palette.surface,
                        alignment: Alignment.center,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(gradient: _palette.gradient, shape: BoxShape.circle),
                          child: const Icon(Iconsax.car, size: 28, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: _palette.accent, borderRadius: BorderRadius.circular(999)),
                          child: const Text(
                            'TAXI',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (t.isFeatured)
                        Positioned(top: 6, right: 6, child: PlanBadgeChip(color: _palette.accentDark)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.driverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Iconsax.location, size: 10, color: AppColors.textLight),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                t.locality,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (facts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 4, runSpacing: 4, children: [for (final f in facts) _factChip(f)]),
                        ],
                        const Spacer(),
                        const SizedBox(height: 8),
                        Container(height: 1, color: AppColors.divider.withValues(alpha: 0.6)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasFare ? 'FARE FROM' : 'LOCAL TAXI',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    if (hasFare) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        BrowseItem.inr(t.minFare!),
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.gold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Iconsax.arrow_right_3, size: 16, color: _palette.accentDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _factChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _palette.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w600, color: _palette.accentDark),
        ),
      );
}
