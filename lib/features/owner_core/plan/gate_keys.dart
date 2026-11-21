import 'package:flutter/widgets.dart';

class GateKey extends ValueKey<String> {
  const GateKey(super.value);
}

abstract final class GateKeys {
  static const sheet = GateKey('gate_sheet');
  static const softRow = GateKey('gate_soft_row');
  static const softCard = GateKey('gate_soft_card');
  static const softArrow = GateKey('gate_soft_arrow');
  static const plusChip = GateKey('gate_plus_chip');
  static const seePlus = GateKey('gate_see_plus');
  static GateKey of(String id) => GateKey('gate_$id');
}
