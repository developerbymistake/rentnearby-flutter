import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../../../models/browse_item.dart';
import '../../../../utils/contact_launcher.dart';
import '../../guest/taxi_navigation.dart';
import '../../taxi_option_sets.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../../../trip/trip_strings_algo_aa.dart';

class JourneyDriverCard extends StatelessWidget {
  final WayDriver driver;
  final Color color;
  final int otherCount;
  final VoidCallback? onChange;
  final String? caption;
  final bool selected;
  final VoidCallback? onTap;
  final String? seatsNote;

  const JourneyDriverCard({
    super.key,
    required this.driver,
    this.color = TaxiColors.accent,
    this.otherCount = 0,
    this.onChange,
    this.caption,
    this.selected = false,
    this.onTap,
    this.seatsNote,
  });

  static String vehicleLine(WayDriver d) {
    final vehicle = d.vehicleCategory != null ? TaxiOptionSets.categoryLabel(d.vehicleCategory) : d.vehicleTypeName;
    return [
      vehicle,
      if (d.seats != null) '${TaxiOptionSets.seatsLabel(d.seats!)} seats',
    ].join(' · ');
  }

  static void call(WayDriver d) {
    final phone = d.phone ?? d.whatsApp;
    if (phone == null) {
      TaxiNavigation.openDetail(d.taxiId);
      return;
    }
    ContactLauncher.call(phone);
  }

  static void whatsApp(WayDriver d) {
    final phone = d.whatsApp ?? d.phone;
    if (phone == null) {
      TaxiNavigation.openDetail(d.taxiId);
      return;
    }
    ContactLauncher.whatsApp(phone);
  }

  @override
  Widget build(BuildContext context) {
    final d = driver;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? color : AppColors.divider, width: selected ? 1.6 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Text(
              d.initial,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                d.driverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              Text(
                caption ?? vehicleLine(d),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
              ),
              if (seatsNote != null)
                Text(
                  seatsNote!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warningText),
                ),
              if (d.repliesInApp)
                const Text(
                  TaxiWaysStrings.repliesInApp,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: TaxiColors.accentDark),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                d.isEstimate ? TripStringsAlgoAa.about(BrowseItem.inr(d.fare)) : BrowseItem.inr(d.fare),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _action(
              label: TaxiWaysStrings.call,
              icon: Iconsax.call,
              filled: true,
              onTap: () => call(d),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _action(
              label: TaxiWaysStrings.whatsApp,
              icon: Iconsax.message,
              filled: false,
              onTap: () => whatsApp(d),
            ),
          ),
        ]),
        if (onChange != null && otherCount > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: TaxiColors.accentDark,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Text(
                    TaxiWaysStrings.otherDrivers(otherCount),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ]),
            ),
          ),
      ]),
    );
    if (onTap == null) return card;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }

  Widget _action({required String label, required IconData icon, required bool filled, required VoidCallback onTap}) {
    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: TaxiColors.accentDark,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: TaxiColors.surface,
            foregroundColor: TaxiColors.accentDark,
            elevation: 0,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: TaxiColors.accent.withValues(alpha: 0.4)),
            ),
          );
    return ElevatedButton(
      onPressed: onTap,
      style: style,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}
