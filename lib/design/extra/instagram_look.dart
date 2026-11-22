import 'package:flutter/painting.dart';

import '../tokens/alpha_tokens.dart';
import 'art_3d.dart';

abstract final class InstagramLook {
  static const Color orange = Color(0xFFF9A03F);
  static const Color red = Color(0xFFE9593F);
  static const Color magenta = Color(0xFFD62976);
  static const Color purple = Color(0xFF962FBF);
  static const Color blue = Color(0xFF4F5BD5);

  static const List<Color> colors = [orange, red, magenta, purple, blue];
  static const List<double> stops = [0, 0.28, 0.58, 0.82, 1];

  static const LinearGradient gradient = LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: colors, stops: stops);

  static final ListingTone tone = ListingTone(
    g1: orange,
    g2: blue,
    shadow: magenta.withValues(alpha: Alpha.v40),
    haloBase: magenta,
    text: magenta,
    button: magenta,
  );
}
