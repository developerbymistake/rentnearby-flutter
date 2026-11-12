import 'package:flutter/material.dart';
import 'shadow_tokens.dart';

class DesignShadows {
  DesignShadows._();

  static const List<BoxShadow> card = ShadowTokens.elev2;
  static const List<BoxShadow> tile = ShadowTokens.elev3;
  static const List<BoxShadow> breakfast = [
    BoxShadow(color: Color(0x59FFB295), offset: Offset(0, 6), blurRadius: 16.0),
  ];
  static const List<BoxShadow> lunch = [
    BoxShadow(color: Color(0x595C5EDD), offset: Offset(0, 6), blurRadius: 16.0),
  ];
  static const List<BoxShadow> dinner = [
    BoxShadow(color: Color(0x591E1466), offset: Offset(0, 6), blurRadius: 16.0),
  ];
  static const List<BoxShadow> hotel = [
    BoxShadow(color: Color(0x592FB5A4), offset: Offset(0, 6), blurRadius: 16.0),
  ];
  static const List<BoxShadow> brand = [
    BoxShadow(color: Color(0x592633C5), offset: Offset(0, 6), blurRadius: 16.0),
  ];
  static const List<BoxShadow> top = [
    BoxShadow(color: Color(0x1A3A5160), offset: Offset(0, -2.0), blurRadius: 10.0),
  ];
}
