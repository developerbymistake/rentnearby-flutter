abstract final class PhoneGuard {
  static final RegExp _separators = RegExp(r'[\s\-.()\[\]/+_]');
  static final RegExp _run = RegExp(r'\p{Nd}{10,}', unicode: true);

  static bool hasPhone(String? text) {
    if (text == null || text.isEmpty) return false;
    return _run.hasMatch(text.replaceAll(_separators, ''));
  }
}
