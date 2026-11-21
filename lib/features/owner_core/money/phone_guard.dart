abstract final class PhoneGuard {
  static final RegExp _separators = RegExp(r'[\s\-.()\[\]]');
  static final RegExp _run = RegExp(r'\d{10,}');

  static bool hasPhone(String? text) {
    if (text == null || text.isEmpty) return false;
    return _run.hasMatch(text.replaceAll(_separators, ''));
  }
}
