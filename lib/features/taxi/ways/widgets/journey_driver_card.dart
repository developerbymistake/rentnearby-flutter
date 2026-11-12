import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../../models/browse_item.dart';
import '../../../../utils/contact_launcher.dart';
import '../../guest/taxi_navigation.dart';
import '../../taxi_option_sets.dart' show TaxiOptionSets;
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../../../trip/trip_strings_algo_aa.dart';

class JourneyDriverCard extends StatelessWidget {
  final WayDriver driver;
  final Color? color;
  final int otherCount;
  final VoidCallback? onChange;
  final String? caption;
  final bool selected;
  final VoidCallback? onTap;
  final String? seatsNote;

  const JourneyDriverCard({
    super.key,
    required this.driver,
    this.color,
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
    return DriverOptionCard(
      name: d.driverName,
      nameMaxLines: 2,
      vehicle: caption ?? vehicleLine(d),
      badge: d.repliesInApp ? TaxiWaysStrings.repliesInApp : null,
      fareValue: d.isEstimate ? TripStringsAlgoAa.about(BrowseItem.inr(d.fare)) : BrowseItem.inr(d.fare),
      tone: KitTone.taxi,
      legColor: color,
      avatarInitial: d.initial,
      selected: selected,
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: 4),
      header: seatsNote == null
          ? null
          : KitStatusStrip(label: seatsNote!, color: DesignColors.warnDeep, icon: Icons.info_outline_rounded),
      actions: [
        PillAction(
          label: TaxiWaysStrings.call,
          filled: true,
          tone: KitTone.taxi,
          icon: const Icon(Icons.call_rounded, size: 16, color: DesignColors.onPrimary),
          maxWidth: 150,
          onTap: () => call(d),
        ),
        PillAction(
          label: TaxiWaysStrings.whatsApp,
          tone: KitTone.taxi,
          icon: const WhatsAppGlyph(size: 18),
          maxWidth: 150,
          onTap: () => whatsApp(d),
        ),
        if (onChange != null && otherCount > 0)
          PillAction(
            label: TaxiWaysStrings.otherDrivers(otherCount),
            tone: KitTone.taxi,
            maxWidth: 220,
            onTap: onChange,
          ),
      ],
    );
  }
}
