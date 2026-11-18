import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_status.dart';
import '../trip_sheet_frame.dart';

class TaxiCancelChoice {
  const TaxiCancelChoice(this.chip);

  final ReasonChip? chip;
}

class TaxiCancelSheet extends StatefulWidget {
  const TaxiCancelSheet({super.key, required this.withBooking});

  final bool withBooking;

  static Future<TaxiCancelChoice?> show(BuildContext context, {required bool withBooking}) =>
      TripSheetFrame.show<TaxiCancelChoice>(context, TaxiCancelSheet(withBooking: withBooking));

  @override
  State<TaxiCancelSheet> createState() => _TaxiCancelSheetState();
}

class _TaxiCancelSheetState extends State<TaxiCancelSheet> {
  ReasonChip _chip = ReasonChip.changedPlan;

  @override
  Widget build(BuildContext context) {
    final booking = widget.withBooking;
    return TripSheetFrame(
      tone: ListingTone.coral,
      art: ListingArt.warning,
      title: booking ? TripStringsTaxiStatus.cancelSheetTitle : TripStringsTaxiStatus.cancelRequestTitle,
      description: booking ? null : TripStringsTaxiStatus.cancelRequestSub,
      footer: GradientPillButton(
        key: const ValueKey('taxi_cancel_confirm'),
        tone: ListingTone.coral,
        label: TripStringsTaxiStatus.confirmCancel,
        danger: true,
        onTap: () => Navigator.pop(context, TaxiCancelChoice(booking ? _chip : null)),
      ),
      children: [
        if (booking)
          Wrap(
            spacing: DS.gh(10),
            runSpacing: DS.gv(10),
            children: [
              for (final c in TripStringsTaxiStatus.reasons)
                KitChoiceChip(
                  key: ValueKey('taxi_reason_${c.wire}'),
                  label: TripStringsTaxiStatus.reasonLabel(c),
                  selected: c == _chip,
                  onTap: () => setState(() => _chip = c),
                ),
            ],
          ),
      ],
    );
  }
}
