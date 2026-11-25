import 'package:bakhli/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Map<String, dynamic>? enquiry, bool? hasChat}) => {
      'id': 'c1',
      'listingType': 'Stay',
      'listingId': 's1',
      'otherPartyId': 'u2',
      'lastMessageAt': '2026-11-25T10:00:00Z',
      'tripEnquiry': ?enquiry,
      'hasChat': ?hasChat,
    };

void main() {
  test('enquiry cards only: left out of Chats', () {
    final c = ConversationModel.fromJson(_json(enquiry: {'id': 'e1', 'status': 'Asked'}, hasChat: false));
    expect(c.enquiryOnly, isTrue);
  });

  test('a real chat message or no enquiry keeps the row', () {
    expect(ConversationModel.fromJson(_json(enquiry: {'id': 'e1', 'status': 'Asked'}, hasChat: true)).enquiryOnly, isFalse);
    expect(ConversationModel.fromJson(_json(hasChat: false)).enquiryOnly, isFalse);
    // Old server without the field: shown as before.
    expect(ConversationModel.fromJson(_json(enquiry: {'id': 'e1', 'status': 'Asked'})).enquiryOnly, isFalse);
  });
}
