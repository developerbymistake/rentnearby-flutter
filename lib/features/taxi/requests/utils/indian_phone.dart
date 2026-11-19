class IndianPhone {
  static final RegExp _e164 = RegExp(r'^\+91(\d{5})(\d{5})$');

  static String display(String raw) {
    final m = _e164.firstMatch(raw.replaceAll(' ', ''));
    return m == null ? raw : '+91 ${m[1]} ${m[2]}';
  }
}
