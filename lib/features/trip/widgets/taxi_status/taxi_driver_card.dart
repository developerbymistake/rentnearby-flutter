import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_status.dart';

enum TaxiDriverMode { choose, selected, onHold }

class TaxiStars extends StatelessWidget {
  const TaxiStars({super.key, required this.filled, this.size = 14});

  final int filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(Icons.star_rounded, size: DS.s(size), color: i <= filled ? DesignColors.amber : DesignColors.chipBackground),
      ],
    );
  }
}

class TaxiDriverIdentity extends StatelessWidget {
  const TaxiDriverIdentity({super.key, required this.driver, this.showRating = true, this.trailing});

  final TaxiDriverCard driver;
  final bool showRating;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final avg = driver.ratingAverage;
    final vehicle = TripStringsTaxiStatus.vehicleLine(driver.vehicle, driver.seats);
    final rides = TripStringsTaxiStatus.rides(driver.ridesCompleted);
    return Row(
      children: [
        const Art3D(asset: ListingArt.profile, size: 48, shadowBlur: 4, shadowOffset: Offset(2, 3)),
        Gap.h(14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
              if (showRating && avg != null)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: DS.gh(4),
                  children: [
                    TaxiStars(filled: avg.round()),
                    Text.rich(
                      TextSpan(
                        text: avg.toStringAsFixed(1),
                        style: Ink3D.text(13, FontWeight.w700, Ink3D.title),
                        children: [TextSpan(text: ' · $rides', style: Ink3D.text(13, FontWeight.w400, Ink3D.copy))],
                      ),
                    ),
                  ],
                )
              else if (showRating && driver.ridesCompleted > 0)
                Text(rides, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy)),
              if (vehicle.isNotEmpty) Text(vehicle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy)),
            ],
          ),
        ),
        if (trailing != null) ...[Gap.h(8), trailing!],
      ],
    );
  }
}

class TaxiStateChip extends StatelessWidget {
  const TaxiStateChip({super.key, required this.label, this.muted = false, this.positive = false});

  final String label;
  final bool muted;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final bg = muted ? DesignColors.chipBackground : (positive ? DesignColors.successSoft : DesignColors.surfaceTint);
    final fg = muted ? DesignColors.textMuted : (positive ? DesignColors.success : DesignColors.primary);
    return Container(
      padding: DS.sym(h: 12, v: 6),
      decoration: BoxDecoration(color: bg, borderRadius: DS.circular(12)),
      child: Text(label, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, fg)),
    );
  }
}

const double _buttonFont = 14;

class TaxiDriverCardView extends StatelessWidget {
  const TaxiDriverCardView({
    super.key,
    required this.driver,
    required this.mode,
    required this.showSelect,
    required this.calling,
    required this.enabled,
    required this.onCall,
    required this.onSelect,
    required this.onNotAgreed,
  });

  final TaxiDriverCard driver;
  final TaxiDriverMode mode;
  final bool showSelect;
  final bool calling;
  final bool enabled;
  final VoidCallback? onCall;
  final VoidCallback onSelect;
  final VoidCallback onNotAgreed;

  @override
  Widget build(BuildContext context) {
    final hold = mode == TaxiDriverMode.onHold;
    final chosen = mode == TaxiDriverMode.selected;
    final chip = chosen
        ? const TaxiStateChip(label: TripStringsTaxiStatus.selected)
        : (hold
            ? const TaxiStateChip(label: TripStringsTaxiStatus.onHold, muted: true)
            : (calling ? const TaxiStateChip(label: TripStringsTaxiStatus.onCall) : null));
    final call = onCall == null
        ? null
        : WhitePillButton(
            key: ValueKey('driver_call_${driver.offerId}'),
            tone: ListingTone.indigo,
            label: TripStringsTaxiStatus.call,
            onTap: enabled ? onCall : null,
            height: 44,
            fontSize: _buttonFont,
          );
    return Opacity(
      opacity: hold ? 0.6 : 1,
      child: Container(
        key: ValueKey('driver_card_${driver.offerId}'),
        padding: DS.insets(l: 16, t: 16, r: 16, b: 14),
        decoration: BoxDecoration(
          color: hold ? DesignColors.surfaceAlt : DesignColors.surface,
          borderRadius: DS.br(CardRadius.hero),
          border: chosen ? Border.all(color: DesignColors.primary, width: DS.s(2)) : null,
          boxShadow: hold ? null : DS.shadows(Ink3D.softShadow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaxiDriverIdentity(driver: driver, trailing: chip),
            if (!hold && (call != null || showSelect)) ...[
              Gap.v(12),
              if (chosen)
                call!
              else
                Row(
                  children: [
                    Flexible(
                      flex: 3,
                      child: Tap3D(
                        tapKey: ValueKey('driver_not_agreed_${driver.offerId}'),
                        onTap: enabled ? onNotAgreed : null,
                        child: Padding(
                          padding: DS.sym(v: 10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              TripStringsTaxiStatus.notAgreed,
                              style: Ink3D.text(13, FontWeight.w700, Ink3D.grey).copyWith(decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Gap.h(8),
                    if (call != null) Expanded(flex: 4, child: call),
                    if (call != null && showSelect) Gap.h(8),
                    if (showSelect)
                      Expanded(
                        flex: 4,
                        child: GradientPillButton(
                          key: ValueKey('driver_select_${driver.offerId}'),
                          tone: ListingTone.indigo,
                          label: TripStringsTaxiStatus.select,
                          onTap: enabled ? onSelect : null,
                          height: 44,
                          fontSize: _buttonFont,
                        ),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
