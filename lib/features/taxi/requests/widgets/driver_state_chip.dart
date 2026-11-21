import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:flutter/material.dart';

/// Coral chip of the taxi driver screens (o_tx_14, o_tx_15, o_tx_37, o_tx_38).
class DriverStateChip extends StatelessWidget {
  const DriverStateChip({super.key, required this.label, this.muted = false, this.positive = false});

  final String label;
  final bool muted;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final coral = ListingPalette.coral;
    final bg = muted ? TaxiStatusLook.holdFill : (positive ? TaxiStatusLook.goodSoft : coral.tint);
    final fg = muted ? TaxiStatusLook.holdText : (positive ? DesignColors.goodInk : coral.text);
    return Container(
      padding: DS.sym(h: 10, v: 3),
      decoration: BoxDecoration(color: bg, borderRadius: DS.circular(10)),
      child: Text(label, maxLines: 1, style: Ink3D.text(11.5, FontWeight.w700, fg, height: 1.5, letterSpacing: 0)),
    );
  }
}
