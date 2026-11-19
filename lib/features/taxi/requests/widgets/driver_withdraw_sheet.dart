import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../../trip/trip_strings_taxi_driver.dart';
import '../../../trip/widgets/trip_sheet_frame.dart';
import '../models/driver_request_models.dart';
import '../strings/driver_bookings_strings.dart';

class DriverWithdrawSheet extends StatefulWidget {
  const DriverWithdrawSheet({super.key, this.title = DriverBookingsStrings.sheetTitle});

  final String title;

  static Future<ReasonChip?> show(BuildContext context, {String title = DriverBookingsStrings.sheetTitle}) =>
      TripSheetFrame.show<ReasonChip>(context, DriverWithdrawSheet(title: title));

  @override
  State<DriverWithdrawSheet> createState() => _DriverWithdrawSheetState();
}

class _DriverWithdrawSheetState extends State<DriverWithdrawSheet> {
  ReasonChip _chip = TripStringsTaxiDriver.reasonOrder.first;

  @override
  Widget build(BuildContext context) {
    final chip = _chip;
    return TripSheetFrame(
      tone: ListingTone.coral,
      art: ListingArt.warning,
      title: widget.title,
      footer: GradientPillButton(
        key: const ValueKey('driver_withdraw_confirm'),
        tone: ListingTone.coral,
        label: DriverBookingsStrings.confirmWithdraw,
        danger: true,
        onTap: () => Navigator.pop(context, chip),
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
