import 'package:flutter/material.dart';

abstract final class HubTokens {
  static const Color ink = Color(0xFF17262A);
  static const Color sub = Color(0xFF4A6572);
  static const Color grey = Color(0xFF767676);
  static const Color accent = Color(0xFF5C5EDD);
  static const Color accentLight = Color(0xFF738AE6);
  static const Color blue = Color(0xFF2633C5);
  static const Color heading = Color(0xFF1B2A8A);
  static const Color headingSub = Color(0xFF2F3FA0);
  static const Color trackRing = Color(0xFFE6E9F7);
  static const Color trackBar = Color(0xFFE9ECF6);
  static const Color chipBg = Color(0xFFEEF0FC);
  static const Color line = Color(0xFFEEF0F4);
  static const Color dotOff = Color(0xFFB7C3F2);
  static const Color statusStrip = Color(0xFFEEF1FD);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x303A5160), offset: Offset(1.1, 1.6), blurRadius: 12),
  ];

  static BorderRadius cardRadius(double corner) => BorderRadius.only(
        topLeft: const Radius.circular(8),
        topRight: Radius.circular(corner),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      );

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFEEF1FD),
      Color(0xFFEEF1FD),
      Color(0xFFCBD5FB),
      Color(0xFFAEBBF2),
      Color(0xFFC3CEF8),
      Color(0xFFE6EAFC),
      Color(0xFFF2F3F8),
    ],
    stops: [0.0, 0.22, 0.40, 0.56, 0.74, 0.90, 1.0],
  );
}
