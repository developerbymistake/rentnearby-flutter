import 'package:flutter/widgets.dart';

abstract final class CardRadius {
  static const double heroNotch = 54;
  static const double tileNotch = 24;
  static const double corner = 8;
  static const double chipValue = 8;
  static const double sheetValue = 28;
  static const double headerValue = 32;

  static const BorderRadius hero = BorderRadius.only(
    topLeft: Radius.circular(corner),
    topRight: Radius.circular(heroNotch),
    bottomLeft: Radius.circular(corner),
    bottomRight: Radius.circular(corner),
  );

  static const BorderRadius heroTop = BorderRadius.only(
    topLeft: Radius.circular(corner),
    topRight: Radius.circular(heroNotch),
  );

  static const BorderRadius tile = BorderRadius.only(
    topLeft: Radius.circular(corner),
    topRight: Radius.circular(tileNotch),
    bottomLeft: Radius.circular(corner),
    bottomRight: Radius.circular(corner),
  );

  static const BorderRadius chip = BorderRadius.all(Radius.circular(chipValue));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static const BorderRadius sheet = BorderRadius.only(
    topLeft: Radius.circular(sheetValue),
    topRight: Radius.circular(sheetValue),
  );

  static const BorderRadius header = BorderRadius.only(
    bottomLeft: Radius.circular(headerValue),
  );
}
