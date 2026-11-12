import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/extra/ways_kit.dart';
import '../../../../config/app_insets.dart';
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
    return PickButton(
      label: label,
      isLoading: busy,
      onPressed: busy ? null : onPressed,
      height: 48,
      gradient: PickKit.taxiGradient,
      shadowColor: PickKit.taxi,
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
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 10 + AppInsets.bottomViewPadding(context)),
      decoration: const BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        boxShadow: WaysKit.topShadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              TaxiWaysStrings.listedFares,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FitnessAppTheme.caption.copyWith(fontSize: 11.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            BrowseItem.inr(total),
            style: FitnessAppTheme.headline.copyWith(fontSize: 20, color: DesignColors.primary),
          ),
        ]),
        const SizedBox(height: 10),
        if (onUse != null) ...[
          JourneyAskButton(label: useLabel ?? '', onPressed: onUse, busy: busy),
          const SizedBox(height: 8),
          SecondaryButton(label: askLabel, onPressed: busy ? null : onAsk, tone: KitTone.taxi, height: 48),
        ] else
          Row(children: [
            if (onSave != null) ...[
              Tooltip(
                message: TaxiWaysStrings.saveJourney,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: TripLook.card(radius: BorderRadius.circular(24)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: busy ? null : onSave,
                      child: Center(
                        child: Opacity(
                            opacity: busy ? Alpha.half : Alpha.full,
                            child: const TravelIcon(TravelIcon.note, size: 26)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: JourneyAskButton(label: askLabel, onPressed: onAsk, busy: busy)),
          ]),
        const SizedBox(height: 8),
        Text(
          TaxiWaysStrings.payLine,
          textAlign: TextAlign.center,
          style: FitnessAppTheme.caption.copyWith(fontSize: 11),
        ),
      ]),
    );
  }
}
