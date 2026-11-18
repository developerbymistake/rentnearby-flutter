import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../../trip/trip_strings_taxi_driver.dart';
import '../../../trip/widgets/trip_sheet_frame.dart';
import '../models/driver_request_models.dart';
import '../strings/driver_bookings_strings.dart';

class DriverWithdrawSheet extends StatefulWidget {
  const DriverWithdrawSheet({super.key});

  static Future<ReasonChip?> show(BuildContext context) =>
      TripSheetFrame.show<ReasonChip>(context, const DriverWithdrawSheet());

  @override
  State<DriverWithdrawSheet> createState() => _DriverWithdrawSheetState();
}

class _DriverWithdrawSheetState extends State<DriverWithdrawSheet> {
  ReasonChip? _chip;

  @override
  Widget build(BuildContext context) {
    final chip = _chip;
    return TripSheetFrame(
      tone: ListingTone.coral,
      art: ListingArt.warning,
      title: DriverBookingsStrings.sheetTitle,
      footer: GradientPillButton(
        key: const ValueKey('driver_withdraw_confirm'),
        tone: ListingTone.coral,
        label: DriverBookingsStrings.confirmWithdraw,
        danger: true,
        onTap: chip == null ? null : () => Navigator.pop(context, chip),
      ),
      children: [
        Wrap(
          spacing: DS.gh(10),
          runSpacing: DS.gv(10),
          children: [
            for (final c in TripStringsTaxiDriver.reasonOrder)
              KitChoiceChip(
                key: ValueKey('driver_reason_${c.wire}'),
                label: TripStringsTaxiDriver.reasonLabel(c),
                selected: c == chip,
                onTap: () => setState(() => _chip = c),
              ),
          ],
        ),
      ],
    );
  }
}
