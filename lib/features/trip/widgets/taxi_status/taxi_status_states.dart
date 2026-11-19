import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_status.dart';
import 'taxi_driver_card.dart';

class TaxiStatusHero extends StatelessWidget {
  const TaxiStatusHero({
    super.key,
    required this.art,
    required this.title,
    this.line,
    this.titleSize = 24,
    this.artSize = 84,
    this.topGap = 0,
    this.titleHeight,
  });

  final String art;
  final String title;
  final String? line;
  final double titleSize;
  final double artSize;
  final double topGap;
  final double? titleHeight;

  @override
  Widget build(BuildContext context) {
    final sub = line;
    return Padding(
      padding: DS.sym(h: 6),
      child: Column(
      children: [
        if (topGap > 0) Gap.v(topGap),
        Art3D(asset: art, size: artSize, shadowBlur: 7, shadowOffset: const Offset(6, 9)),
        Gap.v(10),
        Text(title, textAlign: TextAlign.center, style: Ink3D.text(titleSize, FontWeight.w700, Ink3D.title, height: titleHeight, letterSpacing: 0)),
        if (sub != null && sub.isNotEmpty) ...[
          Gap.v(4),
          Text(sub, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, TripLook.mutedText, height: 1.5, letterSpacing: 0)),
        ],
      ],
      ),
    );
  }
}

class TaxiStatusCard extends StatelessWidget {
  const TaxiStatusCard({super.key, this.cardKey, required this.children, this.padding, this.radius = CardRadius.hero});

  final Key? cardKey;
  final List<Widget> children;
  final EdgeInsets? padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      padding: padding ?? DS.all(16),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(radius), boxShadow: DS.shadows(TripLook.cardShadowSoft)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class TaxiDangerOutline extends StatelessWidget {
  const TaxiDangerOutline({super.key, required this.label, required this.onTap, this.buttonKey});

  final String label;
  final VoidCallback? onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final height = DS.s(44);
    final body = Container(
      height: height,
      alignment: Alignment.center,
      padding: DS.sym(h: 12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: DesignColors.dangerLine, width: DS.s(1.5)),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: Ink3D.text(13, FontWeight.w700, TripLook.badText, letterSpacing: 0))),
    );
    return Tap3D(tapKey: buttonKey, onTap: onTap, child: onTap == null ? Opacity(opacity: 0.45, child: body) : body);
  }
}

class TaxiProgressBar extends StatelessWidget {
  const TaxiProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DS.circular(4),
      child: Container(
        height: DS.s(8),
        color: TaxiStatusLook.holdFill,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(decoration: BoxDecoration(gradient: ListingTone.indigo.gradient, borderRadius: DS.circular(4))),
        ),
      ),
    );
  }
}

const double _buttonFont = 13;

class TaxiBookedCard extends StatelessWidget {
  const TaxiBookedCard({
    super.key,
    required this.request,
    required this.driver,
    required this.enabled,
    required this.onCall,
    required this.onCancel,
    required this.onEnd,
  });

  final TaxiRequest request;
  final TaxiDriverCard? driver;
  final bool enabled;
  final VoidCallback? onCall;
  final VoidCallback onCancel;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final b = request.booking;
    final progress = request.view == RequestView.inProgress;
    final day = b?.dayNumber;
    final total = request.dayCount;
    final canAct = progress ? (b?.canEnd ?? false) : (b?.canCancel ?? request.canCancel);
    final bar = progress && day != null && total > 0;
    final call = onCall == null
        ? null
        : WhitePillButton(key: const ValueKey('booked_call'), tone: ListingTone.indigo, label: TripStringsTaxiStatus.call, onTap: enabled ? onCall : null, height: 44, fontSize: _buttonFont);
    final act = canAct
        ? TaxiDangerOutline(
            buttonKey: ValueKey(progress ? 'end_trip' : 'cancel_booking'),
            label: progress ? TripStringsTaxiStatus.endTrip : TripStringsTaxiStatus.cancelBooking,
            onTap: enabled ? (progress ? onEnd : onCancel) : null,
          )
        : null;
    return TaxiStatusCard(
      cardKey: ValueKey(progress ? 'taxi_in_progress_card' : 'taxi_booked_card'),
      padding: DS.all(18),
      radius: TripCustomizeLook.addDayRadius,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: DS.gh(12),
          runSpacing: DS.gv(6),
          children: [
            TaxiStateChip(label: progress ? TripStringsTaxiStatus.inProgress : TripStringsTaxiStatus.booked, positive: true),
            Text(
              progress && day != null ? TripStringsTaxiStatus.dayOf(day, total) : TripStringsTaxiStatus.dates(b?.from ?? request.from, b?.to ?? request.to),
              style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0),
            ),
          ],
        ),
        if (bar) ...[
          Gap.v(14),
          TaxiProgressBar(value: day / total),
        ],
        if (driver != null) ...[
          Gap.v(bar ? 14 : 12),
          TaxiDriverIdentity(driver: driver!, showRating: !progress),
        ],
        if (act != null || call != null) ...[
          Gap.v(14),
          Row(
            children: [
              if (act != null) Expanded(child: act),
              if (act != null && call != null) Gap.h(10),
              if (call != null) Expanded(child: call),
            ],
          ),
        ],
      ],
    );
  }
}

class TaxiBottomBar extends StatelessWidget {
  const TaxiBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(TripCustomizeLook.barRadius),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(12), DS.s(16), DS.s(16) + MediaQuery.paddingOf(context).bottom),
        child: children.length == 2
            ? LayoutBuilder(
                builder: (_, c) => Row(
                  children: [
                    // The mock's coloured pill keeps its 16px side padding on top of the flex share.
                    SizedBox(width: (c.maxWidth - DS.gh(14) - DS.s(32)) / 2, child: children[0]),
                    Gap.h(14),
                    Expanded(child: children[1]),
                  ],
                ),
              )
            : Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Gap.h(14),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
      ),
    );
  }
}
