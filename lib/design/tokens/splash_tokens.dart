import 'dart:math' as math;

import 'package:flutter/painting.dart';

abstract final class SplashInk {
  static const Color night = Color(0xFF1E1466);
  static const Color white = Color(0xFFFFFFFF);
  static const Color glowCore = Color(0xFF5C5EDD);
  static const Color glowMid = Color(0x54738AE6);
  static const Color glowEdge = Color(0x00738AE6);
  static const Color tagline = Color(0xFFE9ECFF);
  static const Color shimmer = Color(0xCCFFFFFF);
  static const Color shimmerClear = Color(0x00FFFFFF);
  static const Color textShadow = Color(0x660A0630);
}

abstract final class SplashTiming {
  static const int glowMs = 900;
  static const int wordDelayMs = 250;
  static const int wordMs = 700;
  static const int shimmerDelayMs = 950;
  static const int shimmerMs = 900;
  static const int tagDelayMs = 1250;
  static const int tagMs = 500;
  static const int introMs = 1900;
  static const int breatheMs = 4000;
  static const int reducedFadeMs = 200;
}

abstract final class SplashType {
  static double wordSize(double width) => (width * 0.178).clamp(52.0, 72.0);
  static double tagSize(double width) => (width * 0.061).clamp(18.0, 24.0);
  static double glowSize(double width) => math.min(width * 1.45, 600);
}
