import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import 'taxi_switch.dart';

class TaxiSectionCard extends StatelessWidget {
  const TaxiSectionCard({
    super.key,
    required this.art,
    required this.title,
    required this.sub,
    required this.child,
    this.number,
    this.on = true,
    this.onChanged,
    this.switchKey,
    this.switchEnabled = true,
  });

  final String art;
  final String title;
  final String sub;
  final Widget child;
  final int? number;
  final bool on;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;
  final bool switchEnabled;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final open = on || onChanged == null;
    final radius = DS.br(TripCustomizeLook.addDayRadius);
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: radius,
        boxShadow: DS.shadows(TripLook.dayCardShadow),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(gradient: tone.gradient),
              constraints: BoxConstraints(minHeight: DS.s(76)),
              padding: DS.insets(l: 16, t: 14, r: 14, b: 14),
              child: Row(
                children: [
                  if (number != null) ...[
                    Container(
                      width: DS.s(28),
                      height: DS.s(28),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle),
                      child: Text('$number', style: Ink3D.text(12.5, FontWeight.w700, tone.g2, letterSpacing: 0)),
                    ),
                    Gap.h(12),
                  ],
                  Art3D(asset: art, size: 46, shadowBlur: 3, shadowOffset: const Offset(3, 4), shadowAlpha: 0.30),
                  Gap.h(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, DesignColors.textInverse, letterSpacing: 0)),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Ink3D.text(12.5, FontWeight.w400, DesignColors.textInverse, height: 1.4, letterSpacing: 0),
                        ),
                      ],
                    ),
                  ),
                  if (onChanged != null) ...[
                    Gap.h(12),
                    TaxiSwitch(
                      key: switchKey,
                      value: on,
                      onGradient: true,
                      semanticsLabel: title,
                      onChanged: switchEnabled ? onChanged : null,
                    ),
                  ],
                ],
              ),
            ),
            if (open) Padding(padding: DS.insets(l: 14, t: 6, r: 14, b: 18), child: child),
          ],
        ),
      ),
    );
  }
}
