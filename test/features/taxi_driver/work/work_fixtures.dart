import 'dart:async';

import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/models/my_plan_model.dart';

final DateTime workNow = DateTime.utc(2026, 12, 10, 9, 40);

String _iso(DateTime d) => d.toUtc().toIso8601String();

/// The frame's trip: Aarav Sharma, Kathgodam pickup, 18 to 26 Dec (o_tx_13, 14, 15, 37, 38).
Map<String, dynamic> offerJson({
  String id = 'offer-1',
  String state = 'Ringing',
  String bucket = 'New',
  String? endReason,
  Duration ringLeft = const Duration(minutes: 4, seconds: 45),
  Duration confirmLeft = const Duration(minutes: 12, seconds: 40),
  String routeLine = 'Kathgodam to Nainital, Ranikhet, Kausani +2',
  bool traveller = true,
  bool trip = true,
  List<String> manualTripOn = const [],
}) =>
    {
      'offerId': id,
      'requestId': 'req-$id',
      'bookingId': state == 'Confirmed' ? 'booking-$id' : null,
      'state': state,
      'endReason': endReason,
      'bucket': bucket,
      'expiresAt': state == 'Ringing' ? _iso(workNow.add(ringLeft)) : null,
      'confirmBy': state == 'Selected' ? _iso(workNow.add(confirmLeft)) : null,
      'pickupName': 'Kathgodam',
      'sections': {'pickup': true, 'sightseeing': true, 'drop': true},
      'sightseeingDayCount': 6,
      'dateFrom': '2026-12-18',
      'dateTo': '2026-12-26',
      'dayCount': 9,
      'nightCount': 8,
      'routeLine': routeLine,
      'seats': 4,
      'travellers': 2,
      'traveller': traveller ? {'name': 'Aarav Sharma', 'phone': '+919876543210'} : null,
      'datesConflict': null,
      'manualTripOn': manualTripOn,
      'trip': trip
          ? {
              'name': 'Uttarakhand Hills Trip',
              'pickup': {'name': 'Kathgodam', 'date': '2026-12-18'},
              'drop': {'name': 'Kathgodam', 'sameAsPickup': true, 'date': '2026-12-26'},
              'cities': [
                {'name': 'Nainital', 'nights': 3, 'from': '2026-12-18', 'to': '2026-12-21'},
                {'name': 'Ranikhet', 'nights': 1, 'from': '2026-12-21', 'to': '2026-12-22'},
              ],
              'days': <Object>[],
            }
          : null,
    };

DriverOffer offer({String id = 'offer-1', String state = 'Ringing', String bucket = 'New', String? endReason, String? routeLine}) =>
    DriverOffer.fromJson(offerJson(id: id, state: state, bucket: bucket, endReason: endReason, routeLine: routeLine ?? 'Kathgodam to Nainital, Ranikhet +2'));

Map<String, dynamic> listJson(List<Map<String, dynamic>> items, {String? next, int newCount = 1}) => {
      'serverNow': _iso(workNow),
      'counts': {'new': newCount, 'booked': 0},
      'nextCursor': next,
      'items': items,
    };

class WorkRepo extends DriverRequestRepository {
  WorkRepo({this.list, this.detail});

  Map<String, dynamic>? list;
  Map<String, dynamic>? detail;
  TaxiResult<DriverOfferList>? listResult;
  TaxiResult<DriverOffer>? detailResult;
  TaxiResult<DriverOffer>? actionResult;
  Completer<void>? hold;
  final calls = <String>[];

  @override
  Future<TaxiResult<DriverOfferList>> offers({String? cursor}) async {
    calls.add(cursor == null ? 'list' : 'more:$cursor');
    if (hold != null) await hold!.future;
    return listResult ?? TaxiOk(DriverOfferList.fromJson(list ?? listJson(const [])));
  }

  @override
  Future<TaxiResult<DriverOffer>> offer(String offerId) async {
    calls.add('detail');
    if (hold != null) await hold!.future;
    return detailResult ?? (detail == null ? const TaxiNotFound<DriverOffer>() : TaxiOk(DriverOffer.fromJson(detail!)));
  }

  Completer<void>? actionHold;

  Future<TaxiResult<DriverOffer>> _act(String name, String state) async {
    calls.add(name);
    if (actionHold != null) await actionHold!.future;
    return actionResult ?? TaxiOk(DriverOffer.fromJson({...?detail, 'state': state}));
  }

  @override
  Future<TaxiResult<DriverOffer>> accept(String offerId) => _act('accept', 'Accepted');

  @override
  Future<TaxiResult<DriverOffer>> decline(String offerId, {ReasonChip? chip}) => _act('decline', 'Declined');

  @override
  Future<TaxiResult<DriverOffer>> confirm(String offerId) => _act('confirm', 'Confirmed');

  @override
  Future<TaxiResult<DriverOffer>> withdraw(String offerId, ReasonChip chip) => _act('withdraw:${chip.wire}', 'Withdrawn');
}

DriverRequestsController workController(WorkRepo repo, {DateTime? now}) =>
    DriverRequestsController(repo: repo, now: () => now ?? workNow, ring: null);

abstract final class WorkPlans {
  static const free = MyPlanModel(paymentEnabled: true, trialAvailable: true);
  static const plus = MyPlanModel(
    paymentEnabled: true,
    isPaid: true,
    isDefault: false,
    limits: PlanLimitsModel(routes: 5, ringWeight: 2),
  );
  static const off = MyPlanModel(paymentEnabled: false, limits: PlanLimitsModel(routes: 5, ringWeight: 1));

  static void use(MyPlanModel p) => PlanGate.debugPlan = p;
}
