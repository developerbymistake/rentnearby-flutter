import 'package:url_launcher/url_launcher.dart';

class ContactLauncher {
  static const int _phoneLength = 10;

  static String tenDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > _phoneLength ? digits.substring(digits.length - _phoneLength) : digits;
  }

  static Future<void> call(String phone) => _open('tel:+91', phone);

  static Future<void> whatsApp(String phone, {String? message}) => _launch(whatsAppUri(phone, message: message));

  static Uri? whatsAppUri(String phone, {String? message}) =>
      _uri('https://wa.me/91', phone, query: message == null || message.isEmpty ? null : '?text=${Uri.encodeComponent(message)}');

  static Future<void> _open(String prefix, String phone) => _launch(_uri(prefix, phone));

  static Uri? _uri(String prefix, String phone, {String? query}) {
    final number = tenDigits(phone);
    if (number.isEmpty) return null;
    return Uri.parse('$prefix$number${query ?? ''}');
  }

  static Future<void> _launch(Uri? url) async {
    if (url == null) return;
    try {
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
