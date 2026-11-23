import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_dated_price.dart';
import '../../trip_strings_taxi_status.dart';

enum TaxiDriverMode { choose, selected, onHold }

class TaxiStars extends StatelessWidget {
  const TaxiStars({super.key, required this.filled, this.size = 14, this.gap = 2});

  final int filled;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) Gap.h(gap),
          Icon(Icons.star, size: DS.s(size), color: i <= filled ? TaxiStatusLook.star : TaxiStatusLook.holdFill),
        ],
      ],
    );
  }
}

class TaxiDriverIdentity extends StatelessWidget {
  const TaxiDriverIdentity({super.key, required this.driver, this.showRating = true, this.trailing, this.centered = false});

  final TaxiDriverCard driver;
  final bool showRating;
  final Widget? trailing;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final avg = driver.ratingAverage;
    final vehicle = TripStringsTaxiStatus.vehicleLine(driver.vehicle, driver.seats);
    final rides = TripStringsTaxiStatus.rides(driver.ridesCompleted);
    final line = Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, height: 1.5, letterSpacing: 0);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(driver.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
        if (driver.isFeatured)
          Padding(
            padding: DS.insets(t: 4, b: 2),
            child: const TaxiStateChip(key: ValueKey('driver_featured'), label: TripStringsDatedPrice.featured, positive: true),
          ),
        if (showRating && avg != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: DS.gh(4),
            children: [
              TaxiStars(filled: avg.round()),
              Text.rich(
                TextSpan(
                  text: avg.toStringAsFixed(1),
                  style: line.copyWith(fontWeight: FontWeight.w700, color: Ink3D.title),
                  children: [TextSpan(text: ' · $rides', style: line)],
                ),
              ),
            ],
          )
        else if (showRating && driver.ridesCompleted > 0)
          Text(rides, style: line),
        if (vehicle.isNotEmpty) Text(vehicle, maxLines: 2, overflow: TextOverflow.ellipsis, style: line),
      ],
    );
    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        const Art3D(asset: ListingArt.panda, size: 48, shadowAlpha: 0),
        Gap.h(14),
        if (centered) Flexible(child: text) else Expanded(child: text),
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
    final bg = muted ? TaxiStatusLook.holdFill : (positive ? TaxiStatusLook.goodSoft : ListingPalette.indigo.tint);
    final fg = muted ? TaxiStatusLook.holdText : (positive ? DesignColors.goodInk : DesignColors.primary);
    return Container(
      padding: DS.sym(h: 12, v: 4),
      decoration: BoxDecoration(color: bg, borderRadius: DS.circular(10)),
      child: Text(label, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, fg, height: 1.5, letterSpacing: 0)),
    );
  }
}

class TaxiNotAgreedLink extends StatelessWidget {
  const TaxiNotAgreedLink({super.key, required this.label, required this.onTap, this.tapKey});

  final String label;
  final VoidCallback? onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      tapKey: tapKey,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(44)),
        child: Padding(
          padding: DS.sym(h: 6),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              style: Ink3D.text(12.5, FontWeight.w700, TripLook.mutedText, letterSpacing: 0).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ),
    );
  }
}

const double _buttonFont = 13;

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
      opacity: hold ? 0.7 : 1,
      child: Container(
        key: ValueKey('driver_card_${driver.offerId}'),
        padding: DS.all(16),
        decoration: BoxDecoration(
          color: hold ? TaxiStatusLook.dimCard : DesignColors.surface,
          borderRadius: DS.br(TripCustomizeLook.addDayRadius),
          border: Border.all(color: chosen ? DesignColors.lunchEnd : Colors.transparent, width: DS.s(2)),
          boxShadow: hold ? null : DS.shadows(TripLook.cardShadowSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaxiDriverIdentity(driver: driver, trailing: chip),
            if (!hold && (call != null || showSelect)) ...[
              Gap.v(14),
              if (chosen)
                call!
              else
                Row(
                  children: [
                    TaxiNotAgreedLink(
                      tapKey: ValueKey('driver_not_agreed_${driver.offerId}'),
                      label: TripStringsTaxiStatus.notAgreed,
                      onTap: enabled ? onNotAgreed : null,
                    ),
                    if (call != null) ...[Gap.h(10), Expanded(child: call)],
                    if (showSelect) ...[
                      Gap.h(10),
                      Expanded(
                        child: GradientPillButton(
                          key: ValueKey('driver_select_${driver.offerId}'),
                          tone: ListingTone.indigo,
                          label: TripStringsTaxiStatus.select,
                          onTap: enabled ? onSelect : null,
                          height: 44,
                          fontSize: _buttonFont,
                          shadows: TaxiStatusLook.actionGlow,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
