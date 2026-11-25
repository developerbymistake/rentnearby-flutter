import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/design/extra/ext_taxi_owner.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart' hide TaxiRoutePlace;
import 'package:bakhli/features/taxi/models/taxi_vehicle_type_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_route_strings.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_form.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/taxi/setup/taxi_vehicle_screen.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart';
import 'package:bakhli/features/taxi/taxi_vehicle_types_controller.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_setup_strings.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/real_phone.dart';
import 'taxi_setup_fixtures.dart';

class _Types extends TaxiVehicleTypesController {
  @override
  // ignore: must_call_super
  void onInit() {
    types.value = const [TaxiVehicleTypeModel(id: 'v3', name: 'Maruti Ertiga', category: 'MUV', defaultSeats: 7, sortOrder: 1)];
  }

  @override
  Future<void> load() async {}
}

class _Wizard extends SetupTaxi {
  _Wizard(super.model, {this.submitFails = 0, this.submitError, this.afterLoad});
  int submitFails;
  final String? submitError;
  final TaxiOwnerModel? afterLoad;
  final calls = <String>[];
  final routePayloads = <List<Map<String, dynamic>>>[];

  @override
  Future<bool> load() async {
    if (submitError != null) {
      calls.add('load');
      if (afterLoad != null) taxi.value = afterLoad;
    }
    return true;
  }

  @override
  Future<bool> saveRoutes(List<Map<String, dynamic>> routes, {bool quietLimit = false}) async {
    calls.add('routes');
    routePayloads.add(routes);
    final t = taxi.value!;
    taxi.value = setupTaxi(
      step1: true,
      identity: t.identityDone,
      routes: [for (var i = 0; i < routes.length; i++) setupRoute('s$i', routes[i]['fromName'] as String, routes[i]['toName'] as String, routes[i]['fare'] as int)],
      rate: t.localDayRate,
      km: t.localDayKm,
    );
    return true;
  }

  @override
  Future<bool> saveLocalRate({int? dayRate, int? kmPerDay}) async {
    calls.add('rate');
    final t = taxi.value!;
    taxi.value = setupTaxi(step1: true, identity: t.identityDone, routes: t.routes, rate: dayRate, km: kmPerDay);
    return true;
  }

  @override
  Future<bool> submit() async {
    calls.add('submit');
    if (submitFails > 0) {
      submitFails--;
      lastErrorType = submitError;
      return false;
    }
    return true;
  }
}

const _haldwani = TripCityModel(cityKey: 210108988, name: 'Haldwani', districtName: 'Nainital', stateName: 'Uttarakhand', latitude: 29.22, longitude: 79.51);
const _almora = TripCityModel(cityKey: 210003898, name: 'Almora', districtName: 'Almora', stateName: 'Uttarakhand', latitude: 29.6, longitude: 79.66);

_Wizard _setUp(TaxiOwnerModel? model, {int submitFails = 0, bool canCorrect = false, String? submitError, TaxiOwnerModel? afterLoad}) {
  setUpTaxiSetup(model, canCorrect: canCorrect);
  Get.put<TaxiVehicleTypesController>(_Types());
  Get.put<TripCityCatalog>(TripCityCatalog()..seedForTest(const [_haldwani, _almora]), permanent: true);
  Get.delete<TaxiSetupController>(force: true);
  return Get.put<TaxiSetupController>(_Wizard(model, submitFails: submitFails, submitError: submitError, afterLoad: afterLoad)) as _Wizard;
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _open(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, const TaxiVehicleScreen(onboarding: true), size: const Size(392, 1500), toastHost: true);
  await _settle(t);
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 11));
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _fillAlmora(WidgetTester t) async {
  await _tapText(t, TaxiRouteStrings.chooseCity);
  await settlePhone(t);
  await t.tap(find.text('Almora').last);
  await settlePhone(t);
  await _tapText(t, 'One way');
  await t.enterText(find.byType(EditableText).first, '2400');
  await t.pump();
}

void main() {
  tearDown(tearDownTaxiSetup);

  test('onboarding route form is capped at the free plan value', () {
    final c = _setUp(setupTaxi(step1: true, identity: true));
    final form = TaxiRoutesFormController(onboarding: true)..seed(c.taxi.value);
    expect(form.max, PlanKeys.freeSeed[PlanKey.routes]);
    expect(form.max, 1);
    expect(form.formOpen, isTrue);
    form.dispose();
    expect(TaxiRoutesFormController(onboarding: false).max, 10);
  });

  test('onboarding route form: Save refuses an empty form, keeps exactly one route, delete reopens an empty form', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = _setUp(setupTaxi(step1: true, identity: true));
    final form = TaxiRoutesFormController(onboarding: true)..seed(c.taxi.value);
    expect(form.saveForm(), isFalse);
    expect(form.formOpen, isTrue);
    expect(form.routes, isEmpty);
    form
      ..from = TaxiRoutePlace.fromCity(_haldwani)
      ..to = TaxiRoutePlace.fromCity(_almora)
      ..fareCtrl.text = '2400'
      ..pickTrip(0);
    expect(form.saveForm(), isTrue);
    expect(form.routes, hasLength(1));
    expect(form.formOpen, isFalse);
    expect(form.count, form.max);
    form.removeRoute(0);
    expect(form.routes, isEmpty);
    expect(form.formOpen, isTrue);
    expect(form.to, isNull);
    expect(form.fareCtrl.text, isEmpty);
    expect(form.tripType, isNull);
    form.dispose();
  });

  testWidgets('a resumed draft opens on the Route page with no plan meter, add row, tip or footer meter', (t) async {
    _setUp(setupTaxi(step1: true, identity: true));
    await _open(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[3]), findsOneWidget);
    expect(find.text(TaxiSetupStrings.addOneRoute), findsOneWidget);
    expect(find.byKey(const ValueKey('routes_meter_chip')), findsNothing);
    expect(find.byKey(const ValueKey('routes_add_locked')), findsNothing);
    expect(find.byKey(const ValueKey('routes_footer_meter')), findsNothing);
    expect(find.text('Add another route'), findsNothing);
    expect(find.text('Add route'), findsNothing);
    expect(find.textContaining('on Free'), findsNothing);
    expect(find.textContaining('Plus'), findsNothing);
    expect(find.textContaining('Upgrade'), findsNothing);
    expect(find.text(TaxiSetupStrings.routeNumber(1)), findsOneWidget, reason: 'the Route 1 form is already open');
    expect(find.text(TaxiSetupStrings.save), findsOneWidget);
    expect(find.text(TaxiSetupStrings.next), findsNothing);
    await _close(t);
  });

  testWidgets('Save turns the form into the route card and the button into Next; Next saves exactly one route, Back keeps it', (t) async {
    final c = _setUp(setupTaxi(step1: true, identity: true));
    await _open(t);
    await _fillAlmora(t);
    await _tapText(t, TaxiSetupStrings.save);
    await _settle(t);
    expect(c.calls, isEmpty, reason: 'Save keeps the route on the phone');
    expect(find.text('Haldwani to Almora'), findsOneWidget);
    expect(find.byType(TaxiRouteCard3D), findsOneWidget);
    expect(find.text(TaxiRouteStrings.chooseCity), findsNothing);
    expect(find.text(TaxiSetupStrings.save), findsNothing);
    expect(find.text(TaxiSetupStrings.next), findsOneWidget);
    expect(find.text('Add route'), findsNothing);
    expect(find.text('Add another route'), findsNothing);
    await _tapText(t, TaxiSetupStrings.next);
    await _settle(t);
    expect(c.calls, ['routes']);
    expect(c.routePayloads.single, hasLength(1));
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);

    await _tapText(t, 'Back');
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[3]), findsOneWidget);
    expect(find.text('Haldwani to Almora'), findsOneWidget);
    expect(find.text(TaxiRouteStrings.chooseCity), findsNothing, reason: 'one route is the cap, no second form');
    expect(find.text(TaxiSetupStrings.save), findsNothing);

    await _tapText(t, TaxiSetupStrings.next);
    await _settle(t);
    expect(c.calls, ['routes'], reason: 'unchanged route is not sent again');
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await _close(t);
  });

  testWidgets('a saved route: edit opens the form with Save, delete returns to the open empty form', (t) async {
    final c = _setUp(setupTaxi(step1: true, identity: true, routes: [setupRoute('r1', 'Haldwani', 'Almora', 2400)], rate: 2500, km: 120));
    await _open(t);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[3]), findsOneWidget);
    expect(find.byType(TaxiRouteCard3D), findsOneWidget);
    expect(find.text(TaxiSetupStrings.next), findsOneWidget);
    expect(find.text(TaxiSetupStrings.save), findsNothing);

    await t.tap(find.descendant(of: find.byType(TaxiRouteCard3D), matching: find.byIcon(Icons.edit_rounded)));
    await _settle(t);
    expect(find.byType(TaxiRouteCard3D), findsNothing);
    expect(find.text('Almora'), findsOneWidget);
    expect(find.text(TaxiSetupStrings.save), findsOneWidget);
    await _tapText(t, TaxiSetupStrings.save);
    await _settle(t);
    expect(find.byType(TaxiRouteCard3D), findsOneWidget);
    expect(find.text(TaxiSetupStrings.next), findsOneWidget);

    await t.tap(find.descendant(of: find.byType(TaxiRouteCard3D), matching: find.byIcon(Icons.close_rounded)));
    await _settle(t);
    expect(find.byType(TaxiRouteCard3D), findsNothing);
    expect(find.text(TaxiSetupStrings.routeNumber(1)), findsOneWidget);
    expect(find.text(TaxiRouteStrings.chooseCity), findsOneWidget, reason: 'To is empty again');
    expect(find.text(TaxiSetupStrings.save), findsOneWidget);
    expect(find.text(TaxiSetupStrings.next), findsNothing);
    expect(find.text('Add route'), findsNothing);
    expect(c.calls, isEmpty);
    await _close(t);
  });

  testWidgets('Submit saves the rate then submits; a failed submit keeps the input and retry submits again', (t) async {
    final c = _setUp(setupTaxi(step1: true, identity: true, routes: [setupRoute('r1', 'Haldwani', 'Almora', 2400)]), submitFails: 1);
    c.mainBelow = true;
    await t.pumpWidget(const SizedBox.shrink());
    await pumpPhone(t, const Text('HOME'), size: const Size(392, 1500), toastHost: true);
    Get.key.currentState!.push(MaterialPageRoute<void>(settings: const RouteSettings(name: AppRoutes.main), builder: (_) => const Text('MAIN')));
    await _settle(t);
    Get.key.currentState!.push(MaterialPageRoute<void>(builder: (_) => const TaxiVehicleScreen(onboarding: true)));
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    expect(find.text(TaxiSetupStrings.submit), findsOneWidget);
    await t.enterText(find.byType(EditableText).at(0), '2500');
    await t.enterText(find.byType(EditableText).at(1), '120');
    await t.pump();
    await _tapText(t, TaxiSetupStrings.submit);
    await _settle(t);
    expect(c.calls, ['rate', 'submit']);
    expect(find.text('2500'), findsOneWidget);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await _tapText(t, TaxiSetupStrings.submit);
    await _settle(t);
    expect(c.calls, ['rate', 'submit', 'submit']);
    expect(find.text('MAIN'), findsOneWidget);
    await _close(t);
  });

  testWidgets('Back from the Rate page goes to the Route page and the typed rate survives', (t) async {
    final c = _setUp(setupTaxi(step1: true, identity: true, routes: [setupRoute('r1', 'Haldwani', 'Almora', 2400)]));
    await _open(t);
    await t.enterText(find.byType(EditableText).at(0), '3100');
    await t.pump();
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[3]), findsOneWidget);
    await _tapText(t, TaxiSetupStrings.next);
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    expect(find.text('3100'), findsOneWidget);
    expect(c.calls, isEmpty);
    await _close(t);
  });

  testWidgets('page 1 of a gated draft shows the menu button and Back stays put without the one-time correction', (t) async {
    _setUp(null);
    await _open(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[0]), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[0]), findsOneWidget);
    await _close(t);
  });

  testWidgets('a retried Submit that answers TaxiLocked reloads and leaves the wizard once the taxi is under review', (t) async {
    final route = [setupRoute('r1', 'Haldwani', 'Almora', 2400)];
    final c = _setUp(
      setupTaxi(step1: true, identity: true, routes: route, rate: 2500, km: 120),
      submitFails: 1,
      submitError: 'TaxiLocked',
      afterLoad: setupTaxi(status: TaxiStatus.pendingReview, step1: true, identity: true, routes: route, rate: 2500, km: 120),
    );
    c.mainBelow = true;
    await t.pumpWidget(const SizedBox.shrink());
    await pumpPhone(t, const Text('HOME'), size: const Size(392, 1500), toastHost: true);
    Get.key.currentState!.push(MaterialPageRoute<void>(settings: const RouteSettings(name: AppRoutes.main), builder: (_) => const Text('MAIN')));
    await _settle(t);
    Get.key.currentState!.push(MaterialPageRoute<void>(builder: (_) => const TaxiVehicleScreen(onboarding: true)));
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await _tapText(t, TaxiSetupStrings.submit);
    await _settle(t);
    expect(c.calls, ['submit', 'load']);
    expect((Get.find<AuthController>() as SetupAuth).refreshes, 1);
    expect(find.text('MAIN'), findsOneWidget);
    await _close(t);
  });

  testWidgets('a TaxiLocked Submit on a taxi that is not under review stays on the Rate page', (t) async {
    final route = [setupRoute('r1', 'Haldwani', 'Almora', 2400)];
    final c = _setUp(setupTaxi(step1: true, identity: true, routes: route, rate: 2500, km: 120), submitFails: 1, submitError: 'TaxiLocked');
    await _open(t);
    await _tapText(t, TaxiSetupStrings.submit);
    await _settle(t);
    expect(c.calls, ['submit', 'load']);
    expect((Get.find<AuthController>() as SetupAuth).refreshes, 0);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await _close(t);
  });
}
