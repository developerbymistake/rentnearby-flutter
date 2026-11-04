import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../guest/taxi_navigation.dart';
import '../../models/taxi_browse_item.dart';
import '../../taxi_option_sets.dart';
import '../taxi_ways_strings.dart';

class LocalTaxiRailCard extends StatelessWidget {
  static const double baseHeight = 176;

  final TaxiBrowseItem item;
  final double width;

  const LocalTaxiRailCard({super.key, required this.item, this.width = 190});

  static double heightFor(BuildContext context) {
    final s = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    return baseHeight + (s - 1) * 90;
  }

  @override
  Widget build(BuildContext context) {
    final rate = item.localDayRate;
    final seats = item.seats;
    final sub = [
      item.vehicleTypeName,
      if (seats != null) '${TaxiOptionSets.seatsLabel(seats)} seats',
    ].join(' · ');
    return SizedBox(
      width: width,
      height: heightFor(context),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => TaxiNavigation.openDetail(item.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: TaxiColors.surface, shape: BoxShape.circle),
                  child: const Icon(Iconsax.car, size: 16, color: TaxiColors.accent),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: TaxiColors.surface, borderRadius: BorderRadius.circular(999)),
                    child: Text(TaxiWaysStrings.localTag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: TaxiColors.accentDark)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Text(item.driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
              if (rate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(TaxiWaysStrings.perDay(rate),
                        maxLines: 1,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TaxiColors.accentDark)),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => TaxiNavigation.openDetail(item.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TaxiColors.accentDark,
                    side: const BorderSide(color: TaxiColors.accent),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(TaxiWaysStrings.viewAndCall,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
