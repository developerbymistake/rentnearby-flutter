import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../../models/browse_item.dart';
import '../taxi_ways_strings.dart';

class JourneyAskButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const JourneyAskButton({super.key, required this.label, required this.onPressed, this.busy = false});

  static String labelFor(int drivers, {bool these = false}) {
    if (drivers <= 1) return TaxiWaysStrings.askOne;
    if (these) return TaxiWaysStrings.askThese(drivers);
    return drivers == 2 ? TaxiWaysStrings.askBoth : TaxiWaysStrings.askAll(drivers);
  }

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
  final String askLabel;
  final VoidCallback? onAsk;
  final VoidCallback? onSave;
  final VoidCallback? onUse;
  final String? useLabel;
  final bool busy;

  const JourneyTotalBar({
    super.key,
    required this.total,
    required this.askLabel,
    required this.onAsk,
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
        if (onUse != null) ...[
          JourneyAskButton(label: useLabel ?? '', onPressed: onUse, busy: busy),
          const SizedBox(height: 10),
          WhitePillButton(tone: tone, label: askLabel, height: 52, fontSize: 15, onTap: busy ? null : onAsk),
        ] else
          Row(children: [
            if (onSave != null) ...[
              JourneyRoundButton3D(art: ListingArt.clipboard, tooltip: TaxiWaysStrings.saveJourney, onTap: busy ? null : onSave),
              const SizedBox(width: 12),
            ],
            Expanded(child: JourneyAskButton(label: askLabel, onPressed: onAsk, busy: busy)),
          ]),
        const JourneyPayLine(TaxiWaysStrings.payLine),
      ],
    );
  }
}
