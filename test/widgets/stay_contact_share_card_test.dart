import 'dart:convert';

import 'package:bakhli/models/message_model.dart';
import 'package:bakhli/widgets/chat_message_bubble.dart';
import 'package:bakhli/widgets/stay_contact_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

MessageModel _m(String type, Map<String, dynamic> p) => MessageModel(
      id: 'm1',
      conversationId: 'c1',
      senderId: 'o',
      isMine: false,
      type: type,
      payloadJson: jsonEncode(p),
      createdAt: DateTime(2026, 11, 21, 9),
    );

Future<void> _pump(WidgetTester t, MessageModel m) async {
  await t.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: ChatMessageBubble(message: m, templates: const []))),
  ));
  await t.pump();
}

void main() {
  final full = <String, dynamic>{
    'stayName': 'Deodar Cottage',
    'upiId': 'deodar@okaxis',
    'whatsApp': '9876543210',
    'text': 'UPI and WhatsApp shared. Update the app to see them.',
  };

  testWidgets('shows both values with copy and open whatsapp, no amount and no status', (t) async {
    await _pump(t, _m(StayContactShareCard.type, full));
    expect(find.byType(StayContactShareCard), findsOneWidget);
    expect(find.text('Contact details'), findsOneWidget);
    expect(find.text('Shared by you'), findsNothing);
    expect(find.text('Deodar Cottage'), findsOneWidget);
    expect(find.text('deodar@okaxis'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsOneWidget);
    expect(find.text('Contact details only. The app does not take or track payments.'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining('dvance'), findsNothing);
    expect(find.textContaining('roof'), findsNothing);
  });

  testWidgets('o_st_40 sender side reads Shared by you and accepts whatsAppNumber', (t) async {
    final mine = MessageModel(
      id: 'm2',
      conversationId: 'c1',
      senderId: 'me',
      isMine: true,
      type: StayContactShareCard.type,
      payloadJson: jsonEncode({'stayName': 'Deodar Heights', 'upiId': 'meena.bisht@okaxis', 'whatsAppNumber': '9837041122'}),
      createdAt: DateTime(2026, 11, 21, 16, 12),
    );
    await _pump(t, mine);
    expect(find.text('Shared by you'), findsOneWidget);
    expect(find.text('+91 98370 41122'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('copy puts the upi id on the clipboard', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(t, _m(StayContactShareCard.type, full));
    await t.tap(find.text('Copy'));
    await t.pump();
    expect(copied, 'deodar@okaxis');
  });

  testWidgets('a missing upi or whatsapp hides that row', (t) async {
    await _pump(t, _m(StayContactShareCard.type, {...full, 'upiId': null}));
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Open WhatsApp'), findsOneWidget);
    await _pump(t, _m(StayContactShareCard.type, {...full}..remove('whatsApp')));
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsNothing);
  });

  testWidgets('old advance card types render as a neutral note', (t) async {
    for (final type in ['trip_advance_request', 'trip_advance_proof_sent']) {
      await _pump(t, _m(type, {'enquiryId': 'e1', 'amount': 2000, 'status': 'pending'}));
      expect(find.text('This message is no longer shown.'), findsOneWidget, reason: type);
      expect(find.textContaining('2000'), findsNothing);
      expect(t.takeException(), isNull);
    }
    await _pump(t, _m('trip_advance_request', {'text': 'Update the app to see this.'}));
    expect(find.text('Update the app to see this.'), findsOneWidget);
  });
}
