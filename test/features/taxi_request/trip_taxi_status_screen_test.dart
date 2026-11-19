import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_request_status_screen.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/features/trip/widgets/taxi_status/taxi_status_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'taxi_request_controller_fakes.dart';

const _id = '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101';
const _ramesh = 'a1b2c3d4-0001-4a00-8000-000000000001';
const _mohan = 'a1b2c3d4-0002-4a00-8000-000000000002';

class _Harness {
  _Harness(this.json) : repo = FakeTaxiRepo() {
    final req = TaxiRequest.fromJson(json);
    repo.getAnswer = (_) => TaxiOk(req);
    controller = TripTaxiRequestController(
      repo: repo,
      enquiries: FakeEnquiries(),
      realtime: null,
      refreshPlan: (_) async => true,
      onLegacyClosed: () {},
    );
  }

  final Map<String, dynamic> json;
  final FakeTaxiRepo repo;
  late final TripTaxiRequestController controller;
  final List<String> calls = [];
  int done = 0;
  final List<bool> opened = [];

  Widget screen() => TripTaxiRequestStatusScreen(
        requestId: json['id'] as String,
        controller: controller,
        onDone: () => done++,
        onOpenRequest: ({required keepChoices}) => opened.add(keepChoices),
        onCall: (phone) async => calls.add(phone),
        onBack: () {},
      );
}

Map<String, dynamic> _sample(String name, [Map<String, dynamic> change = const {}]) => {...sampleJson(name), ...change};

Map<String, dynamic> _drivers(Map<String, dynamic> base, List<Map<String, dynamic>> list) => {...base, 'drivers': list};

Map<String, dynamic> _driver(String id, String name, {String state = 'Accepted', bool canSelect = true, String? phone = '+919876500001'}) => {
      'offerId': id,
      'state': state,
      'name': name,
      'phone': phone,
      'vehicle': 'Swift Dzire',
      'seats': 4,
      'ratingAverage': 4.8,
      'ratingCount': 72,
      'ridesCompleted': 120,
      'canSelect': canSelect,
      'confirmBy': null,
    };

Future<_Harness> _open(WidgetTester tester, Map<String, dynamic> json, {Size size = phoneSize}) async {
  final h = _Harness(json);
  await pumpAtSize(tester, h.screen(), size);
  await tester.pump();
  await tester.pump();
  return h;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  expect(f, findsOneWidget, reason: key);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump();
}

Finder _t(String text) => find.text(text);

void _stepsAre(String sub) {
  expect(_t('Finding driver'), findsOneWidget);
  expect(_t('Choose your driver'), findsOneWidget);
  expect(_t('Booked'), findsOneWidget);
  expect(_t(sub), findsOneWidget);
}

void main() {
  tearDown(Get.reset);

  testWidgets('frame_29_finding', (tester) async {
    await _open(tester, _sample('taxi_request_finding.json'));
    expect(_t('Request status'), findsOneWidget);
    expect(_t('Uttarakhand Hills Trip'), findsOneWidget);
    expect(_t('Taxi request'), findsOneWidget);
    expect(_t('Pickup at Kathgodam · 3 sightseeing days · Drop'), findsOneWidget);
    _stepsAre('We asked 3 drivers at Kathgodam');
    expect(_t('Your number is shown only to drivers who accept.'), findsNothing);
    expect(_t('Done'), findsOneWidget);
    expect(find.byKey(const ValueKey('status_change_pickup')), findsNothing);
  });

  testWidgets('frame_30_waiting', (tester) async {
    await _open(tester, _sample('taxi_request_waiting.json'));
    _stepsAre('Drivers are busy with other requests. Please wait.');
    expect(_t('Done'), findsOneWidget);
  });

  testWidgets('frame_31_collecting', (tester) async {
    final base = _sample('taxi_request_collecting.json');
    final h = await _open(tester, _drivers(base, [(base['drivers'] as List).first as Map<String, dynamic>]));
    _stepsAre('We asked 3 drivers at Kathgodam');
    expect(find.byKey(const ValueKey('driver_card_$_ramesh')), findsOneWidget);
    expect(find.byKey(const ValueKey('driver_card_$_mohan')), findsNothing);
    expect(_t('Ramesh Kumar'), findsOneWidget);
    expect(_t('4.8 · 120 rides'), findsOneWidget);
    expect(_t('Swift Dzire · 4 seater'), findsOneWidget);
    expect(_t('Not agreed'), findsOneWidget);
    expect(_t('Call'), findsOneWidget);
    expect(_t('Select'), findsOneWidget);
    expect(_t('Still asking more drivers'), findsOneWidget);
    expect(_t('Ask more drivers'), findsOneWidget);
    expect(h.repo.getIds, [_id]);
  });

  testWidgets('frame_32_collecting_two', (tester) async {
    final h = await _open(tester, _sample('taxi_request_collecting.json'));
    expect(find.byKey(const ValueKey('driver_card_$_ramesh')), findsOneWidget);
    expect(find.byKey(const ValueKey('driver_card_$_mohan')), findsOneWidget);
    expect(_t('Select'), findsNWidgets(2));
    await _tap(tester, 'driver_call_$_mohan');
    expect(h.calls, ['+919876500002']);
    expect(_t('On a call'), findsOneWidget);
  });

  testWidgets('frame_33_selected', (tester) async {
    final base = _sample('taxi_request_selected.json');
    final drivers = [
      for (final d in base['drivers'] as List) {...(d as Map<String, dynamic>), 'canSelect': true},
    ];
    await _open(tester, _drivers(base, drivers));
    expect(_t('Waiting for Ramesh Kumar to confirm'), findsOneWidget);
    expect(_t('Selected'), findsOneWidget);
    expect(_t('On hold'), findsOneWidget);
    expect(_t('Select'), findsNothing);
    expect(_t('Not agreed'), findsNothing);
    expect(find.byKey(const ValueKey('driver_call_$_ramesh')), findsOneWidget);
    expect(find.byKey(const ValueKey('driver_call_$_mohan')), findsNothing);
  });

  testWidgets('frame_34_booked', (tester) async {
    await _open(tester, _sample('taxi_request_booked.json'));
    expect(_t('Booked'), findsOneWidget);
    expect(_t('18 Dec to 21 Dec'), findsOneWidget);
    expect(_t('Ramesh Kumar'), findsOneWidget);
    expect(_t('Cancel booking'), findsOneWidget);
    expect(_t('Call'), findsOneWidget);
    expect(_t('Done'), findsOneWidget);
  });

  testWidgets('frame_35_in_progress', (tester) async {
    await _open(tester, _sample('taxi_request_in_progress.json'));
    expect(_t('Trip in progress'), findsOneWidget);
    expect(_t('Day 3 of 4'), findsOneWidget);
    expect(_t('End trip'), findsOneWidget);
    expect(_t('Call'), findsOneWidget);
    expect(find.byType(TaxiProgressBar), findsOneWidget);
  });

  testWidgets('frame_36_rate', (tester) async {
    await _open(tester, _sample('taxi_request_rate.json'));
    expect(_t('Rate your driver'), findsOneWidget);
    expect(_t('Ramesh Kumar'), findsOneWidget);
    expect(find.byKey(const ValueKey('rate_star_5')), findsOneWidget);
    expect(_t('Submit'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('frame_37_thanks', (tester) async {
    await _open(tester, _sample('taxi_request_rate.json', {'state': 'Completed', 'view': 'Done', 'rating': {'stars': 4, 'ratedAt': '2026-12-22T10:00:00Z'}}));
    expect(_t('Thank you'), findsOneWidget);
    expect(_t('Ramesh Kumar'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(5));
    expect(_t('Done'), findsOneWidget);
    expect(_t('Submit'), findsNothing);
  });

  testWidgets('frame_38_cancel_sheet', (tester) async {
    await _open(tester, _sample('taxi_request_booked.json'));
    await _tap(tester, 'cancel_booking');
    await tester.pump(const Duration(milliseconds: 400));
    for (final label in ['Changed plan', 'Not reachable', 'Price not agreed', 'Vehicle issue', 'Other']) {
      expect(_t(label), findsOneWidget, reason: label);
    }
    expect(_t('Confirm cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('frame_39_busy', (tester) async {
    final h = await _open(tester, _sample('taxi_request_busy.json'));
    expect(_t('All drivers are busy right now'), findsOneWidget);
    expect(_t('Please try again in a little while.'), findsOneWidget);
    await _tap(tester, 'busy_change_pickup');
    await _tap(tester, 'busy_try_again');
    expect(h.opened, [false, true]);
  });

  testWidgets('frame_40_no_reply', (tester) async {
    final h = await _open(tester, _sample('taxi_request_no_reply.json'));
    _stepsAre('No reply yet. Still asking drivers.');
    expect(_t('Change pickup'), findsOneWidget);
    expect(_t('Done'), findsOneWidget);
    await _tap(tester, 'status_done');
    expect(h.done, 1);
  });

  testWidgets('reopened_after_driver_withdraw_can_cancel_as_a_plain_request', (tester) async {
    final h = await _open(tester, _sample('taxi_request_finding.json', {
      'booking': {
        'id': 'b0000000-0000-4000-8000-000000000001',
        'state': 'Cancelled',
        'dateFrom': '2026-12-18',
        'dateTo': '2026-12-20',
        'dayNumber': null,
        'canCancel': false,
        'canEnd': false,
      },
      'canCancel': true,
    }));
    await _tap(tester, 'cancel_request');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('taxi_reason_ChangedPlan')), findsNothing);
    await _tap(tester, 'taxi_cancel_confirm');
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.repo.actions, ['cancel:TravellerCancelled:null']);
  });

  for (final name in ['taxi_request_finding.json', 'taxi_request_no_reply.json']) {
    testWidgets('open_with_no_one_ringing_offers_ask_more ($name)', (tester) async {
      final h = await _open(tester, _sample(name, {'stillAsking': false, 'canAskMore': true}));
      expect(_t('No driver agreed yet. Ask more drivers.'), findsOneWidget);
      expect(_t('We asked 3 drivers at Kathgodam'), findsNothing);
      await _tap(tester, 'status_ask_more');
      expect(h.repo.actions, ['askMore']);
    });
  }

  testWidgets('finding_without_ask_more_hides_the_button', (tester) async {
    await _open(tester, _sample('taxi_request_finding.json'));
    expect(find.byKey(const ValueKey('status_ask_more')), findsNothing);
  });

  testWidgets('ended_shows_request_again', (tester) async {
    final h = await _open(tester, _sample('taxi_request_busy.json', {'state': 'Cancelled', 'view': 'Ended'}));
    expect(_t('Request closed'), findsOneWidget);
    await _tap(tester, 'ended_request_again');
    expect(h.opened, [false]);
  });

  group('actions call the controller', () {
    testWidgets('Select', (tester) async {
      final h = await _open(tester, _sample('taxi_request_collecting.json'));
      await _tap(tester, 'driver_select_$_mohan');
      expect(h.repo.actions, ['select:$_mohan']);
    });

    testWidgets('Not agreed', (tester) async {
      final h = await _open(tester, _sample('taxi_request_collecting.json'));
      await _tap(tester, 'driver_not_agreed_$_ramesh');
      expect(h.repo.actions, ['notAgreed:$_ramesh']);
    });

    testWidgets('Ask more', (tester) async {
      final h = await _open(tester, _sample('taxi_request_collecting.json'));
      await _tap(tester, 'status_ask_more');
      expect(h.repo.actions, ['askMore']);
    });

    testWidgets('Cancel booking sends the chosen chip', (tester) async {
      final h = await _open(tester, _sample('taxi_request_booked.json'));
      await _tap(tester, 'cancel_booking');
      await tester.pump(const Duration(milliseconds: 400));
      await _tap(tester, 'taxi_reason_PriceNotAgreed');
      await _tap(tester, 'taxi_cancel_confirm');
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.repo.actions, ['cancel:TravellerCancelled:PriceNotAgreed']);
    });

    testWidgets('Cancel request is a plain confirm', (tester) async {
      final h = await _open(tester, _sample('taxi_request_collecting.json'));
      await _tap(tester, 'cancel_request');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('taxi_reason_ChangedPlan')), findsNothing);
      await _tap(tester, 'taxi_cancel_confirm');
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.repo.actions, ['cancel:TravellerCancelled:null']);
    });

    testWidgets('End trip', (tester) async {
      final h = await _open(tester, _sample('taxi_request_in_progress.json'));
      await _tap(tester, 'end_trip');
      expect(h.repo.actions, ['end']);
    });

    testWidgets('Submit needs a star, then sends it', (tester) async {
      final h = await _open(tester, _sample('taxi_request_rate.json'));
      await _tap(tester, 'rate_submit');
      expect(h.repo.actions, isEmpty);
      await _tap(tester, 'rate_star_4');
      await _tap(tester, 'rate_submit');
      expect(h.repo.actions, ['rate:4']);
    });

    testWidgets('Change pickup on no reply cancels with PickupChanged and opens the request page', (tester) async {
      final h = _Harness(_sample('taxi_request_no_reply.json'));
      final ended = TaxiRequest.fromJson(_sample('taxi_request_no_reply.json', {'version': 99, 'state': 'Cancelled', 'view': 'Ended'}));
      h.repo.actionAnswer = TaxiOk(ended);
      await pumpAtSize(tester, h.screen(), phoneSize);
      await tester.pump();
      await tester.pump();
      await _tap(tester, 'status_change_pickup');
      expect(h.repo.actions, ['cancel:PickupChanged:null']);
      expect(h.opened, [false]);
    });
  });

  testWidgets('select_is_hidden_while_another_driver_is_selected', (tester) async {
    final base = _sample('taxi_request_selected.json');
    await _open(tester, _drivers(base, [
      _driver(_ramesh, 'Ramesh Kumar', state: 'Selected', canSelect: false),
      _driver(_mohan, 'Mohan Singh', canSelect: true, phone: '+919876500002'),
    ]));
    expect(find.byKey(const ValueKey('driver_select_$_mohan')), findsNothing);
    expect(find.byKey(const ValueKey('driver_select_$_ramesh')), findsNothing);
  });

  testWidgets('phone_null_hides_call', (tester) async {
    final base = _sample('taxi_request_collecting.json');
    await _open(tester, _drivers(base, [
      _driver(_ramesh, 'Ramesh Kumar', phone: null),
      _driver(_mohan, 'Mohan Singh', phone: '+919876500002'),
    ]));
    expect(find.byKey(const ValueKey('driver_call_$_ramesh')), findsNothing);
    expect(find.byKey(const ValueKey('driver_call_$_mohan')), findsOneWidget);
    expect(find.byKey(const ValueKey('driver_select_$_ramesh')), findsOneWidget);
  });

  testWidgets('unknown_view_shows_a_neutral_card', (tester) async {
    await _open(tester, _sample('taxi_request_finding.json', {'view': 'SomethingNew'}));
    expect(find.byKey(const ValueKey('status_neutral_card')), findsOneWidget);
    expect(_t('Checking your request'), findsOneWidget);
    expect(_t('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load_failure_shows_retry', (tester) async {
    final h = _Harness(_sample('taxi_request_finding.json'));
    h.repo.getAnswer = (_) => const TaxiOffline<TaxiRequest>();
    await pumpAtSize(tester, h.screen(), phoneSize);
    await tester.pump();
    await tester.pump();
    expect(_t('Could not load this request'), findsOneWidget);
    expect(find.byKey(const ValueKey('status_retry')), findsOneWidget);
    final req = TaxiRequest.fromJson(h.json);
    h.repo.getAnswer = (_) => TaxiOk(req);
    await _tap(tester, 'status_retry');
    expect(h.repo.getIds, [_id, _id]);
    expect(_t('Could not load this request'), findsNothing);
    expect(_t('Taxi request'), findsOneWidget);
    _stepsAre('We asked 3 drivers at Kathgodam');
  });

  group('failed action line', () {
    const busyMsg = 'All drivers are busy. Please try again soon.';

    testWidgets('shows the server message, then hides after a newer request arrives', (tester) async {
      final h = await _open(tester, _sample('taxi_request_collecting.json'));
      h.repo.actionAnswer = const TaxiAllDriversBusy<TaxiRequest>(message: busyMsg);
      await _tap(tester, 'status_ask_more');
      expect(find.byKey(const ValueKey('status_failed_line')), findsOneWidget);
      expect(_t(busyMsg), findsOneWidget);
      final v = h.json['version'] as int;
      final newer = TaxiRequest.fromJson({...h.json, 'version': v + 1});
      h.repo.getAnswer = (_) => TaxiOk(newer);
      await h.controller.refreshRequest();
      await tester.pump();
      expect(find.byKey(const ValueKey('status_failed_line')), findsNothing);
    });

    testWidgets('a later successful action clears it', (tester) async {
      final h = await _open(tester, _sample('taxi_request_collecting.json'));
      h.repo.actionAnswer = const TaxiRefused<TaxiRequest>(type: 'OfferStateInvalid', statusCode: 409, message: 'This driver is no longer free.');
      await _tap(tester, 'driver_select_$_mohan');
      expect(_t('This driver is no longer free.'), findsOneWidget);
      h.repo.actionAnswer = TaxiOk(TaxiRequest.fromJson(h.json));
      await _tap(tester, 'status_ask_more');
      expect(find.byKey(const ValueKey('status_failed_line')), findsNothing);
    });

    testWidgets('client error shows the generic line, offline shows the connection line', (tester) async {
      final h = await _open(tester, _sample('taxi_request_collecting.json'));
      await _tap(tester, 'status_ask_more');
      expect(_t('Something went wrong. Please try again.'), findsOneWidget);
      expect(_t('no answer'), findsNothing);
      h.repo.actionAnswer = const TaxiOffline<TaxiRequest>();
      await _tap(tester, 'status_ask_more');
      expect(_t('No connection. Please try again.'), findsOneWidget);
      expect(_t('Something went wrong. Please try again.'), findsNothing);
    });

    testWidgets('state invalid hides once the refreshed request lands', (tester) async {
      final h = await _open(tester, _sample('taxi_request_collecting.json'));
      final v = h.json['version'] as int;
      final newer = TaxiRequest.fromJson({...h.json, 'version': v + 1});
      h.repo.getAnswer = (_) => TaxiOk(newer);
      h.repo.actionAnswer = const TaxiStateInvalid<TaxiRequest>(message: 'This request changed.');
      await _tap(tester, 'status_ask_more');
      await tester.pump();
      expect(find.byKey(const ValueKey('status_failed_line')), findsNothing);
    });
  });

  testWidgets('back_calls_onBack', (tester) async {
    var back = 0;
    final h = _Harness(_sample('taxi_request_finding.json'));
    await pumpAtSize(
      tester,
      TripTaxiRequestStatusScreen(requestId: _id, controller: h.controller, onBack: () => back++),
      phoneSize,
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pump();
    expect(back, 1);
  });

  testWidgets('detach_on_close', (tester) async {
    final h = await _open(tester, _sample('taxi_request_collecting.json'));
    expect(h.controller.isAttached, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(h.controller.isAttached, isFalse);
  });

  group('five sizes', () {
    final base = _sample('taxi_request_collecting.json');
    final three = _drivers(base, [
      _driver(_ramesh, 'Ramesh Kumar'),
      _driver(_mohan, 'Mohan Singh Bahadur Rathore', phone: '+919876500002'),
      _driver('a1b2c3d4-0003-4a00-8000-000000000003', 'Suresh Pandey', phone: '+919876500003'),
    ]);
    final cases = <String, Map<String, dynamic>>{
      'collecting with three drivers': three,
      'selected': _sample('taxi_request_selected.json'),
      'booked': _sample('taxi_request_booked.json'),
      'in progress': _sample('taxi_request_in_progress.json'),
      'rate': _sample('taxi_request_rate.json'),
      'busy': _sample('taxi_request_busy.json'),
      'no reply': _sample('taxi_request_no_reply.json'),
      'finding': _sample('taxi_request_finding.json'),
      'thanks': _sample('taxi_request_rate.json', {'state': 'Completed', 'view': 'Done', 'rating': {'stars': 4, 'ratedAt': '2026-12-22T10:00:00Z'}}),
    };
    for (final size in fiveSizes) {
      testWidgets('neutral card at ${sizeLabel(size)}', (tester) async {
        await _open(tester, _sample('taxi_request_finding.json', {'view': 'SomethingNew'}), size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('status_neutral_card')), findsOneWidget);
      });
      testWidgets('cancel booking sheet at ${sizeLabel(size)}', (tester) async {
        await _open(tester, _sample('taxi_request_booked.json'), size: size);
        await _tap(tester, 'cancel_booking');
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('taxi_cancel_confirm')), findsOneWidget);
        expect(find.byKey(const ValueKey('taxi_reason_Other')), findsOneWidget);
      });
      testWidgets('cancel request sheet at ${sizeLabel(size)}', (tester) async {
        await _open(tester, _sample('taxi_request_collecting.json'), size: size);
        await _tap(tester, 'cancel_request');
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('taxi_cancel_confirm')), findsOneWidget);
      });
    }
    for (final e in cases.entries) {
      for (final size in fiveSizes) {
        testWidgets('${e.key} at ${sizeLabel(size)}', (tester) async {
          await _open(tester, e.value, size: size);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('status_neutral_card')), findsNothing);
          expect(find.text('Request status'), findsOneWidget);
          if (e.key.startsWith('collecting')) {
            expect(find.byKey(const ValueKey('driver_card_$_ramesh')), findsOneWidget);
          }
        });
      }
    }
  });
}
