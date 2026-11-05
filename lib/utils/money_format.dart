class Money {
  Money._();

  static const String symbol = '₹';

  static const List<(int, String, int)> _units = [
    (10000000, 'Cr', 2),
    (100000, 'L', 2),
    (1000, 'k', 1),
  ];

  static String group(int n) {
    if (n < 0) return '-${group(-n)}';
    final s = n.toString();
    if (s.length <= 3) return s;
    final head = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    final lead = head.length.isOdd ? 1 : 0;
    if (lead == 1) buf.write(head[0]);
    for (var i = lead; i < head.length; i += 2) {
      if (buf.isNotEmpty) buf.write(',');
      buf.write(head.substring(i, i + 2));
    }
    return '$buf,${s.substring(s.length - 3)}';
  }

  static String exact(num v) {
    final n = v.round();
    return n < 0 ? '-$symbol${group(-n)}' : '$symbol${group(n)}';
  }

  // Lossless unit form ('12k', '1.5L', '2.25Cr'), null when the unit would round the amount.
  static String? unitBody(int n) {
    final a = n.abs();
    for (final (size, suffix, decimals) in _units) {
      if (a < size || (suffix == 'k' && a >= 100000)) continue;
      final scale = decimals == 2 ? 100 : 10;
      if ((a * scale) % size != 0) continue;
      final q = a * scale ~/ size;
      final frac = (q % scale).toString().padLeft(decimals, '0').replaceAll(RegExp(r'0+$'), '');
      final body = '${q ~/ scale}${frac.isEmpty ? '' : '.$frac'}$suffix';
      return n < 0 ? '-$body' : body;
    }
    return null;
  }

  static String body(int n) => unitBody(n) ?? group(n);

  static String short(num v) {
    final n = v.round();
    final b = body(n.abs());
    return n < 0 ? '-$symbol$b' : '$symbol$b';
  }

  static String shortRange(int min, int max) {
    final a = unitBody(min), b = unitBody(max);
    if (a != null && b != null) {
      final ua = a.replaceAll(RegExp(r'[0-9.\-]'), '');
      final ub = b.replaceAll(RegExp(r'[0-9.\-]'), '');
      if (ua == ub) return '$symbol${a.substring(0, a.length - ua.length)}-$b';
    }
    return '$symbol${body(min)} - ${body(max)}';
  }
}
