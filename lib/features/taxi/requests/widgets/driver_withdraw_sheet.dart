import 'package:flutter/material.dart';

import '../../../trip/trip_strings_taxi_driver.dart';
import '../../../trip/widgets/taxi_status/taxi_reason_sheet.dart';
import '../models/driver_request_models.dart';
import '../strings/driver_bookings_strings.dart';

class DriverWithdrawSheet extends StatelessWidget {
  const DriverWithdrawSheet({super.key, this.title = DriverBookingsStrings.sheetTitle});

  final String title;

  static Future<ReasonChip?> show(BuildContext context, {String title = DriverBookingsStrings.sheetTitle}) =>
      TaxiReasonSheet.show<ReasonChip>(context, DriverWithdrawSheet(title: title));

  @override
  Widget build(BuildContext context) {
    return TaxiReasonSheet<ReasonChip>(
      title: title,
      reasons: TripStringsTaxiDriver.reasonOrder,
      initial: TripStringsTaxiDriver.reasonOrder.first,
      labelOf: TripStringsTaxiDriver.reasonLabel,
      chipKeyOf: (c) => ValueKey('driver_reason_${c.wire}'),
      confirmLabel: DriverBookingsStrings.confirmWithdraw,
      confirmKey: const ValueKey('driver_withdraw_confirm'),
      onConfirm: (c, chip) => Navigator.pop(c, chip),
    );
  }
}
