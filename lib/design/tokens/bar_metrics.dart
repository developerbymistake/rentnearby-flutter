import 'package:flutter/widgets.dart';

import 'overlay_insets.dart';

abstract final class BarMetrics {
  static const double barHeight = 78;
  static const double centreOverflow = 20;
  static const double boxHeight = barHeight + centreOverflow;
  static const double bodyGap = 16;

  static double bodyBottom(double bottomInset) =>
      boxHeight + bottomInset + bodyGap;

  static double bodyBottomOf(BuildContext context) => OverlayInsets.dock(context);

  static double boxHeightFor(double bottomInset) =>
      boxHeight + bottomInset;
}
