import '../../../../utils/money_format.dart';

class QuoteTotals {
  const QuoteTotals({
    required this.subtotal,
    required this.discount,
    required this.taxable,
    required this.gstBp,
    required this.gstPaise,
    required this.roundOffPaise,
    required this.total,
    required this.received,
    required this.balance,
  });

  final int subtotal;
  final int discount;
  final int taxable;
  final int gstBp;
  final int gstPaise;
  final int roundOffPaise;
  final int total;
  final int received;
  final int balance;

  bool get hasGst => gstBp > 0;
  bool get tooLarge => total > QuoteMoney.maxTotal;
}

abstract final class QuoteMoney {
  static const int maxRate = 9999999;
  static const int maxTotal = 9999999999;
  static const int maxGstBp = 2800;

  static int line(int rate, int qty, int nights) => rate * qty * nights;

  static int roundHalfUpDiv(int numerator, int denominator) {
    if (numerator >= 0) return (numerator * 2 + denominator) ~/ (denominator * 2);
    return -roundHalfUpDiv(-numerator, denominator);
  }

  // GST % text with up to 2 decimals ("5", "12.5", "18.00") to basis points; null when not a number in 0-28.
  static int? parseBp(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    final m = RegExp(r'^(\d{1,2})(?:\.(\d{1,2}))?$').firstMatch(t);
    if (m == null) return null;
    final whole = int.parse(m.group(1)!);
    final frac = (m.group(2) ?? '').padRight(2, '0');
    final bp = whole * 100 + int.parse(frac);
    return bp > maxGstBp ? null : bp;
  }

  static String bpText(int bp) {
    final whole = bp ~/ 100;
    final frac = bp % 100;
    if (frac == 0) return '$whole';
    final f = frac.toString().padLeft(2, '0');
    return '$whole.${f.endsWith('0') ? f.substring(0, 1) : f}';
  }

  static QuoteTotals compute({
    required Iterable<int> lineAmounts,
    int discount = 0,
    int gstBp = 0,
    bool gstAllowed = false,
    Iterable<int> payments = const [],
  }) {
    final subtotal = lineAmounts.fold<int>(0, (a, b) => a + b);
    final d = discount < 0 ? 0 : (discount > subtotal ? subtotal : discount);
    final taxable = subtotal - d;
    final bp = gstAllowed && gstBp > 0 ? gstBp : 0;
    final gstPaise = bp == 0 ? 0 : roundHalfUpDiv(taxable * bp, 100);
    final rawPaise = taxable * 100 + gstPaise;
    final total = roundHalfUpDiv(rawPaise, 100);
    final roundOff = total * 100 - rawPaise;
    final received = payments.fold<int>(0, (a, b) => a + b);
    return QuoteTotals(
      subtotal: subtotal,
      discount: d,
      taxable: taxable,
      gstBp: bp,
      gstPaise: gstPaise,
      roundOffPaise: roundOff,
      total: total,
      received: received,
      balance: total - received,
    );
  }

  static String group(int rupees) => Money.group(rupees);

  static String inr(int rupees) => '${Money.symbol}${Money.group(rupees)}';

  static String paise(int paise) {
    final neg = paise < 0;
    final a = paise.abs();
    final s = '${Money.group(a ~/ 100)}.${(a % 100).toString().padLeft(2, '0')}';
    return neg ? '-$s' : s;
  }

  static String signedPaise(int paise) => paise > 0 ? '+${QuoteMoney.paise(paise)}' : QuoteMoney.paise(paise);
}
