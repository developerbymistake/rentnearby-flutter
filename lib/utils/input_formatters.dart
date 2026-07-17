import 'package:flutter/services.dart';

/// Denies emoji and other pictographic/symbol characters — used on any
/// free-text search field where matching against real place/city names is
/// the only valid input; emoji can never match and are easy to trigger by
/// accident via the emoji keyboard.
final List<TextInputFormatter> noEmojiInputFormatters = [
  FilteringTextInputFormatter.deny(
    RegExp(
      '[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}'
      '\u{1F680}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}'
      '\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
      unicode: true,
    ),
  ),
];

/// Redeem codes are uppercase alphanumeric with no spaces or symbols — used
/// on the Redeem Code screen's single text field. Denies anything but
/// letters/digits, then force-uppercases (Flutter has no built-in
/// case-transforming formatter, so this is hand-rolled like the digit-only
/// formatters used on phone/OTP fields).
final List<TextInputFormatter> redeemCodeInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
  _UppercaseTextFormatter(),
];

class _UppercaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
