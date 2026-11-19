import 'package:bakhli/utils/contact_launcher.dart';
import 'package:bakhli/utils/contact_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const asha = (name: 'Asha Rawat', phone: '9876543210');

  test('stay message has the name, phone and interested text', () {
    expect(
      ContactMessage.stay(stayName: 'Pine Stay', customer: asha),
      'Hello, I am interested in your stay Pine Stay on Bakhli.\n'
      'Name: Asha Rawat\n'
      'Phone: +91 9876543210\n'
      'Please share availability and price. Thank you.',
    );
  });

  test('taxi message has the vehicle, name and phone', () {
    expect(
      ContactMessage.taxi(vehicle: 'Sedan', customer: asha),
      'Hello, I found your taxi (Sedan) on Bakhli.\n'
      'Name: Asha Rawat\n'
      'Phone: +91 9876543210\n'
      'I need a taxi. Please share availability and fare. Thank you.',
    );
  });

  test('no name or a blank name drops the Name line', () {
    expect(ContactMessage.stay(stayName: 'Pine Stay', customer: (name: null, phone: '9876543210')), isNot(contains('Name:')));
    expect(ContactMessage.stay(stayName: 'Pine Stay', customer: (name: '   ', phone: '9876543210')), isNot(contains('Name:')));
    expect(ContactMessage.taxi(customer: (name: '', phone: '9876543210')), contains('Phone: +91 9876543210'));
  });

  test('phone is normalised and a missing phone drops the Phone line', () {
    expect(ContactMessage.stay(customer: (name: 'Asha', phone: '+91 98765 43210')), contains('Phone: +91 9876543210'));
    expect(ContactMessage.stay(customer: (name: 'Asha', phone: null)), isNot(contains('Phone:')));
    expect(ContactMessage.stay(customer: (name: 'Asha', phone: '12345')), isNot(contains('Phone:')));
  });

  test('no customer still gives a message', () {
    expect(
      ContactMessage.stay(stayName: 'Pine Stay'),
      'Hello, I am interested in your stay Pine Stay on Bakhli.\nPlease share availability and price. Thank you.',
    );
  });

  test('missing or fallback titles drop the title', () {
    expect(ContactMessage.stay(stayName: null), startsWith('Hello, I am interested in your stay on Bakhli.'));
    expect(ContactMessage.stay(stayName: 'Stay'), startsWith('Hello, I am interested in your stay on Bakhli.'));
    expect(ContactMessage.taxi(vehicle: null), startsWith('Hello, I found your taxi on Bakhli.'));
    expect(ContactMessage.taxi(vehicle: 'Taxi'), startsWith('Hello, I found your taxi on Bakhli.'));
  });

  test('a name with a new line stays on one line', () {
    final m = ContactMessage.stay(stayName: 'Pine\nStay', customer: (name: 'Asha\n Rawat', phone: '9876543210'));
    expect(m.split('\n'), hasLength(4));
    expect(m, contains('Name: Asha Rawat'));
    expect(m, contains('your stay Pine Stay on'));
  });

  test('WhatsApp url encodes the message', () {
    expect(ContactLauncher.whatsAppUri('9876543210', message: 'a b\nc&d').toString(), 'https://wa.me/919876543210?text=a%20b%0Ac%26d');
    expect(ContactLauncher.whatsAppUri('+91 98765 43210').toString(), 'https://wa.me/919876543210');
    expect(ContactLauncher.whatsAppUri(''), isNull);
  });
}
