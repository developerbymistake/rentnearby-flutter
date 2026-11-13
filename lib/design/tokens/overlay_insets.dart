import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'bar_metrics.dart';

abstract final class OverlayInsets {
  static const double pillHeight = 56;
  static const double pillGap = 12;

  static double dock(BuildContext context) {
    final media = MediaQuery.of(context);
    final floor = BarMetrics.bodyBottom(media.viewPadding.bottom);
    return math.max(floor, media.padding.bottom + BarMetrics.bodyGap);
  }

  static double pillBottom(BuildContext context) => dock(context);

  static double list(BuildContext context, {bool pill = false}) =>
      dock(context) + (pill ? pillHeight + pillGap : 0);

  static Widget sliver(BuildContext context, {bool pill = false}) =>
      SliverToBoxAdapter(child: SizedBox(height: list(context, pill: pill)));
}
