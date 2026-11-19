import 'package:bakhli/features/taxi/requests/utils/indian_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an Indian mobile reads +91 XXXXX XXXXX, anything else is left as is', () {
    expect(IndianPhone.display('+919876543210'), '+91 98765 43210');
    expect(IndianPhone.display('+91 98765 43210'), '+91 98765 43210');
    expect(IndianPhone.display('+4420123456'), '+4420123456');
    expect(IndianPhone.display('98765'), '98765');
  });
}
