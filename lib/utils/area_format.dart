class AreaFormat {
  AreaFormat._();

  static const int maxDecimals = 4;

  static String number(double v) {
    if (!v.isFinite) return '0';
    final s = v.toStringAsFixed(maxDecimals);
    if (!s.contains('.')) return s;
    final t = s.replaceAll(RegExp(r'0+$'), '');
    final out = t.endsWith('.') ? t.substring(0, t.length - 1) : t;
    return out == '-0' ? '0' : out;
  }

  static String label(double value, String unit) => '${number(value)} $unit'.trim();
}
