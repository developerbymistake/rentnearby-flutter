import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _chatRouteAllowed = [
  'lib/screens/chats_list_screen.dart',
  'lib/screens/chat_conversation_screen.dart',
  'lib/services/notification_service.dart',
  'lib/widgets/global_location_gates.dart',
  'lib/config/app_routes.dart',
];

// Render-only places: old bubbles of these types still print, string constants still defined.
const _renderOnly = {
  // chat_controller.dart reads them only to tell a real old chat from enquiry cards.
  "'contact_request'": ['lib/widgets/chat_message_bubble.dart', 'lib/controllers/chat_controller.dart'],
  "'schedule_proposal'": ['lib/widgets/chat_message_bubble.dart', 'lib/controllers/chat_controller.dart'],
  'Open chat': <String>[],
  'Propose a price': <String>[],
  'Request contact number': <String>[],
  'Schedule a visit': <String>[],
};

const _goneSymbols = [
  'openChatForEnquiry',
  'createOrGetConversation',
  'ChatPlusMenuSheet',
  'TripOwnerActionBar',
  'TripCounterSheet',
  'TripStripAction',
  'sendMessage(',
  'contact-response',
  'schedule-response',
  'TripStrings.openChat',
  'TripStrings.proposePrice',
  'TripChangeRequestSheet',
];

Map<String, String> _lib() => {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
        f.path.replaceAll(Platform.pathSeparator, '/'): f.readAsStringSync(),
    };

void main() {
  final lib = _lib();

  test('no chat send, create or enquiry chat entry is left in lib', () {
    final hits = <String>[
      for (final e in lib.entries)
        for (final s in _goneSymbols)
          if (e.value.contains(s)) '${e.key}: $s',
    ];
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('removed chat files are gone', () {
    for (final p in [
      'lib/widgets/chat_plus_menu_sheet.dart',
      'lib/features/stay/enquiries/trip_owner_action_bar.dart',
      'lib/features/trip/widgets/trip_counter_sheet.dart',
      'lib/features/trip/widgets/trip_change_request_sheet.dart',
    ]) {
      expect(File(p).existsSync(), isFalse, reason: p);
    }
  });

  test('only existing conversations open the chat screen', () {
    final hits = <String>[
      for (final e in lib.entries)
        if (e.value.contains('AppRoutes.chatConversation') && !_chatRouteAllowed.contains(e.key)) e.key,
    ];
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('removed labels and send types appear only where old data renders', () {
    final hits = <String>[];
    _renderOnly.forEach((text, allowed) {
      for (final e in lib.entries) {
        if (e.value.contains(text) && !allowed.contains(e.key)) hits.add('${e.key}: $text');
      }
    });
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('chat screen is history only', () {
    final src = lib['lib/screens/chat_conversation_screen.dart']!;
    for (final s in ['_send(', 'ChatNextSlotBubble', 'ChatSchedulePickerSheet', '_pendingActionMessageIds']) {
      expect(src.contains(s), isFalse, reason: s);
    }
    expect(src, contains('AppRoutes.myEnquiries'));
  });

  test('stay detail has no Chat button', () {
    final src = lib['lib/features/stay/guest/stay_detail_screen.dart']!;
    expect(src.contains('onChat:'), isFalse);
    expect(src.contains('ChatController'), isFalse);
  });
}
