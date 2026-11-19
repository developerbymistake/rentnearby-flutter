import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_request.dart';
import 'taxi_request_look.dart';

class TaxiSeatChips extends StatelessWidget {
  const TaxiSeatChips({super.key, required this.seats, required this.onChanged, this.enabledFor});

  final int seats;
  final ValueChanged<int> onChanged;
  final bool Function(int seats)? enabledFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(14)),
      child: Row(
        children: [
          for (var i = 0; i < TaxiSeats.options.length; i++) ...[
            if (i > 0) Gap.h(10),
            Expanded(child: _chip(TaxiSeats.options[i])),
          ],
        ],
      ),
    );
  }

  Widget _chip(int value) {
    final tone = ListingTone.indigo;
    final on = enabledFor?.call(value) ?? true;
    final selected = value == seats && on;
    return Tap3D(
      onTap: on ? () => onChanged(value) : null,
      selected: selected,
      label: TripStringsTaxiRequest.seatsLabel(value),
      child: Opacity(
        opacity: on ? 1 : 0.55,
        child: Container(
          key: ValueKey('taxi_seat_$value'),
          alignment: Alignment.center,
          constraints: BoxConstraints(minHeight: DS.s(44)),
          padding: DS.sym(h: 4),
          decoration: BoxDecoration(
            gradient: selected ? tone.gradient : null,
            color: selected ? null : DesignColors.surface,
            borderRadius: DS.br(TaxiRequestLook.chipRadius),
            boxShadow: DS.shadows(selected ? TripCustomizeLook.softPill : TaxiRequestLook.chip),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              TripStringsTaxiRequest.seatsLabel(value),
              maxLines: 1,
              style: Ink3D.text(13, FontWeight.w700, selected ? DesignColors.textInverse : Ink3D.sub, letterSpacing: 0),
            ),
          ),
        ),
      ),
    );
  }
}
