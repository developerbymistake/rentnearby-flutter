import 'package:flutter/services.dart';

enum DobStatus { ok, future, minor, tooOld }

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

// Mirrors RentNearBy.Core/Models/TaxiIdentityRules.cs.
class TaxiIdentityValidators {
  static const int minAgeYears = 18;
  static const int maxAgeYears = 100;
  static const int dlMinAgeAtIssue = 18;
  static const int dlMinYear = 1970;
  static const int dlInputMaxLength = 19;

  static const dlInvalidMessage = 'Enter a valid licence number';
  static const dlRequiredMessage = 'Enter your driving licence number';
  static const dlHelp = 'As on your licence, e.g. UK07 20150012345';
  static const dlOldHelp = 'Old licence? Use the number shown on mParivahan';
  static const dobInvalidMessage = 'Enter a valid date of birth';
  static const dobRequiredMessage = 'Select your date of birth';
  static const dobMinorMessage = 'You must be $minAgeYears or older';
  static const dlYearMessage = 'Licence year does not match your date of birth';
  static const savedHelp = 'Saved. Leave empty to keep it.';

  static const dlServerMessages = {dlInvalidMessage, dlRequiredMessage, dlYearMessage};
  static const dobServerMessages = {dobInvalidMessage, 'Enter your date of birth', dobMinorMessage};

  static const stateCodes = <String>{
    'AN', 'AP', 'AR', 'AS', 'BR', 'CG', 'CH', 'DD', 'DL', 'GA', 'GJ', 'HP', 'HR', 'JH', 'JK', 'KA', 'KL', 'LA',
    'LD', 'MH', 'ML', 'MN', 'MP', 'MZ', 'NL', 'OD', 'PB', 'PY', 'RJ', 'SK', 'TN', 'TR', 'TS', 'UK', 'UP', 'WB',
    'UA', 'OR', 'DN', 'TG',
  };

  static final _dlPattern = RegExp(r'^([A-Z]{2})([0-9]{2})([0-9]{4})([0-9]{7})$');

  static final List<TextInputFormatter> dlInputFormatters = [
    const _UpperCaseFormatter(),
    FilteringTextInputFormatter.allow(RegExp('[A-Z0-9 -]')),
    LengthLimitingTextInputFormatter(dlInputMaxLength),
  ];

  static String normalizeDl(String? raw) =>
      (raw ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s\-/.]'), '');

  static bool isValidDl(String normalised, {int? currentYear}) {
    final m = _dlPattern.firstMatch(normalised);
    if (m == null) return false;
    if (!stateCodes.contains(m.group(1))) return false;
    if (m.group(2) == '00') return false;
    final year = int.parse(m.group(3)!);
    final maxYear = currentYear ?? todayIst().year;
    if (year < dlMinYear || year > maxYear) return false;
    return m.group(4) != '0000000';
  }

  static int dlIssueYear(String normalised) => int.parse(normalised.substring(4, 8));

  static String formatDl(String normalised) =>
      normalised.length == 15 ? '${normalised.substring(0, 4)} ${normalised.substring(4)}' : normalised;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime yearsBefore(DateTime date, int years) {
    final y = date.year - years;
    final day = (date.month == 2 && date.day == 29 && !_isLeap(y)) ? 28 : date.day;
    return DateTime(y, date.month, day);
  }

  static bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  static int ageOn(DateTime dob, DateTime today) {
    var age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
    return age;
  }

  // The server checks age against the IST day.
  static DateTime todayIst() => dateOnly(DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));

  static DobStatus dobStatus(DateTime dob, DateTime today) {
    if (dob.isAfter(today)) return DobStatus.future;
    final age = ageOn(dob, today);
    if (age < minAgeYears) return DobStatus.minor;
    if (age > maxAgeYears) return DobStatus.tooOld;
    return DobStatus.ok;
  }

  static bool dlYearMatchesDob(int issueYear, DateTime dob) => issueYear >= dob.year + dlMinAgeAtIssue;

  static String dobMessage(DobStatus s) => switch (s) {
        DobStatus.ok => '',
        DobStatus.minor => dobMinorMessage,
        _ => dobInvalidMessage,
      };

  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String displayDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}
