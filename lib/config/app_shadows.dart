import 'package:flutter/material.dart';

abstract final class AppShadows {
  static List<BoxShadow> premium(
    Color tint, {
    double alpha = 0.12,
    double blur = 16,
    Offset offset = const Offset(0, 6),
  }) => [BoxShadow(color: tint.withValues(alpha: alpha), blurRadius: blur, offset: offset)];
}
