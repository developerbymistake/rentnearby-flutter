import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/models/message_model.dart';
import 'package:bakhli/models/question_template_model.dart';
import 'package:bakhli/screens/chat_conversation_screen.dart';
import 'package:bakhli/services/chat_hub_service.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/widgets/stay_contact_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_render.dart';
import '../../../support/real_phone.dart';
import 'stay_work_fixtures.dart';

MessageModel _m(String id, String type, bool mine, Map<String, dynamic> payload, int minute) => MessageModel(
      id: id,
      conversationId: 'conv-e4',
      senderId: mine ? 'me' : 'other',
      isMine: mine,
      type: type,
      payloadJson: jsonEncode(payload),
      readAt: mine ? DateTime(2026, 11, 21, 16, 20) : null,
      createdAt: DateTime(2026, 11, 21, 16, minute),
    );

final _thread = [
  _m('m1', 'text', false, {'text': 'Thank you! We reach around 2 pm on the 27th. Can you send your details?'}, 10),
  _m('m2', StayContactShareCard.type, true, {'upiId': 'meena.bisht@okaxis', 'whatsAppNumber': '9837041122'}, 12),
  _m('m3', 'text', false, {'text': 'Sure, see you on the 27th. Parking is right at the gate.'}, 14),
];

TripEnquiryModel _confirmed({String? phone = '9876543210'}) => TripEnquiryModel.fromJson(enquiryJson(
      id: 'e4',
      name: 'Rohit Verma',
      status: 'ConfirmedByBoth',
      display: 'confirmedByBoth',
      checkIn: '2026-11-27',
      checkOut: '2026-11-29',
      adults: 2,
      phone: phone,
      expiresIn: null,
      acceptedOffer: offerJson(id: 'acc', perNight: 3600),
      agreedTotal: 7200,
      confirmedAt: iso(DateTime(2026, 11, 21, 9)),
    ));

TripEnquiryModel? _enquiry;
List<MessageModel> _messages = const [];

class _Chat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> markRead(String conversationId) async {}
  @override
  Future<List<QuestionTemplateModel>> loadQuestionTemplates({bool forceRefresh = false}) async => questionTemplates;
  @override
  Future<({List<MessageModel> items, String? status, bool hasMore})> getMessages(String conversationId, {DateTime? before, DateTime? after}) {
    if (before != null || after != null) return Future.value((items: <MessageModel>[], status: null, hasMore: false));
    return Future.value((items: _messages.reversed.toList(), status: 'Active', hasMore: false));
  }

  @override
  Future<MessageModel?> sendMessage(String conversationId, String type, Map<String, dynamic> payload, {String? respondsToMessageId, String? clientMessageId}) =>
      Future.value(null);
}

class _Hub extends ChatHubService {
  @override
  Future<void> joinConversation(String conversationId) async {}
  @override
  Future<void> leaveConversation(String conversationId) async {}
}

class _Notif extends NotificationService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
  @override
  void dismissChatNotification(String conversationId) {}
}

class _Enq extends TripEnquiryController {
  @override
  Future<TripEnquiryModel?> forConversation(String conversationId) async => _enquiry;
  @override
  Future<TripEnquiryModel?> refreshOne(String enquiryId) async => _enquiry;
}

class _Launcher extends StatefulWidget {
  const _Launcher();
  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.to(
        () => const ChatConversationScreen(),
        transition: Transition.noTransition,
        arguments: {
          'conversationId': 'conv-e4',
          'listingType': 'Stay',
          'listingId': 'stay-1',
          'otherPartyId': 'trav-e4',
          'otherPartyName': 'Rohit Verma',
          'listingTitle': 'Deodar Heights Homestay',
          'area': 'Nainital',
          'isOwner': true,
          'status': 'Active',
          'isBlockedByMe': false,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

void _register({TripEnquiryModel? enquiry, List<MessageModel> messages = const []}) {
  setUpEnquiries(const {});
  _enquiry = enquiry;
  _messages = messages;
  Get.put<ChatController>(_Chat());
  Get.put<ChatHubService>(_Hub());
  Get.put<NotificationService>(_Notif());
  Get.put<TripEnquiryController>(_Enq());
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await settlePhone(t);
}

void main() {
  tearDown(tearDownWork);

  testWidgets('o_st_40_cardShowsOnlySavedFields, copy and WhatsApp, no money words', (t) async {
    _register(enquiry: _confirmed(), messages: _thread);
    await pumpPhone(t, const _Launcher(), size: const Size(392, 900));
    await _settle(t);
    expect(find.text('Shared by you'), findsOneWidget);
    expect(find.text('meena.bisht@okaxis'), findsOneWidget);
    expect(find.text('+91 98370 41122'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsOneWidget);
    expect(find.text('Contact details only. The app does not take or track payments.'), findsOneWidget);
    for (final w in ['Pay now', 'advance', 'proof', 'Paid']) {
      expect(find.textContaining(w), findsNothing, reason: w);
    }
  });

  testWidgets('o_st_40_barButtonOnlyOnConfirmed, Share and Call guest chips', (t) async {
    _register(enquiry: _confirmed(), messages: _thread);
    await pumpPhone(t, const _Launcher(), size: const Size(392, 900));
    await _settle(t);
    expect(find.text('Share UPI and WhatsApp'), findsOneWidget);
    expect(find.text('Call guest'), findsOneWidget);
  });

  testWidgets('o_st_40 call guest hidden without a phone', (t) async {
    _register(enquiry: _confirmed(phone: null), messages: _thread);
    await pumpPhone(t, const _Launcher(), size: const Size(392, 900));
    await _settle(t);
    expect(find.text('Call guest'), findsNothing);
  });

  testWidgets('o_st_40 card with only a WhatsApp number shows no UPI row', (t) async {
    _register(enquiry: _confirmed(), messages: [_m('m2', StayContactShareCard.type, true, {'whatsAppNumber': '9837041122'}, 12)]);
    await pumpPhone(t, const _Launcher(), size: const Size(392, 900));
    await _settle(t);
    expect(find.text('UPI ID'), findsNothing);
    expect(find.text('Open WhatsApp'), findsOneWidget);
  });

  for (final w in [320.0, 360.0, 411.0]) {
    for (final s in [1.0, 1.3]) {
      testWidgets('o_st_40 chat at $w @$s', (t) async {
        _register(enquiry: _confirmed(), messages: _thread);
        await pumpPhone(t, const _Launcher(), size: Size(w, 800), textScale: s);
        await _settle(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('render o_st_40', (t) async {
    _register(enquiry: _confirmed(), messages: _thread);
    await pumpPhone(t, const _Launcher(), size: Size(ownerFrameWidth, ownerFrameHeight('o_st_40')), devicePixelRatio: ownerFrameDpr, toastHost: true);
    await _settle(t);
    await settlePhone(t);
    final layer = t.binding.renderViews.first.debugLayer! as OffsetLayer;
    final view = t.binding.renderViews.first;
    await t.runAsync(() async {
      final image = await layer.toImage(Offset.zero & (view.size * t.view.devicePixelRatio));
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$ownerRenderDir/o_st_40.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
