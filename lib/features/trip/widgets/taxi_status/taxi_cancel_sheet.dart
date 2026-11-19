import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_status.dart';
import 'taxi_reason_sheet.dart';

class TaxiCancelChoice {
  const TaxiCancelChoice(this.chip);

  final ReasonChip? chip;
}

class TaxiCancelSheet extends StatelessWidget {
  const TaxiCancelSheet({super.key, required this.withBooking});

  final bool withBooking;

  static Future<TaxiCancelChoice?> show(BuildContext context, {required bool withBooking}) =>
      TaxiReasonSheet.show<TaxiCancelChoice>(context, TaxiCancelSheet(withBooking: withBooking));

  @override
  Widget build(BuildContext context) {
    final booking = withBooking;
    return TaxiReasonSheet<ReasonChip>(
      title: booking ? TripStringsTaxiStatus.cancelSheetTitle : TripStringsTaxiStatus.cancelRequestTitle,
      subtitle: booking ? null : TripStringsTaxiStatus.cancelRequestSub,
      reasons: booking ? TripStringsTaxiStatus.reasons : const [],
      initial: booking ? ReasonChip.changedPlan : null,
      labelOf: TripStringsTaxiStatus.reasonLabel,
      chipKeyOf: (c) => ValueKey('taxi_reason_${c.wire}'),
      confirmLabel: TripStringsTaxiStatus.confirmCancel,
      confirmKey: const ValueKey('taxi_cancel_confirm'),
      onConfirm: (c, chip) => Navigator.pop(c, TaxiCancelChoice(booking ? chip : null)),
    );
  }
}
