import 'dart:math' as math;

import 'package:flutter/widgets.dart';

abstract final class BarMetrics {
  static const double barHeight = 72;
  static const double centreOverflow = 38;
  static const double boxHeight = barHeight + centreOverflow;
  static const double bodyGap = 16;

  static double bodyBottom(double bottomInset) =>
      barHeight + bottomInset + bodyGap;

  static double bodyBottomOf(BuildContext context) {
    final media = MediaQuery.of(context);
    final floor = bodyBottom(media.viewPadding.bottom);
    final fromScaffold = media.padding.bottom - centreOverflow + bodyGap;
    return math.max(floor, fromScaffold);
  }

  static double boxHeightFor(double bottomInset) =>
      boxHeight + bottomInset;
}
