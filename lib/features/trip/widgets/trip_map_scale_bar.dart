import 'dart:math' as math;

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../trip_strings_map_disc.dart';

class TripMapScaleBar extends StatelessWidget {
  final double? metersPerDp;

  const TripMapScaleBar({super.key, required this.metersPerDp});

  static double get maxWidth => DS.s(96);

  // Largest 1, 2 or 5 x 10^n metres whose bar fits in maxWidth.
  static ({int meters, double width})? pick(double? metersPerDp) {
    final mpd = metersPerDp;
    if (mpd == null || !mpd.isFinite || mpd <= 0) return null;
    final limit = maxWidth * mpd;
    if (limit < 1) return null;
    final exp = (math.log(limit) / math.ln10).floor();
    final base = math.pow(10, exp).toDouble();
    for (final f in const [5, 2, 1]) {
      final m = f * base;
      if (m <= limit) return (meters: m.round(), width: m / mpd);
    }
    return null;
  }

  static String label(int meters) =>
      meters < 1000 ? TripMapDiscStrings.scaleMeters(meters) : TripMapDiscStrings.scaleKm(meters / 1000);

  @override
  Widget build(BuildContext context) {
    final p = pick(metersPerDp);
    if (p == null) return const SizedBox.shrink();
    const line = BorderSide(color: FitnessAppTheme.darkText, width: 1.5);
    return IgnorePointer(
      child: Column(
        key: const ValueKey('disc-scale'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(right: DS.s(3)),
            child: Text(
              label(p.meters),
              maxLines: 1,
              style: Ink3D.text(10, FontWeight.w500, FitnessAppTheme.darkText).copyWith(
                shadows: const [Shadow(color: FitnessAppTheme.white, blurRadius: 2)],
              ),
            ),
          ),
          Container(
            width: p.width,
            height: DS.s(14),
            decoration: BoxDecoration(
              color: DesignColors.tint(FitnessAppTheme.white, Alpha.half),
              border: const Border(left: line, right: line, bottom: line),
            ),
          ),
        ],
      ),
    );
  }
}
