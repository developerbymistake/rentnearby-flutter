import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/features/trip/utils/trip_easy_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';
import '../trip/support/engine_rig.dart';
import 'taxi_request_controller_fakes.dart';

const _taxiKey = TripEasyRowKey(TripEasyRowKind.taxi);
const _requestId = '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TaxiRequest _cancelled({required bool canRate}) {
  final base = sampleJson('taxi_request_in_progress.json');
  return TaxiRequest.fromJson({
    ...base,
    'id': _requestId,
    'state': 'Cancelled',
    'view': 'Ended',
    'endReason': 'DriverLeftTrip',
    'version': 30,
    'booking': {...(base['booking'] as Map<String, dynamic>), 'state': 'Cancelled', 'canRate': canRate, 'leftDuringTrip': true},
  });
}

Future<(TripPlanController, TripTaxiRequestController)> _rig(TaxiRequest answer) async {
  final plan = enginePlan(const [[2, 2, 2]]);
  installFakeApi([FakeRoute.value('GET', '/trips/{id}', engineTripJson(plan))]);
  final repo = FakeTaxiRepo()..getAnswer = ((_) => TaxiOk(answer));
  Get.put<TabConfigController>(_Tabs());
  final req = Get.put<TripTaxiRequestController>(TripTaxiRequestController(repo: repo, enquiries: FakeEnquiries(), realtime: null));
  final c = TripPlanController();
  c.plan.value = plan;
  Get.put<TripPlanController>(c, permanent: true);
  c.trip.value = engineTrip(plan).copyWith(
    taxiRequest: const TripTaxiRequestRef(requestId: _requestId, state: 'Cancelled', view: 'Ended', version: 30),
  );
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return (c, req);
}

void main() {
  tearDown(Get.reset);

  test('a request cancelled mid-trip that can be rated gives the taxi row a Rate step', () async {
    final (c, req) = await _rig(_cancelled(canRate: true));
    expect(req.request.value?.id, _requestId);
    expect(c.taxiCanRate, isTrue);
    final row = c.easyRowOf(_taxiKey)!;
    expect(row.state, TripRowState.confirmed);
    expect(row.subtitle, TripStringsDayplan.taxiRate);
    expect(row.taxiRequest?.requestId, _requestId);
    expect(TripOverviewTaxi.of(c.trip.value!.taxiRequest, canRate: c.taxiCanRate).chip, 'Completed');
  });

  test('a cancelled request the backend does not allow rating for stays a plain todo', () async {
    final (c, _) = await _rig(_cancelled(canRate: false));
    expect(c.taxiCanRate, isFalse);
    expect(c.easyRowOf(_taxiKey)!.state, TripRowState.todo);
    expect(TripOverviewTaxi.of(c.trip.value!.taxiRequest, canRate: c.taxiCanRate).hasRequest, isFalse);
  });

  test('rules: Cancelled without the rate flag is todo, with it is the Rate row', () {
    const ref = TripTaxiRequestRef(requestId: 'r1', state: 'Cancelled', view: 'Ended', version: 3);
    final plan = enginePlan(const [[2, 2, 2]]);
    TripEasyRowInfo row(bool rate) =>
        TripEasyRules.rowOf(TripEasyRules.rows(plan, const [], const [], taxiRequest: ref, taxiCanRate: rate), _taxiKey)!;
    expect(row(false).state, TripRowState.todo);
    expect(row(true).state, TripRowState.confirmed);
    expect(row(true).subtitle, TripStringsDayplan.taxiRate);
  });
}
