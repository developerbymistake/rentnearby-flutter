enum MoneyChip { none, toCollect, paidInFull, received }

enum MoneyNoteError { amountRange, receivedAboveFinal, finalNeeded }

class MoneyNote {
  const MoneyNote({this.finalAmount, this.receivedSoFar, this.paidInFull = false});

  final int? finalAmount;
  final int? receivedSoFar;
  final bool paidInFull;
}

abstract final class MoneyNoteMath {
  static const int finalMin = 1;
  static const int receivedMin = 0;
  static const int max = 9900000;

  static int received(MoneyNote n) => n.paidInFull ? (n.finalAmount ?? 0) : (n.receivedSoFar ?? 0);

  static int? balance(MoneyNote n) {
    final f = n.finalAmount;
    if (f == null) return null;
    final b = f - received(n);
    return b < 0 ? 0 : b;
  }

  static MoneyChip chip(MoneyNote n) {
    final b = balance(n);
    if (b != null) return b > 0 ? MoneyChip.toCollect : MoneyChip.paidInFull;
    return received(n) > 0 ? MoneyChip.received : MoneyChip.none;
  }

  static int chipAmount(MoneyNote n) => switch (chip(n)) {
        MoneyChip.toCollect => balance(n) ?? 0,
        MoneyChip.received => received(n),
        MoneyChip.paidInFull => n.finalAmount ?? 0,
        MoneyChip.none => 0,
      };

  static MoneyNoteError? validate(MoneyNote n) {
    final f = n.finalAmount;
    final a = n.receivedSoFar;
    if (f != null && (f < finalMin || f > max)) return MoneyNoteError.amountRange;
    if (a != null && (a < receivedMin || a > max)) return MoneyNoteError.amountRange;
    if (n.paidInFull && f == null) return MoneyNoteError.finalNeeded;
    if (f != null && a != null && a > f) return MoneyNoteError.receivedAboveFinal;
    return null;
  }

  static const Map<String, MoneyChip> chipWire = {
    'None': MoneyChip.none,
    'ToCollect': MoneyChip.toCollect,
    'PaidInFull': MoneyChip.paidInFull,
    'Received': MoneyChip.received,
  };
}
