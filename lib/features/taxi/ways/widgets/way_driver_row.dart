import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_shadows.dart';
import '../../../../models/browse_item.dart';
import '../../taxi_option_sets.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../../../trip/trip_strings_algo_aa.dart';
import '../../../trip/trip_strings_steps_a3.dart';
import 'best_way_mark.dart';

class WayDriverRow extends StatelessWidget {
  final WayDriver driver;
  final int people;
  final String? bestReason;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback? onUse;
  final bool useBusy;

  const WayDriverRow({
    super.key,
    required this.driver,
    required this.onTap,
    this.people = 1,
    this.bestReason,
    this.onCall,
    this.onUse,
    this.useBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = driver;
    final from = d.reversed ? d.toName : d.fromName;
    final to = d.reversed ? d.fromName : d.toName;
    final vehicle = d.vehicleCategory != null ? TaxiOptionSets.categoryLabel(d.vehicleCategory) : d.vehicleTypeName;
    final line = [
      TaxiWaysStrings.subtitle(from, to),
      vehicle,
      if (d.repliesInApp) TaxiWaysStrings.repliesInApp,
    ].join(' · ');
    final best = bestReason != null;
    final cars = d.carsFor(people);
    final price = BrowseItem.inr(d.groupFare(people));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: best ? TaxiColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: best ? TaxiColors.accent.withValues(alpha: 0.55) : AppColors.divider, width: best ? 1.4 : 1),
            boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.06, blur: 10, offset: const Offset(0, 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (best) ...[
              BestWayMark(reason: bestReason!),
              const SizedBox(height: 10),
            ],
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: TaxiColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Iconsax.car, size: 20, color: TaxiColors.accentDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(
                      d.driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    _tag(cars > 1
                        ? TripStringsAlgoAa.cars(cars)
                        : (d.basedHere ? TaxiWaysStrings.basedHere : TaxiWaysStrings.oneCar)),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    d.isEstimate ? TripStringsAlgoAa.about(price) : price,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w800, color: TaxiColors.accentDark),
                  ),
                ),
              ),
            ]),
            if (onCall != null || onUse != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Iconsax.call, size: 16, color: TaxiColors.accentDark),
                      label: const Text(TaxiWaysStrings.call,
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TaxiColors.accentDark)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: BorderSide(color: TaxiColors.accent.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (onCall != null && onUse != null) const SizedBox(width: 8),
                if (onUse != null)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: useBusy ? null : onUse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TaxiColors.accentDark,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: TaxiColors.accent.withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: useBusy
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text(TripStringsStepsA3.useForMyTrip,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(6)),
        child: Text(
          text,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        ),
      );
}
