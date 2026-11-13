import 'dart:convert';

import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/models/message_model.dart';
import 'package:bakhli/widgets/trip_chat_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

class _Enq extends TripEnquiryController {
  @override
  Future<TripEnquiryModel?> refreshOne(String enquiryId) async => TripEnquiryModel.fromJson({
        'id': 'e1',
        'tripId': 't1',
        'listingId': 'l1',
        'listingName': 'Deodar Cottage',
        'conversationId': 'c1',
        'status': 'Asked',
        'displayStatus': 'asked',
        'checkIn': '2026-11-13',
        'checkOut': '2026-11-15',
        'context': {'city': 'Nainital', 'adults': 2, 'rooms': 1},
      });
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

MessageModel _m(String id, String type, bool mine, Map<String, dynamic> p) => MessageModel(
      id: id,
      conversationId: 'c1',
      senderId: mine ? 'me' : 'o',
      isMine: mine,
      type: type,
      payloadJson: jsonEncode(p),
      readAt: mine ? DateTime(2026, 11, 12) : null,
      createdAt: DateTime(2026, 11, 12, 9),
    );

final _dates = {'checkIn': '2026-11-13', 'checkOut': '2026-11-15'};

TripChatCallbacks _cb({bool owner = false}) => TripChatCallbacks(
      onAccept: (_, _) {},
      onDecline: (_, _) {},
      onProofSent: (_) {},
      onMarkReceived: (_) {},
      onNotYet: (_) {},
      onAcceptPrice: owner ? (_, _) {} : null,
      onSendDifferentOffer: (_, _) {},
      onAcceptNewPrice: (_, _) {},
      onKeepPrice: (_, _) {},
      onCancelStay: (_) {},
      onAcceptChange: (_, _) {},
      guestName: 'Rahul Sharma',
      hostPhone: '9876543210',
      guestPhone: '9876543210',
      tripId: 't1',
      day: 1,
      listingTitle: 'Deodar Cottage',
      agreedTotal: 7200,
    );

Widget _list(List<Widget> cards) => Scaffold(
      backgroundColor: const Color(0xFFF2F3F8),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 10), children: cards),
      ),
    );

Widget _card(BuildContext c, MessageModel m, {bool owner = false}) =>
    TripChatCards.build(c, m, isOwner: owner, accent: const Color(0xFF2E7D32), callbacks: _cb(owner: owner));

final _scenes = <String, List<(MessageModel, bool)>>{
  'ch_offer': [
    (_m('1', 'trip_enquiry', false, {'enquiryId': 'e1', ..._dates, 'nights': 2, 'adults': 2, 'rooms': 1, 'text': 'Day 1 Naini Lake, Mall Road. Day 2 Snow View.'}), true),
    (
      _m('2', 'trip_offer', false, {
        'enquiryId': 'e1',
        'offerId': 'o1',
        'status': 'pending',
        'validUntil': _iso(DateTime.now().add(const Duration(hours: 23, minutes: 30))),
        ..._dates,
        'nights': 2,
        'total': 7200,
        'advanceAmount': 2000,
        'cancellationText': 'Free till 2 days before',
        'lines': [
          {'roomName': 'Deluxe room', 'units': 1, 'guests': 2, 'pricePerNight': 3600},
        ],
      }),
      false
    ),
  ],
  'ch_advance': [
    (
      _m('3', 'trip_advance_request', false, {
        'enquiryId': 'e1',
        'status': 'pending',
        'amount': 2000,
        'holdUntil': _iso(DateTime.now().add(const Duration(hours: 4))),
        'upiId': 'deodar@okaxis',
        'stayName': 'Deodar Cottage',
        ..._dates,
        'agreedTotal': 7200,
      }),
      false
    ),
    (
      _m('4', 'trip_advance_request', false, {
        'enquiryId': 'e1',
        'status': 'proofSent',
        'amount': 2000,
        'holdUntil': _iso(DateTime.now().add(const Duration(hours: 4))),
        'proofSentAt': _iso(DateTime.now().subtract(const Duration(minutes: 20))),
        'stayName': 'Deodar Cottage',
        ..._dates,
      }),
      false
    ),
  ],
  'ch_end': [
    (_m('5', 'trip_advance_request', false, {'enquiryId': 'e1', 'status': 'received', 'amount': 2000, 'stayName': 'Deodar Cottage', ..._dates, 'agreedTotal': 7200}), false),
    (
      _m('6', 'trip_advance_request', false, {
        'enquiryId': 'e1',
        'status': 'pending',
        'amount': 2000,
        'holdUntil': _iso(DateTime.now().subtract(const Duration(hours: 1))),
        ..._dates,
      }),
      false
    ),
  ],
  'ch_host': [
    (
      _m('7', 'trip_advance_proof_sent', false, {
        'enquiryId': 'e1',
        'status': 'proofSent',
        'amount': 2000,
        'holdUntil': _iso(DateTime.now().add(const Duration(hours: 4))),
        'guestPhone': '9876543210',
        ..._dates,
      }),
      true
    ),
    (_m('8', 'trip_counter', false, {'enquiryId': 'e1', 'offerId': 'k1', 'status': 'pending', 'proposedPerNight': 2200, 'listedPerNight': 2600, 'nights': 2, 'units': 1}), true),
  ],
  'ch_change': [
    (
      _m('9', 'trip_revised_offer', false, {
        'enquiryId': 'e1',
        'offerId': 'r1',
        'status': 'pending',
        'oldTotal': 7200,
        'total': 6800,
        'reason': 'one room is under repair',
        'advanceAgreed': 2000,
        ..._dates,
        'nights': 2,
      }),
      false
    ),
    (
      _m('10', 'trip_change_request', true, {
        'enquiryId': 'e1',
        'offerId': 'c1',
        'status': 'pending',
        'oldCheckIn': '2026-11-13',
        'oldCheckOut': '2026-11-15',
        'checkIn': '2026-11-14',
        'checkOut': '2026-11-16',
        'oldAdults': 2,
        'adults': 2,
        'kids': 1,
        'rooms': 1,
        'oldRooms': 1,
        'total': 7200,
      }),
      false
    ),
  ],
};

void main() {
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\trip-replies';
    Get.testMode = true;
    Get.put<TripEnquiryController>(_Enq());
  });
  tearDown(Get.reset);

  for (final e in _scenes.entries) {
    for (final (tag, w, s) in [('', 360.0, 1.0), ('_13', 360.0, 1.3), ('_300', 300.0, 1.0)]) {
      testWidgets('${e.key}$tag', (t) async {
        debugDisableShadows = false;
        await pumpPhone(
          t,
          Builder(builder: (c) => _list([for (final (m, owner) in e.value) _card(c, m, owner: owner)])),
          size: Size(w, 800),
          devicePixelRatio: 1.5,
          textScale: s,
        );
        await settlePhone(t);
        await shot(t, '${e.key}$tag');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        debugDisableShadows = true;
      });
    }
  }
}
