import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../../models/browse_item.dart';
import '../taxi_ways_strings.dart';

class JourneyPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const JourneyPrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return GradientPillButton(
      tone: ListingTone.coral,
      label: label,
      loading: busy,
      height: 52,
      fontSize: 15,
      onTap: busy ? null : onPressed,
    );
  }
}

class JourneyTotalBar extends StatelessWidget {
  final int total;
  final VoidCallback? onSave;
  final VoidCallback? onUse;
  final String? useLabel;
  final bool busy;

  const JourneyTotalBar({
    super.key,
    required this.total,
    this.onSave,
    this.onUse,
    this.useLabel,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.coral;
    return JourneyDock3D(
      children: [
        Row(children: [
          Expanded(
            child: Text(
              TaxiWaysStrings.listedFares,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.35),
            ),
          ),
          const SizedBox(width: 12),
          Text(BrowseItem.inr(total), style: Ink3D.text(26, FontWeight.w700, tone.text)),
        ]),
        const SizedBox(height: 12),
        if (onUse != null)
          JourneyPrimaryButton(label: useLabel ?? '', onPressed: onUse, busy: busy)
        else if (onSave != null)
          JourneyPrimaryButton(label: TaxiWaysStrings.saveJourney, onPressed: onSave, busy: busy),
        const JourneyPayLine(TaxiWaysStrings.payLine),
      ],
    );
  }
}
