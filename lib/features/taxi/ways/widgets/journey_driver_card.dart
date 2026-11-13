import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
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
  final ListingTone? tone;
  final String? tag;
  final String? route;
  final Color? linkAbove;

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
    this.tone,
    this.tag,
    this.route,
    this.linkAbove,
  });

  static String vehicleLine(WayDriver d) {
    final vehicle = d.vehicleCategory != null ? TaxiOptionSets.categoryLabel(d.vehicleCategory) : d.vehicleTypeName;
    return [
      vehicle,
      if (d.seats != null) '${TaxiOptionSets.seatsLabel(d.seats!)} seats',
    ].join(' · ');
  }

  static String fareText(WayDriver d) => d.isEstimate ? TripStringsAlgoAa.about(BrowseItem.inr(d.fare)) : BrowseItem.inr(d.fare);

  static void call(WayDriver d) {
    final phone = d.phone ?? d.whatsApp;
    if (phone == null) {
      TaxiNavigation.openDetail(d.taxiId);
      return;
    }
    ContactLauncher.call(phone);
  }

  @override
  Widget build(BuildContext context) {
    final d = driver;
    return JourneyCard3D(
      tone: tone ?? ListingTone.cA,
      art: JourneyArt.forVehicle(d.vehicleTypeName, d.seats),
      tag: tag,
      title: d.driverName,
      subtitle: [caption ?? vehicleLine(d), ?route],
      pill: d.repliesInApp ? const JourneyPill3D(label: TaxiWaysStrings.repliesInApp) : null,
      fare: fareText(d),
      note: [?seatsNote],
      noteLines: 0,
      picked: selected,
      onTap: onTap,
      linkAbove: linkAbove,
      cells: [
        JourneyCell(label: TaxiWaysStrings.call, icon: Icons.call_rounded, onTap: () => call(d)),
        if (onChange != null && otherCount > 0)
          JourneyCell(label: TaxiWaysStrings.otherDrivers(otherCount), icon: Icons.swap_horiz_rounded, onTap: onChange)
        else
          null,
      ],
    );
  }
}
