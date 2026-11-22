import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/owner_core/session/owner_notice_registry.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_app_bookings_controller.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/taxi/requests/models/ring_end.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_bookings_section.dart';
import 'package:bakhli/features/taxi_driver/notices/taxi_notice_copy.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_work_strings.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/plan_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import 'work_fixtures.dart';

PlanModel _paidTaxi({required int trialDays}) => PlanModel(
      id: 'taxi_plus',
      featureKey: 'Taxi',
      code: 'PLUS',
      name: 'Plus',
      tagline: null,
      isDefault: false,
      trialDays: trialDays,
      features: const {'Routes': 5},
      prices: const [],
    );

PlanModel _freeTaxi({required int routes}) => PlanModel(
      id: 'taxi_free',
      featureKey: 'Taxi',
      code: 'FREE',
      name: 'Free',
      tagline: null,
      isDefault: true,
      trialDays: 0,
      features: {'Routes': routes},
      prices: const [],
    );

Map<String, dynamic> _booking(String id, String state, {String from = '2026-12-18', String to = '2026-12-26', Object? stars, String? by}) => {
      'bookingId': id,
      'offerId': 'o-$id',
      'requestId': 'r-$id',
      'state': state,
      'dateFrom': from,
      'dateTo': to,
      'pickupName': 'Kathgodam',
      'travellerName': 'Aarav Sharma',
      'travellerPhone': '+919876543210',
      'canWithdraw': true,
      'canEnd': true,
      'ratingStars': stars,
      'cancelledBy': by,
    };

Notice _notice(String kind, {String? title, Map<String, dynamic> args = const {}}) =>
    Notice.fromJson({'id': 'n1', 'kind': kind, 'refTitle': title, 'refId': 'f1', 'args': args, 'count': 1, 'createdAt': '2026-11-01T07:00:00Z'});

void main() {
  group('o_tx_36 every ring-end line', () {
    const lines = {
      'Filled': TaxiWorkStrings.endTaken,
      'Booked': TaxiWorkStrings.endTaken,
      'RequestCancelled': 'The traveller cancelled the request',
      'DriverOffline': 'You are offline',
      'RouteRemoved': 'You removed this route',
      'ListingInReview': 'This request is closed',
      'Closed': 'This request is closed',
      'Accepted': 'You accepted this request',
      'Declined': 'You declined this request',
    };
    lines.forEach((reason, line) {
      test('ringEnd_$reason', () {
        final e = RingEnd.forReason(reason, paymentOn: true);
        expect(e.title, line);
        expect(e.sub, 'This does not count as a miss.');
        expect(e.kind, RingEndKind.ended);
      });
    });

    test('ringEnd_routePausedByPlan_paymentOn_isE', () {
      final e = RingEnd.forReason('RoutePausedByPlan', paymentOn: true);
      expect(e.kind, RingEndKind.pausedOnFree);
      expect(e.title, 'This route is paused on Free.');
      expect(e.sub, 'Choose which route stays, or get Plus to use all your routes.');
    });

    test('ringEnd_routePausedByPlan_paymentOff_isGenericClosed', () {
      final e = RingEnd.forReason('RoutePausedByPlan', paymentOn: false);
      expect(e.kind, RingEndKind.ended);
      expect(e.title, 'This request is closed');
      expect('${e.title}${e.sub}'.contains('Free'), isFalse);
    });

    test('ringEnd_unknownReason_fallsBackToClosed', () {
      for (final r in [null, '', 'SomethingNew', 'ListingRemoved']) {
        expect(RingEnd.forReason(r, paymentOn: true).title, 'This request is closed');
      }
    });

    test('ringEnd_forOffer_states', () {
      expect(RingEnd.forOffer(offer(state: 'Ringing'), paymentOn: true), isNull);
      expect(RingEnd.forOffer(offer(state: 'Accepted'), paymentOn: true), isNull);
      expect(RingEnd.forOffer(offer(state: 'Missed'), paymentOn: true)!.title, 'Missed');
      expect(RingEnd.forOffer(offer(state: 'Missed'), paymentOn: true)!.sub, 'Went to the next drivers.');
      expect(RingEnd.forOffer(offer(state: 'Declined'), paymentOn: true)!.title, 'You declined this request');
      expect(RingEnd.forOffer(offer(state: 'Closed', endReason: 'Filled'), paymentOn: true)!.title, 'Taken by another driver');
      expect(RingEnd.forOffer(offer(state: 'Closed', endReason: 'Expired'), paymentOn: true)!.kind, RingEndKind.missed);
      expect(RingEnd.forOffer(offer(state: 'Closed'), paymentOn: true)!.title, 'This request is closed');
    });
  });

  group('C-PARSE', () {
    test('offer_jsonVariants_neverThrow', () {
      for (final v in jsonVariants(offerJson(manualTripOn: ['2026-12-20']))) {
        expect(() => DriverOffer.fromJson(v), returnsNormally);
      }
    });

    test('booking_jsonVariants_neverThrow', () {
      for (final v in jsonVariants(_booking('b1', 'Completed', stars: 5, by: 'Traveller'))) {
        expect(() => DriverBooking.fromJson(v), returnsNormally);
      }
    });

    test('manualTripOn_parsed_sorted_and_tolerant', () {
      final o = DriverOffer.fromJson(offerJson(manualTripOn: ['2026-12-22', 'x', '2026-12-20']));
      expect(o.manualTripDays, [DateTime(2026, 12, 20), DateTime(2026, 12, 22)]);
      expect(DriverOffer.fromJson({...offerJson(), 'manualTripOn': 'nope'}).manualTripOn, isEmpty);
      expect(DriverOffer.fromJson({...offerJson()}..remove('manualTripOn')).toJson().containsKey('manualTripOn'), isFalse);
    });

    test('booking_ratingStars_outOfRange_isNull', () {
      expect(DriverBooking.fromJson(_booking('b', 'Completed', stars: 9)).ratingStars, isNull);
      expect(DriverBooking.fromJson(_booking('b', 'Completed', stars: '5')).ratingStars, isNull);
      expect(DriverBooking.fromJson(_booking('b', 'Completed', stars: 4)).ratingStars, 4);
    });

    test('offerEndReason_newValues', () {
      expect(OfferEndReason.parse('RoutePausedByPlan'), OfferEndReason.routePausedByPlan);
      expect(OfferEndReason.parse('ListingInReview'), OfferEndReason.listingInReview);
      expect(OfferEndReason.parse('RouteRemoved'), OfferEndReason.routeRemoved);
    });
  });

  group('copy', () {
    test('amber_manualTrip_line_0_1_2_3', () {
      expect(TaxiWorkStrings.manualTrips(const []), '');
      expect(TaxiWorkStrings.manualTrips([DateTime(2026, 12, 20)]), 'You added a trip on 20 Dec.');
      expect(TaxiWorkStrings.manualTrips([DateTime(2026, 12, 20), DateTime(2026, 12, 22)]), 'You added trips on 20 Dec and 22 Dec.');
      expect(TaxiWorkStrings.manualTrips([DateTime(2026, 12, 20), DateTime(2026, 12, 21), DateTime(2026, 12, 22)]),
          'You added trips on 20 Dec, 21 Dec and 22 Dec.');
    });

    test('frame_strings_exact', () {
      expect(TaxiWorkStrings.stillYours('4:10'), 'Check your internet. The request is still yours for 4:10.');
      expect(TaxiWorkStrings.selectedCountdown('12:40'), 'Selected you · confirm in 12:40');
      expect(TaxiWorkStrings.bookedChip(TaxiWorkStrings.shortRange(DateTime(2026, 12, 18), DateTime(2026, 12, 26))), 'Booked · 18 to 26 Dec');
      expect(TaxiWorkStrings.reopensNote('Aarav'), 'Aarav’s request opens again for other drivers. Your calendar entry stays, marked Cancelled.');
      expect(TaxiWorkStrings.withdrawBookingSub('Aarav', '18 to 26 Dec'), 'Aarav · 18 to 26 Dec');
      expect(TaxiWorkStrings.endTripBody('Aarav'), 'Aarav will be asked to rate you.');
      expect(TaxiWorkStrings.rated('Aarav', 5), 'Aarav rated you 5 stars');
      expect(TaxiWorkStrings.travellerCancelled('Seema'), 'Seema cancelled. Your dates are free again.');
      expect(TaxiWorkStrings.listedFare(3, '₹1,800'), '3 travellers · your listed fare ₹1,800');
      expect(TaxiWorkStrings.yourFare('₹1,900', 3), 'Your fare ₹1,900 · 3 travellers');
      expect(TaxiWorkStrings.inCalendar('₹1,900'), 'Your fare ₹1,900 · in your calendar as From app');
      expect(TaxiWorkStrings.routesHidden(3), '3 routes are hidden on Free. Nothing is deleted.');
      expect(TaxiWorkStrings.freeKeeps(1, trialDays: 7), 'Free keeps 1 route. Try Plus free for 7 days.');
      expect(TaxiWorkStrings.freeKeeps(1), 'Free keeps 1 route.');
      expect(TaxiWorkStrings.freeKeeps(2, trialDays: 14), 'Free keeps 2 routes. Try Plus free for 14 days.');
    });
  });

  group('o_tx_39 booking chips', () {
    DriverBookingLook look(String state, {Object? stars, String? by}) => DriverBookingLook.of(DriverBooking.fromJson(_booking('b', state, stars: stars, by: by)));

    test('chip_mapping_allStates', () {
      expect(look('Booked').chip, 'Occupied');
      expect(look('InProgress').chip, 'On trip');
      expect(look('Completed').chip, 'Completed');
      expect(look('Cancelled').chip, 'Cancelled');
      expect(look('Weird').chip, isNull);
      expect(look('Cancelled').muted, isTrue);
    });

    test('rated_and_cancel_lines', () {
      expect(look('Completed', stars: 5).note, 'Aarav rated you 5 stars');
      expect(look('Completed').note, isNull);
      expect(look('Cancelled', by: 'Traveller').note, 'Aarav cancelled. Your dates are free again.');
      expect(look('Cancelled', by: 'Admin').note, 'Cancelled by Bakhli.');
      expect(look('Cancelled').note, isNull);
    });

    test('order_by_date_like_the_frame', () {
      final list = DriverAppBookingsController.order([
        DriverBooking.fromJson(_booking('c', 'Completed', from: '2026-11-01', to: '2026-11-03')),
        DriverBooking.fromJson(_booking('b', 'Booked', from: '2027-01-02', to: '2027-01-02')),
        DriverBooking.fromJson(_booking('t', 'InProgress')),
        DriverBooking.fromJson(_booking('x', 'Cancelled', from: '2026-11-20', to: '2026-11-21')),
        DriverBooking.fromJson(_booking('t', 'InProgress')),
      ]);
      expect(list.map((b) => b.bookingId), ['c', 'x', 't', 'b']);
    });
  });

  group('o_tx_21 / o_tx_49 / o_tx_45 C notices', () {
    setUp(() {
      OwnerNoticeRegistry.reset();
      TaxiNoticeCopy.register();
    });
    tearDown(() => TaxiNoticeCopy.debugPlan = null);

    test('festival_row_text_and_route', () {
      final v = OwnerNoticeRegistry.of(_notice('FestivalReminder', title: 'Diwali week', args: {'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'}))!;
      expect(v.title, 'Diwali week starts 6 Nov');
      expect(v.body, 'Go online and check your fares.');
      expect(v.tag, 'FESTIVAL');
      expect(v.route, '/my-taxi');
      expect(v.args, {'section': 'routes'});
    });

    test('festival_missingName_or_date_rowHidden', () {
      expect(OwnerNoticeRegistry.of(_notice('FestivalReminder', args: {'dateFrom': '2026-11-06'})), isNull);
      expect(OwnerNoticeRegistry.of(_notice('FestivalReminder', title: 'Diwali week')), isNull);
    });

    test('planLimitsChanged_row', () {
      TaxiNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true, hidden: PlanHiddenModel(routes: 3));
      final v = OwnerNoticeRegistry.of(_notice('PlanLimitsChanged'))!;
      expect(v.title, 'Plans have started');
      expect(v.body, '3 routes are hidden on Free. Nothing is deleted.');
      expect(v.tag, 'PLAN');
      expect(v.route, '/taxi-plan-visible');
      TaxiNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true);
      expect(OwnerNoticeRegistry.of(_notice('PlanLimitsChanged')), isNull);
    });

    test('plansStarting_row_text', () {
      TaxiNoticeCopy.debugPlan = MyPlanModel(paymentEnabled: false, trialAvailable: true, paymentStartsOn: DateTime(2027, 2, 1));
      TaxiNoticeCopy.debugCatalog = [_paidTaxi(trialDays: 7)];
      final v = OwnerNoticeRegistry.of(_notice('PlansStarting'))!;
      expect(v.title, 'Plans start on 1 Feb');
      expect(v.body, 'Free keeps 1 route. Try Plus free for 7 days.');
      expect(v.route, '/plans');
    });

    test('plansStarting_noTrial_noTrialSentence', () {
      TaxiNoticeCopy.debugPlan = MyPlanModel(paymentStartsOn: DateTime(2027, 2, 1));
      TaxiNoticeCopy.debugCatalog = [_paidTaxi(trialDays: 0)];
      expect(OwnerNoticeRegistry.of(_notice('PlansStarting'))!.body, 'Free keeps 1 route.');
    });

    test('plansStarting_catalogNumbers_FT21', () {
      TaxiNoticeCopy.debugPlan = MyPlanModel(paymentStartsOn: DateTime(2027, 2, 1), trialAvailable: true);
      TaxiNoticeCopy.debugCatalog = [_freeTaxi(routes: 2), _paidTaxi(trialDays: 14)];
      expect(OwnerNoticeRegistry.of(_notice('PlansStarting'))!.body, 'Free keeps 2 routes. Try Plus free for 14 days.');
      TaxiNoticeCopy.debugPlan = MyPlanModel(paymentStartsOn: DateTime(2027, 2, 1));
      expect(OwnerNoticeRegistry.of(_notice('PlansStarting'))!.body, 'Free keeps 2 routes.', reason: 'trial already used');
      TaxiNoticeCopy.debugPlan = MyPlanModel(paymentStartsOn: DateTime(2027, 2, 1), trialAvailable: true);
      TaxiNoticeCopy.debugCatalog = const [];
      expect(OwnerNoticeRegistry.of(_notice('PlansStarting'))!.body, 'Free keeps 1 route.');
      TaxiNoticeCopy.debugCatalog = null;
    });

    test('plansStarting_missingDate_rowHidden', () {
      TaxiNoticeCopy.debugPlan = const MyPlanModel(trialAvailable: true);
      expect(OwnerNoticeRegistry.of(_notice('PlansStarting')), isNull);
    });

    test('unknown_kind_noRow', () {
      expect(OwnerNoticeRegistry.of(_notice('SomethingNew')), isNull);
    });
  });
}
