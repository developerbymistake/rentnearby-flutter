import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiry_actions.dart';
import 'package:bakhli/features/stay/enquiries/trip_ask_advance_sheet.dart';
import 'package:bakhli/features/stay/enquiries/trip_send_offer_sheet.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_supply_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_offer_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/features/trip/screens/trip_stay_enquiry_sheet.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_enquiry_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_accept_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_cancel_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_change_request_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_counter_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_driver_reply_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_problem_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_send_result_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_taxi_booking_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_update_ask_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_withdraw_sheet.dart';
import 'package:bakhli/widgets/trip_report_traveller_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../journeys/fake_api.dart';
import '../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Supply extends TripSupplyController {
  @override
  bool get staysOutOfDate => false;
  @override
  Future<void> ensureStays(int legIndex) async => stayLeg.value = legIndex;
  @override
  Future<void> ensureTaxis(int legIndex, {int? day}) async => taxiLeg.value = legIndex;
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, Object?> _offer(int perNight, int nights, {int? advance, String kind = 'Offer'}) => {
      'id': 'of$perNight',
      'kind': kind,
      'nights': nights,
      'lines': [
        {'roomName': 'Deluxe room', 'units': 1, 'guests': 2, 'pricePerNight': perNight},
      ],
      'total': perNight * nights,
      'advanceAmount': ?advance,
      'cancellationText': 'Free till 2 days before',
      'validUntil': _iso(DateTime.now().add(const Duration(hours: 23))),
      'status': 'Pending',
    };

TripEnquiryModel _stay(String id, String name, String display,
    {String status = 'Asked', int? agreed, Map<String, Object?>? openOffer, Map<String, Object?>? change, Map<String, Object?>? advance, DateTime? start}) {
  final j = enquiryJson(id: id, kind: 'Stay', status: status, start: start ?? journeyStart(), nights: 2, displayStatus: display, agreedTotal: agreed);
  return TripEnquiryModel.fromJson({
    ...j,
    'listingId': 'stay-$id',
    'listingName': name,
    'conversationId': 'c$id',
    'createdAt': _iso(DateTime.now().subtract(const Duration(hours: 2))),
    'expiresAt': _iso(DateTime.now().add(const Duration(hours: 22))),
    'owner': {'id': 'o$id', 'name': 'Host', 'phone': '9876543210'},
    'traveller': {'id': 't$id', 'name': 'Rahul Sharma', 'phone': '9876543211'},
    'context': {...(j['context'] as Map<String, Object?>), 'adults': 2, 'rooms': 1},
    'openOffer': ?openOffer,
    'pendingChange': ?change,
    'advance': ?advance,
  });
}

TripEnquiryModel _taxi(String id, String display, {int? fare, int? agreed, String status = 'Asked'}) {
  final j = enquiryJson(id: id, kind: 'Taxi', status: status, start: journeyStart(), days: [1, 2], displayStatus: display);
  return TripEnquiryModel.fromJson({
    ...j,
    'listingName': 'Ramesh Kumar',
    'createdAt': _iso(DateTime.now().subtract(const Duration(hours: 1))),
    'owner': {'id': 'd$id', 'name': 'Ramesh Kumar', 'phone': '9876543210'},
    'taxi': {'listedRate': 3000, 'driverFare': ?fare, 'driverNote': 'AC car, toll included', 'agreedFare': ?agreed},
  });
}

final _stayOwner = StayOwnerModel.fromJson({
  'id': 's1',
  'status': 'Approved',
  'name': 'Deodar Cottage',
  'rooms': [
    {'id': 'r1', 'roomIndex': 1, 'pricePerNight': 3600, 'maxGuests': 2, 'roomName': 'Deluxe room'},
    {'id': 'r2', 'roomIndex': 2, 'pricePerNight': 2600, 'maxGuests': 3, 'roomName': 'Family room'},
  ],
});

final _configs = <(String, double, double)>[('', 360, 1.0), ('_13', 360, 1.3), ('_300', 300, 1.0)];

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\trip-replies';
    Get.testMode = true;
    installFakeApi([]);
    Get.put<TabConfigController>(_Tabs());
    final plan = Get.put(TripPlanController());
    plan.plan.value = journeyPlan([3]);
    Get.put<TripSupplyController>(_Supply());
  });
  tearDown(Get.reset);

  final offered = _stay('a', 'Deodar Cottage', 'offered', status: 'Offered', openOffer: _offer(3600, 2, advance: 2000));
  final asked = _stay('b', 'Lakeside Rooms', 'asked');
  final confirmed = _stay('d', 'Himalayan View Homestay', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 7200);
  final fareSent = _taxi('t1', 'fareSent', fare: 4500);
  final booked = _taxi('t2', 'confirmedByBoth', agreed: 4500, status: 'ConfirmedByBoth');
  final withAdvance = _stay('e', 'Deodar Cottage', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 7200, advance: {
    'status': 'ProofSent',
    'amount': 2000,
    'holdUntil': _iso(DateTime.now().add(const Duration(hours: 4))),
  });
  final withChange = _stay('f', 'Deodar Cottage', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 7200, change: {
    ..._offer(3600, 2, kind: 'ChangeRequest'),
    'id': 'ch1',
  });

  final scenes = <String, Future<Object?> Function(BuildContext)>{
    'sr_accept': (c) => TripAcceptSheet.show(c, enquiry: offered, offer: offered.openOffer!),
    'sr_counter': (c) => TripCounterSheet.show(c, enquiry: asked),
    'sr_withdraw': (c) => TripWithdrawSheet.show(c, enquiry: asked),
    'sr_withdraw2': (c) => TripWithdrawSheet.showForRemove(c, open: [asked, offered]),
    'sr_withdraw_inline': (c) => TripWithdrawSheet.confirmInline(c),
    'sr_cancel': (c) => TripCancelSheet.show(c, enquiry: confirmed, ownerSide: false),
    'sr_change': (c) => TripChangeRequestSheet.show(c, enquiry: confirmed, checkIn: journeyStart(), checkOut: journeyStart().add(const Duration(days: 2))),
    'tr_lead': (c) => TripDriverReplySheet.show(c, enquiry: fareSent),
    'tr_booked': (c) => TripTaxiBookingSheet.show(c, taxi: null, day: 1, enquiry: fareSent, initialFare: 4500),
    'tr_cancel': (c) => TripCancelSheet.show(c, enquiry: booked, ownerSide: true),
    'ua_sheet': (c) => TripUpdateAskSheet.show(c, SettingsSaveResult(saved: true, openAffected: [asked], confirmedAffected: [confirmed], openTaxiAffected: [fareSent])),
    'pr_sheet': (c) => TripProblemSheet.show(c, day: 1),
    'sd_result': (c) => TripSendResultSheet.show(
          c,
          batch: TripEnquiryBatch(items: [asked, offered], skipped: const [TripSkipped(listingId: 'stay-c', reason: 'AlreadyOpen')], veryShortNotice: false),
          names: const {'stay-a': 'Deodar Cottage', 'stay-b': 'Lakeside Rooms', 'stay-c': 'Pine Ridge Stay'},
        ),
    'sd_fail': (c) => TripSendResultSheet.show(
          c,
          batch: const TripEnquiryBatch(items: [], skipped: [TripSkipped(listingId: 'stay-c', reason: 'AlreadyOpen'), TripSkipped(listingId: 'stay-b', reason: 'NotAvailable')], veryShortNotice: false),
          names: const {'stay-b': 'Lakeside Rooms', 'stay-c': 'Pine Ridge Stay'},
        ),
    'hi_offer': (c) => TripSendOfferSheet.show(c, enquiry: asked, stay: _stayOwner),
    'hi_revised': (c) => TripSendOfferSheet.show(c, enquiry: confirmed, stay: _stayOwner, revised: true),
    'hi_advance': (c) => TripAskAdvanceSheet.show(c, enquiry: confirmed, stay: _stayOwner),
    'hi_na': (c) => StayEnquiryActions.notAvailable(c, asked),
    'hi_mark': (c) => StayEnquiryActions.markReceived(c, withAdvance),
    'hi_change': (c) => StayEnquiryActions.acceptChange(c, withChange, 'ch1'),
    'rt_sheet': (c) => TripReportTravellerSheet.show(c, enquiry: asked),
    'se_stay': (c) => TripStayEnquirySheet.show(
          c,
          stay: StayNearbyModel(id: 'stay-x', name: 'Deodar Cottage', latitude: 29.3, longitude: 79.5, minPricePerNight: 3600, distanceKm: 1, isActive: true),
          day: 1,
          nights: 2,
        ),
    'se_taxi': (c) => TripTaxiEnquirySheet.show(
          c,
          driver: TaxiBrowseItem(id: 'x1', driverName: 'Ramesh Kumar', vehicleTypeName: 'Sedan', plateDisplay: 'UK 04 AB 1234', routeCount: 2, matchReversed: false, createdAt: DateTime(2026)),
          days: const [1, 2],
        ),
  };

  final revisedOffer = TripOfferModel.fromJson({..._offer(3400, 2, kind: 'Revised'), 'id': 'rv1', 'oldTotal': 7200});
  final withRevised = _stay('g', 'Deodar Cottage', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 7200);
  scenes['sr_revised'] = (c) => TripAcceptSheet.show(c, enquiry: withRevised, offer: revisedOffer);
  scenes['ua_people'] = (c) {
    TripPlanController.to.lastSettingsChange = (dates: false, people: true, days: false);
    return TripUpdateAskSheet.show(c, SettingsSaveResult(saved: true, openAffected: [asked], openTaxiAffected: [fareSent]));
  };
  scenes['pr_off'] = (c) {
    TripPlanController.to.offline.value = true;
    return TripProblemSheet.show(c, day: 1);
  };

  for (final s in scenes.entries) {
    for (final (tag, w, sc) in _configs) {
      testWidgets('${s.key}$tag', (t) async {
        TripPlanController.to.enquiryList.assignAll([offered, asked, confirmed, fareSent, booked]);
        debugDisableShadows = false;
        await pumpPhone(
          t,
          Builder(
            builder: (c) => Scaffold(
              backgroundColor: const Color(0xFFD8EEDA),
              body: Center(child: TextButton(onPressed: () => s.value(c), child: const Text('go'))),
            ),
          ),
          size: Size(w, 800),
          devicePixelRatio: 1.5,
          textScale: sc,
        );
        await t.tap(find.text('go'));
        await t.pump();
        await settlePhone(t);
        await shot(t, '${s.key}$tag');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
        debugDisableShadows = true;
      });
    }
  }

  final actions = <String, (Future<Object?> Function(BuildContext), Future<void> Function(WidgetTester))>{
    'sr_counter2': (
      (c) => TripCounterSheet.show(c, enquiry: asked),
      (t) async {
        await t.enterText(find.byType(TextField).first, '50');
        await t.tap(find.text(TripStrings.sendMyPrice));
      }
    ),
    'hi_offer2': (
      (c) => TripSendOfferSheet.show(c, enquiry: asked, stay: _stayOwner),
      (t) async {
        await t.enterText(find.byType(TextField).first, '');
        await t.tap(find.text(TripStrings.sendOffer).last);
      }
    ),
    'hi_offer3': (
      (c) => TripSendOfferSheet.show(c, enquiry: asked, stay: _stayOwner),
      (t) async {
        await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -500));
      }
    ),
    'hi_advance2': (
      (c) => TripAskAdvanceSheet.show(c, enquiry: confirmed, stay: _stayOwner),
      (t) async {
        await t.tap(find.text(TripStrings.sendInChat));
      }
    ),
    'pr_other': (
      (c) => TripProblemSheet.show(c, day: 1),
      (t) async {
        await t.tap(find.text(TripStrings.somethingElse));
      }
    ),
    'pr_sheet_host': (
      (c) {
        final today = TripClock.today();
        TripPlanController.to.plan.value = journeyPlan([3], start: today);
        TripPlanController.to.enquiryList.assignAll([
          _stay('h1', 'Deodar Cottage', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 7200, start: today),
          _stay('h2', 'Lakeside Rooms', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 6400, start: today),
        ]);
        return TripProblemSheet.show(c, day: 1);
      },
      (t) async {
        await t.tap(find.text(TripStrings.hostNoRoom));
      }
    ),
    'tr_booked3': (
      (c) => TripTaxiBookingSheet.show(c, taxi: null, day: 1, enquiry: fareSent, initialFare: 50),
      (t) async {
        await t.tap(find.text(TripStrings.saveBooking));
        await t.pump(const Duration(milliseconds: 300));
        await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -400));
      }
    ),
    'tr_booked2': (
      (c) => TripTaxiBookingSheet.show(c, taxi: null, day: 1, enquiry: fareSent, initialFare: 50),
      (t) async {
        await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -400));
      }
    ),
  };

  for (final a in actions.entries) {
    testWidgets(a.key, (t) async {
      TripPlanController.to.enquiryList.assignAll([offered, asked, confirmed, fareSent, booked]);
      debugDisableShadows = false;
      await pumpPhone(
        t,
        Builder(
          builder: (c) => Scaffold(
            backgroundColor: const Color(0xFFD8EEDA),
            body: Center(child: TextButton(onPressed: () => a.value.$1(c), child: const Text('go'))),
          ),
        ),
        size: const Size(360, 800),
        devicePixelRatio: 1.5,
      );
      await t.tap(find.text('go'));
      await t.pump();
      await settlePhone(t);
      await a.value.$2(t);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await shot(t, a.key);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
      debugDisableShadows = true;
    });
  }
}
