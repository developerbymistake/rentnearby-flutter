import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_request.dart';

class TaxiSeatChips extends StatelessWidget {
  const TaxiSeatChips({super.key, required this.seats, required this.onChanged});

  final int seats;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < TaxiSeats.options.length; i++) ...[
          if (i > 0) Gap.h(10),
          Expanded(child: _chip(TaxiSeats.options[i])),
        ],
      ],
    );
  }

  Widget _chip(int value) {
    final tone = ListingTone.indigo;
    final selected = value == seats;
    return Tap3D(
      onTap: () => onChanged(value),
      selected: selected,
      label: TripStringsTaxiRequest.seatsLabel(value),
      child: Container(
        key: ValueKey('taxi_seat_$value'),
        alignment: Alignment.center,
        padding: DS.sym(h: 4, v: 12),
        decoration: BoxDecoration(
          gradient: selected ? tone.gradient : null,
          color: selected ? null : Colors.white,
          borderRadius: DS.circular(16),
          boxShadow: DS.shadows(selected ? Form3D.glow(tone, blur: 10) : Ink3D.softShadow),
        ),
        child: Text(
          TripStringsTaxiRequest.seatsLabel(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Ink3D.text(13, FontWeight.w700, selected ? DesignColors.textInverse : Ink3D.sub),
        ),
      ),
    );
  }
}
