import 'package:flutter/material.dart';

import '../../../../design/tokens/card_tokens.dart';

class TaxiRequestLook {
  TaxiRequestLook._();

  static const List<BoxShadow> field = <BoxShadow>[BoxShadow(color: Color(0x29000000), offset: Offset(0, 3), blurRadius: 10)];
  static const List<BoxShadow> list = <BoxShadow>[BoxShadow(color: Color(0x4D3A5160), offset: Offset(1.1, 4), blurRadius: 14)];
  static const List<BoxShadow> dayRow = <BoxShadow>[BoxShadow(color: Color(0x333A5160), offset: Offset(1.1, 1.1), blurRadius: 8)];
  static const List<BoxShadow> chip = <BoxShadow>[BoxShadow(color: Color(0x29000000), offset: Offset(0, 2), blurRadius: 8)];
  static const List<BoxShadow> thumb = <BoxShadow>[BoxShadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 4)];
  static const List<BoxShadow> whitePill = <BoxShadow>[BoxShadow(color: Color(0x33000000), offset: Offset(3, 4), blurRadius: 8)];

  static const BorderRadius chipRadius = CardRadius.card;
}
