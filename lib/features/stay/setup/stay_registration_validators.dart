import 'package:flutter/services.dart';
import '../../../utils/input_formatters.dart';

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

// Mirrors RentNearBy.Core/Models/StayRegistrationRules.cs.
class StayRegistrationValidators {
  static const String otherCode = 'OTHER';
  static const String udyamCode = 'UDYAM';

  static const int registrationMin = 5;
  static const int registrationMax = 25;
  static const int otherNameMin = 3;
  static const int otherNameMax = 40;

  static const String gstinInvalidMessage = 'Enter a valid GSTIN';
  static const String gstinHelp = '15 characters, e.g. 05ABCDE1234F1Z6';
  static const String registrationInvalidMessage = 'Enter a valid registration number';
  static const String registrationHelp = '5 to 25 letters, digits, / or -';
  static const String udyamInvalidMessage = 'Enter a valid Udyam number, e.g. UDYAM-UK-05-0001234';
  static const String otherNameEmptyMessage = 'Enter the document name';
  static const String otherNameInvalidMessage = 'Document name must be 3 to 40 characters';
  static const String typeRequiredMessage = 'Pick a registration type';
  static const String numberRequiredMessage = 'Enter your registration number';
  static const String typeInvalidMessage = 'Pick a valid registration type';
  static const String typesNotLoadedMessage = 'Registration types did not load. Tap to retry.';
  static const String typesLoadingMessage = 'Loading registration types. Try again in a moment.';
  static const String savedHelp = 'Saved. Leave empty to keep it.';

  static const typeServerMessages = {typeRequiredMessage, typeInvalidMessage};
  static const otherNameServerMessages = {otherNameEmptyMessage, otherNameInvalidMessage};
  static const numberServerMessages = {numberRequiredMessage, registrationInvalidMessage, udyamInvalidMessage};
  static const gstinServerMessages = {gstinInvalidMessage};

  static const List<String> stateCodes = [
    'AN', 'AP', 'AR', 'AS', 'BR', 'CG', 'CH', 'DD', 'DL', 'GA', 'GJ', 'HP',
    'HR', 'JH', 'JK', 'KA', 'KL', 'LA', 'LD', 'MH', 'ML', 'MN', 'MP', 'MZ',
    'NL', 'OD', 'PB', 'PY', 'RJ', 'SK', 'TN', 'TR', 'TS', 'UK', 'UP', 'WB',
    'UA', 'OR', 'DN', 'TG',
  ];

  static const String _alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static final RegExp _gstinPattern = RegExp(r'^([0-9]{2})([A-Z]{5}[0-9]{4}[A-Z])([1-9A-Z])(Z)([0-9A-Z])$');
  static final RegExp _registrationPattern = RegExp(r'^[A-Z0-9/-]{5,25}$');
  static final RegExp _udyamInputPattern = RegExp(r'^UDYAM-?([A-Z]{2})-?([0-9]{2})-?([0-9]{7})$');
  static final RegExp _udyamCanonicalPattern = RegExp(r'^UDYAM-([A-Z]{2})-([0-9]{2})-([0-9]{7})$');
  static final RegExp _otherNamePattern = RegExp(r"^[A-Za-z0-9 &/.'()-]{3,40}$");
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _digit = RegExp(r'[0-9]');

  static String normalizeGstin(String? raw) => (raw ?? '').trim().toUpperCase().replaceAll(_whitespace, '');

  static String gstinCheckChar(String first14) {
    var sum = 0;
    for (var i = 0; i < first14.length; i++) {
      final v = _alphabet.indexOf(first14[i]);
      if (v < 0) return '';
      final p = v * (i.isEven ? 1 : 2);
      sum += p ~/ 36 + p % 36;
    }
    return _alphabet[(36 - sum % 36) % 36];
  }

  static bool isValidGstin(String normalised) {
    final m = _gstinPattern.firstMatch(normalised);
    if (m == null) return false;
    final state = int.parse(m.group(1)!);
    if (state < 1 || state > 38) return false;
    return gstinCheckChar(normalised.substring(0, 14)) == normalised[14];
  }

  static String normalizeRegistration(String? raw) =>
      (raw ?? '').trim().toUpperCase().replaceAll(_whitespace, '');

  static bool isValidRegistration(String normalised) =>
      _registrationPattern.hasMatch(normalised) && _digit.hasMatch(normalised);

  static String normalizeUdyam(String normalised) {
    final m = _udyamInputPattern.firstMatch(normalised);
    if (m == null) return normalised;
    return 'UDYAM-${m.group(1)}-${m.group(2)}-${m.group(3)}';
  }

  static bool isValidUdyam(String canonical) {
    final m = _udyamCanonicalPattern.firstMatch(canonical);
    return m != null && stateCodes.contains(m.group(1));
  }

  static bool isValidForType(String typeCode, String normalised) =>
      typeCode == udyamCode ? isValidUdyam(normalizeUdyam(normalised)) : isValidRegistration(normalised);

  static String normalizeForType(String typeCode, String? raw) {
    final n = normalizeRegistration(raw);
    return typeCode == udyamCode ? normalizeUdyam(n) : n;
  }

  static String messageForType(String typeCode) =>
      typeCode == udyamCode ? udyamInvalidMessage : registrationInvalidMessage;

  static String normalizeOtherName(String? raw) => (raw ?? '').trim().replaceAll(_whitespace, ' ');

  static String? otherNameError(String? raw) {
    final n = normalizeOtherName(raw);
    if (n.isEmpty) return otherNameEmptyMessage;
    if (!_otherNamePattern.hasMatch(n)) return otherNameInvalidMessage;
    return null;
  }

  static final List<TextInputFormatter> gstinInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    const _UpperCaseFormatter(),
    LengthLimitingTextInputFormatter(15),
  ];

  static final List<TextInputFormatter> registrationInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9/ -]')),
    const _UpperCaseFormatter(),
    LengthLimitingTextInputFormatter(registrationMax),
  ];

  static final List<TextInputFormatter> otherNameInputFormatters = [
    ...noEmojiInputFormatters,
    LengthLimitingTextInputFormatter(otherNameMax),
  ];
}
