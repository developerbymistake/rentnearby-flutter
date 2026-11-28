abstract final class TaxiReviewStrings {
  static const title = 'Review';
  static const sub = 'Check everything, then send';
  static const stepLine = 'Step 6 of 6 · $sub';
  static const vehicle = 'Vehicle';
  static const driver = 'Driver';
  static const base = 'Base';
  static const route = 'Route';
  static const dayRate = 'Day rate';
  static const edit = 'Edit';
  static const licenceAdded = 'Licence added';
  static String driverLine({String? lead, required bool licence}) {
    final l = lead?.trim() ?? '';
    if (l.isEmpty) return licence ? licenceAdded : '';
    return licence ? '$l · licence added' : l;
  }

  static String routeLine(String from, String to) => '$from → $to';
  static const confirmTitle = 'Send for review?';
  static const confirmBody = 'We check your details. Travellers see your taxi once it is approved.';
  static const send = 'Send';
  static const notNow = 'Not now';
  static String seats(String n) => '$n seats';
  static String rateLine(String rate, int km) => '$rate · $km km a day';
}
