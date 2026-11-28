import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/design/extra/ext_taxi_owner.dart';
import 'package:bakhli/design/extra/list_rows_3d.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart' hide TaxiRoutePlace;
import 'package:bakhli/features/taxi/models/taxi_vehicle_type_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_review_strings.dart';
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
  Future<bool> saveBasic(Map<String, dynamic> body) async {
    calls.add('basic');
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

Future<void> _openOverMain(WidgetTester t, _Wizard c) async {
  c.mainBelow = true;
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, const Text('HOME'), size: const Size(392, 1500), toastHost: true);
  Get.key.currentState!.push(MaterialPageRoute<void>(settings: const RouteSettings(name: AppRoutes.main), builder: (_) => const Text('MAIN')));
  await _settle(t);
  Get.key.currentState!.push(MaterialPageRoute<void>(builder: (_) => const TaxiVehicleScreen(onboarding: true)));
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

Future<void> _next(WidgetTester t) async {
  await _tapText(t, TaxiSetupStrings.next);
  await _settle(t);
}

Future<void> _submitAndAnswer(WidgetTester t, String answer) async {
  await _tapText(t, TaxiSetupStrings.submit);
  await _settle(t);
  expect(find.text(TaxiReviewStrings.confirmTitle), findsOneWidget);
  expect(find.text(TaxiReviewStrings.confirmBody), findsOneWidget);
  await _tapText(t, answer);
  await _settle(t);
}

Future<void> _editCard(WidgetTester t, int index) async {
  final edit = find.text(TaxiReviewStrings.edit).at(index);
  await t.ensureVisible(edit);
  await t.pump();
  await t.tap(edit, warnIfMissed: false);
  await _settle(t);
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

TaxiOwnerModel _ready({int? rate = 2500, int? km = 120}) =>
    setupTaxi(step1: true, identity: true, routes: [setupRoute('r1', 'Haldwani', 'Almora', 2400)], rate: rate, km: km);

void main() {
  tearDown(tearDownTaxiSetup);

  test('the wizard has six steps and the last one is Review', () {
    expect(TaxiSetupStrings.wizardSteps, hasLength(6));
    expect(TaxiSetupStrings.wizardLabels, hasLength(6));
    for (final s in TaxiSetupStrings.wizardSteps) {
      expect(s, contains('of 6'));
    }
    expect(TaxiSetupStrings.wizardSteps.last, 'Step 6 of 6 · Review');
    expect(TaxiSetupStrings.wizardLabels.last, 'Review');
  });

  test('Review lines follow mock P7: name · licence added, phone when no name, arrow route', () {
    expect(TaxiReviewStrings.stepLine, 'Step 6 of 6 · Check everything, then send');
    expect(TaxiReviewStrings.driverLine(lead: 'Ramesh', licence: true), 'Ramesh · licence added');
    expect(TaxiReviewStrings.driverLine(lead: 'Ramesh', licence: false), 'Ramesh');
    expect(TaxiReviewStrings.driverLine(lead: '+91 9876511223', licence: true), '+91 9876511223 · licence added');
    expect(TaxiReviewStrings.driverLine(lead: null, licence: true), 'Licence added');
    expect(TaxiReviewStrings.driverLine(lead: ' ', licence: false), '');
    expect(TaxiReviewStrings.routeLine('Haldwani', 'Nainital'), 'Haldwani → Nainital');
  });

  test('onboarding route form is capped at the free plan value', () {
    final c = _setUp(setupTaxi(step1: true, identity: true));
    final form = TaxiRoutesFormController(onboarding: true)..seed(c.taxi.value);
    expect(form.max, PlanKeys.freeSeed[PlanKey.routes]);
    expect(form.max, 1);
    expect(form.formOpen, isTrue);
    form.dispose();
    expect(TaxiRoutesFormController(onboarding: false).max, 10);
  });

  test('onboarding: a saved route opens filled in the form, never as a list row, and validate keeps its key', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final route = setupRoute('r1', 'Haldwani', 'Almora', 2400);
    final c = _setUp(setupTaxi(step1: true, identity: true, routes: [route]));
    final form = TaxiRoutesFormController(onboarding: true)..seed(c.taxi.value);
    expect(form.routes, isEmpty);
    expect(form.formOpen, isTrue);
    expect(form.to?.name, 'Almora');
    expect(form.fareCtrl.text, '2400');
    expect(form.tripType, 'OneWay');
    expect(form.validate(), isTrue);
    expect(form.payload(), hasLength(1));
    expect(form.payload().toString(), TaxiRoutesFormController.keyOf([route]));
    form.openSingle();
    expect(form.formOpen, isTrue);
    expect(form.routes, isEmpty);
    expect(form.to?.name, 'Almora');
    form.dispose();

    final manage = TaxiRoutesFormController(onboarding: false)..seed(c.taxi.value);
    expect(manage.routes, hasLength(1), reason: 'Manage routes keeps its list');
    expect(manage.formOpen, isTrue);
    expect(manage.to, isNull);
    manage.dispose();
  });

  test('onboarding: an empty form fails validate and stays open', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = _setUp(setupTaxi(step1: true, identity: true));
    final form = TaxiRoutesFormController(onboarding: true)..seed(c.taxi.value);
    expect(form.validate(), isFalse);
    expect(form.formOpen, isTrue);
    expect(form.routes, isEmpty);
    expect(form.ring, TaxiRouteRing.to);
    form.dispose();
  });

  testWidgets('a resumed draft opens on the Route page: one form, Next, no list, meter or add row', (t) async {
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
    expect(find.byType(TaxiRouteCard3D), findsNothing);
    expect(find.text(TaxiSetupStrings.routeNumber(1)), findsOneWidget);
    expect(find.text(TaxiSetupStrings.next), findsOneWidget);
    expect(find.text(TaxiSetupStrings.save), findsNothing);
    await _close(t);
  });

  testWidgets('Next saves the one route and moves on; Back shows the same form filled; an unchanged route is not sent again', (t) async {
    final c = _setUp(setupTaxi(step1: true, identity: true));
    await _open(t);
    await _fillAlmora(t);
    await _next(t);
    expect(c.calls, ['routes']);
    expect(c.routePayloads.single, hasLength(1));
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);

    await _tapText(t, 'Back');
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[3]), findsOneWidget);
    expect(find.byType(TaxiRouteCard3D), findsNothing, reason: 'no list row in onboarding');
    expect(find.text('Almora'), findsOneWidget);
    expect(find.text('2400'), findsOneWidget);
    expect(find.text(TaxiSetupStrings.next), findsOneWidget);

    await _next(t);
    expect(c.calls, ['routes'], reason: 'unchanged route is not sent again');
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await _close(t);
  });

  testWidgets('a saved route reopens filled with no Edit or Delete row', (t) async {
    final c = _setUp(_ready());
    await _open(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[3]), findsOneWidget);
    expect(find.byType(TaxiRouteCard3D), findsNothing);
    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.text('Almora'), findsOneWidget);
    expect(find.text('2400'), findsOneWidget);
    await _next(t);
    expect(c.calls, isEmpty);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await _close(t);
  });

  testWidgets('the Rate page shows Next; Next saves the rate and opens Review with the five cards', (t) async {
    final c = _setUp(_ready(rate: null, km: null));
    await _open(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    expect(find.text(TaxiSetupStrings.submit), findsNothing);
    await t.enterText(find.byType(EditableText).at(0), '2500');
    await t.enterText(find.byType(EditableText).at(1), '120');
    await t.pump();
    await _next(t);
    expect(c.calls, ['rate']);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    expect(find.text(TaxiSetupStrings.submit), findsOneWidget);
    for (final title in [TaxiReviewStrings.vehicle, TaxiReviewStrings.driver, TaxiReviewStrings.base, TaxiReviewStrings.route, TaxiReviewStrings.dayRate]) {
      expect(find.descendant(of: find.byType(SummaryRow3D), matching: find.text(title)), findsOneWidget);
    }
    expect(find.text(TaxiReviewStrings.edit), findsNWidgets(5));
    expect(find.text('Maruti Ertiga · 6 seats · UK 04 TA 2231'), findsOneWidget);
    expect(find.text('Pradeep Kumar · licence added'), findsOneWidget);
    expect(find.text(TaxiReviewStrings.sub), findsNothing, reason: 'shown inside the step line');
    expect(find.text('Step 6 of 6 · Check everything, then send'), findsOneWidget);
    expect(find.text('Haldwani, Nainital'), findsOneWidget);
    expect(find.text('Haldwani → Almora · ₹2,400'), findsOneWidget);
    expect(find.text('₹2,500 · 120 km a day'), findsOneWidget);
    await _close(t);
  });

  testWidgets('a bad rate stays on the Rate page', (t) async {
    final c = _setUp(_ready(rate: null, km: null));
    await _open(t);
    await _next(t);
    expect(c.calls, isEmpty);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await _close(t);
  });

  testWidgets('Submit asks first: Not now sends nothing, Send submits and lands on Home', (t) async {
    final c = _setUp(_ready());
    await _openOverMain(t, c);
    await _next(t);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    await _submitAndAnswer(t, TaxiReviewStrings.notNow);
    expect(c.calls, isEmpty);
    expect(find.text(TaxiReviewStrings.confirmTitle), findsNothing);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    await _submitAndAnswer(t, TaxiReviewStrings.send);
    expect(c.calls, ['submit']);
    expect(find.text('MAIN'), findsOneWidget);
    await _close(t);
  });

  testWidgets('a failed submit stays on Review and a retry submits again', (t) async {
    final c = _setUp(_ready(rate: null, km: null), submitFails: 1);
    await _openOverMain(t, c);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await t.enterText(find.byType(EditableText).at(0), '2500');
    await t.enterText(find.byType(EditableText).at(1), '120');
    await t.pump();
    await _next(t);
    await _submitAndAnswer(t, TaxiReviewStrings.send);
    expect(c.calls, ['rate', 'submit']);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    await _submitAndAnswer(t, TaxiReviewStrings.send);
    expect(c.calls, ['rate', 'submit', 'submit']);
    expect(find.text('MAIN'), findsOneWidget);
    await _close(t);
  });

  testWidgets('Edit Route opens the Route page and its Next saves and comes straight back to Review', (t) async {
    final c = _setUp(_ready());
    await _open(t);
    await _next(t);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    await _editCard(t, 3);
    expect(find.text(TaxiSetupStrings.wizardSteps[3]), findsOneWidget);
    expect(find.text('Almora'), findsOneWidget);
    await t.enterText(find.byType(EditableText).first, '2600');
    await t.pump();
    await _next(t);
    expect(c.calls, ['routes']);
    expect(c.routePayloads.single.single['fare'], 2600);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    expect(find.text('Haldwani → Almora · ₹2,600'), findsOneWidget);
    await _close(t);
  });

  testWidgets('Edit Day rate: Next saves the new rate and returns to Review', (t) async {
    final c = _setUp(_ready());
    await _open(t);
    await _next(t);
    await _editCard(t, 4);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await t.enterText(find.byType(EditableText).at(0), '3000');
    await t.pump();
    await _next(t);
    expect(c.calls, ['rate']);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    expect(find.text('₹3,000 · 120 km a day'), findsOneWidget);
    await _close(t);
  });

  testWidgets('Edit Driver with nothing changed: Next goes straight back to Review without saving', (t) async {
    final c = _setUp(_ready());
    await _open(t);
    await _next(t);
    await _editCard(t, 1);
    expect(find.text(TaxiSetupStrings.wizardSteps[1]), findsOneWidget);
    await _next(t);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    expect(c.calls, isEmpty);
    await _close(t);
  });

  testWidgets('Back from an edit goes back to Review: on page 1 no menu, and a changed route is dropped', (t) async {
    final c = _setUp(_ready());
    await _open(t);
    await _next(t);
    await _editCard(t, 0);
    expect(find.text(TaxiSetupStrings.wizardSteps[0]), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.text('Back'), findsOneWidget);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);

    await _editCard(t, 3);
    await t.enterText(find.byType(EditableText).first, '2900');
    await t.pump();
    await _tapText(t, 'Back');
    await _settle(t);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    expect(find.text('Haldwani → Almora · ₹2,400'), findsOneWidget);
    await _editCard(t, 3);
    expect(find.text('2400'), findsOneWidget);
    expect(c.calls, isEmpty);
    await _close(t);
  });

  testWidgets('Back from Review goes to the Rate page', (t) async {
    _setUp(_ready());
    await _open(t);
    await _next(t);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    await _tapText(t, 'Back');
    await _settle(t);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
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
    await _next(t);
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
      _ready(),
      submitFails: 1,
      submitError: 'TaxiLocked',
      afterLoad: setupTaxi(status: TaxiStatus.pendingReview, step1: true, identity: true, routes: route, rate: 2500, km: 120),
    );
    await _openOverMain(t, c);
    expect(find.text(TaxiSetupStrings.wizardSteps[4]), findsOneWidget);
    await _next(t);
    await _submitAndAnswer(t, TaxiReviewStrings.send);
    expect(c.calls, ['submit', 'load']);
    expect((Get.find<AuthController>() as SetupAuth).refreshes, 1);
    expect(find.text('MAIN'), findsOneWidget);
    await _close(t);
  });

  testWidgets('a TaxiLocked Submit on a taxi that is not under review stays on Review', (t) async {
    final c = _setUp(_ready(), submitFails: 1, submitError: 'TaxiLocked');
    await _open(t);
    await _next(t);
    await _submitAndAnswer(t, TaxiReviewStrings.send);
    expect(c.calls, ['submit', 'load']);
    expect((Get.find<AuthController>() as SetupAuth).refreshes, 0);
    expect(find.text(TaxiReviewStrings.stepLine), findsOneWidget);
    await _close(t);
  });
}
