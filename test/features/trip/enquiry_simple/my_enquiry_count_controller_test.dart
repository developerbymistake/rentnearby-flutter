import 'package:bakhli/features/trip/enquiries/my_enquiry_count_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('apply sets offers and clear resets it', () {
    final c = MyEnquiryCountController();
    c.apply(waiting: 2, offers: 3, booked: 1);
    expect(c.offers.value, 3);
    c.clear();
    expect(c.offers.value, 0);
  });
}
