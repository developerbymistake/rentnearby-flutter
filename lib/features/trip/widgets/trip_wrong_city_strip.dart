import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../taxi/taxi_option_sets.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_strings_mcc_a2.dart';
import '../utils/trip_enquiry_rules.dart';

class TripWrongCityStrip extends StatelessWidget {
  const TripWrongCityStrip({
    super.key,
    required this.enquiry,
    required this.info,
    this.onCancel,
    this.onChangeDays,
    this.dense = false,
  });

  final TripEnquiryModel enquiry;
  final WrongCityInfo info;
  final VoidCallback? onCancel;
  final VoidCallback? onChangeDays;
  final bool dense;

  static String lineOf(TripEnquiryModel e, WrongCityInfo info) {
    final taxi = e.isTaxi;
    if (info.total > 1) {
      return taxi
          ? TripStringsMccA2.daysInCity(info.wrong, info.total, info.dayCity)
          : TripStringsMccA2.nightsInCity(info.wrong, info.total, info.dayCity);
    }
    return taxi
        ? TripStringsMccA2.dayInCity(info.firstWrongDay, info.dayCity)
        : TripStringsMccA2.nightInCity(info.firstWrongDay, info.dayCity);
  }

  Widget _action(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripStatusColors.failed),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final taxi = enquiry.isTaxi;
    final kindColor = taxi ? TaxiColors.accent : StayColors.accent;
    final name = enquiry.listingName;
    final line = lineOf(enquiry, info);
    final actions = [
      if (onCancel != null) _action(TripStringsMccA2.cancel, onCancel!),
      if (onChangeDays != null) _action(TripStringsMccA2.changeDays, onChangeDays!),
    ];
    return Container(
      margin: EdgeInsets.only(top: dense ? 6 : 8),
      decoration: BoxDecoration(
        color: TripStatusColors.failedSurface,
        borderRadius: BorderRadius.circular(dense ? 10 : 12),
        border: Border.all(color: TripStatusColors.failed.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dense ? 9 : 11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: TripStatusColors.failed),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, dense ? 6 : 8, 6, actions.isEmpty ? (dense ? 6 : 8) : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(taxi ? Iconsax.car : Iconsax.building_4, size: 14, color: kindColor),
                          const SizedBox(width: 6),
                          const Icon(Iconsax.warning_2, size: 14, color: TripStatusColors.failed),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              TripStringsMccA2.wrongCityNow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.errorText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name.isEmpty || dense ? line : '$name · $line',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.errorText),
                      ),
                      if (actions.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(alignment: WrapAlignment.end, children: actions),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
