import 'package:flutter/material.dart';

class ShadowSpec {
  final double alpha;
  final Offset offset;
  final double blur;
  const ShadowSpec(this.alpha, this.offset, this.blur);

  static const double defaultAlpha = 0.2;
  static const double defaultBlur = 10.0;
  static const Offset flatOffset = Offset(1.1, 1.1);

  ShadowSpec scaled(double factor) => ShadowSpec(alpha * factor, offset, blur);

  static const ShadowSpec elev1Spec = ShadowSpec(0.10, Offset(0.0, 2.0), 8.0);
  static const ShadowSpec elev2Spec = ShadowSpec(0.14, Offset(0.0, 4.0), 14.0);
  static const ShadowSpec elev3Spec = ShadowSpec(0.20, Offset(0.0, 8.0), 20.0);
  static const ShadowSpec glowSpec = ShadowSpec(0.35, Offset(0.0, 6.0), 16.0);

  static const ShadowSpec navLift = ShadowSpec(0.4, Offset(8.0, 16.0), 16.0);
  static const ShadowSpec navIdle = ShadowSpec(0.25, Offset(8.0, 16.0), 16.0);
  static const ShadowSpec chatMine = glowSpec;
  static const ShadowSpec chatTheirs = elev2Spec;
  static const ShadowSpec liftSmall = elev3Spec;
  static const ShadowSpec faint = elev1Spec;

  static const ShadowSpec topEdge = ShadowSpec(0.2, Offset(0.0, -2.0), 10.0);
  static const ShadowSpec ring = ShadowSpec(0.2, Offset(0.0, 0.0), 6.0);
  static const ShadowSpec ringStrong = ShadowSpec(0.25, Offset(0.0, 0.0), 8.0);
  static const ShadowSpec badge = ShadowSpec(0.25, Offset(1.1, 2.0), 6.0);
  static const ShadowSpec topBar = ShadowSpec(0.2, Offset(0.0, -2.0), 8.0);
  static const ShadowSpec restTight = elev2Spec;
  static const ShadowSpec rest = elev2Spec;
  static const ShadowSpec topRaised = ShadowSpec(0.2, Offset(1.1, -4.0), 10.0);
  static const ShadowSpec soft = elev2Spec;
  static const ShadowSpec strong = elev3Spec;
  static const ShadowSpec glow = glowSpec;
  static const ShadowSpec lift = elev3Spec;
  static const ShadowSpec glowMid = glowSpec;
  static const ShadowSpec glowStrong = glowSpec;
}

class ShadowTokens {
  ShadowTokens._();

  static const List<BoxShadow> elev1 = [
    BoxShadow(color: Color(0x1A3A5160), offset: Offset(0, 2), blurRadius: 8),
  ];
  static const List<BoxShadow> elev2 = [
    BoxShadow(color: Color(0x243A5160), offset: Offset(0, 4), blurRadius: 14),
  ];
  static const List<BoxShadow> elev3 = [
    BoxShadow(color: Color(0x333A5160), offset: Offset(0, 8), blurRadius: 20),
  ];

  static const List<BoxShadow> elev3Up = [
    BoxShadow(color: Color(0x333A5160), offset: Offset(0, -8), blurRadius: 20),
  ];

  static List<BoxShadow> glow(Color color) => [tint(color, ShadowSpec.glowSpec)];

  static BoxShadow tint(Color color, ShadowSpec spec) => BoxShadow(color: color.withValues(alpha: spec.alpha), offset: spec.offset, blurRadius: spec.blur);
}
