import 'contact_launcher.dart';

typedef ContactCustomer = ({String? name, String? phone});

class ContactMessage {
  static const String call = 'Call';
  static const String whatsApp = 'WhatsApp';

  static String stay({String? stayName, ContactCustomer? customer}) => _build(
        _named('Hello, I am interested in your stay', stayName, fallback: 'Stay'),
        customer,
        'Please share availability and price. Thank you.',
      );

  static String taxi({String? vehicle, ContactCustomer? customer}) => _build(
        _named('Hello, I found your taxi', vehicle, fallback: 'Taxi', brackets: true),
        customer,
        'I need a taxi. Please share availability and fare. Thank you.',
      );

  static String _clean(String? v) => (v ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _named(String lead, String? title, {required String fallback, bool brackets = false}) {
    final t = _clean(title);
    if (t.isEmpty || t == fallback) return '$lead on Bakhli.';
    return brackets ? '$lead ($t) on Bakhli.' : '$lead $t on Bakhli.';
  }

  static String _build(String first, ContactCustomer? customer, String last) {
    final name = _clean(customer?.name);
    final phone = ContactLauncher.tenDigits(customer?.phone ?? '');
    return [
      first,
      if (name.isNotEmpty) 'Name: $name',
      if (phone.length == 10) 'Phone: +91 $phone',
      last,
    ].join('\n');
  }
}
