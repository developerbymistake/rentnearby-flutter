import 'package:url_launcher/url_launcher.dart';

class ContactLauncher {
  static const int _phoneLength = 10;

  static String tenDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > _phoneLength ? digits.substring(digits.length - _phoneLength) : digits;
  }

  static Future<void> call(String phone) => _open('tel:+91', phone);

  static Future<void> whatsApp(String phone, {String? message}) =>
      _open('https://wa.me/91', phone, query: message == null || message.isEmpty ? null : '?text=${Uri.encodeComponent(message)}');

  static Future<void> _open(String prefix, String phone, {String? query}) async {
    final number = tenDigits(phone);
    if (number.isEmpty) return;
    final url = Uri.parse('$prefix$number${query ?? ''}');
    try {
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
