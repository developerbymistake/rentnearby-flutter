import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_name_screen.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/features/trip/trip_routes.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a1.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import 'support/engine_rig.dart';

const _nainital = TripCityModel(cityKey: 1, name: 'Nainital', stateName: 'Uttarakhand', latitude: 29.4, longitude: 79.4);
const _almora = TripCityModel(cityKey: 2, name: 'Almora', stateName: 'Uttarakhand', latitude: 29.6, longitude: 79.6);

TripSpotModel _spot(String id) => TripSpotModel.fromJson({
      'id': id,
      'name': id,
      'latitude': 29.4,
      'longitude': 79.4,
      'category': 'attraction',
      'visitMinutes': 60,
    });

Map<dynamic, dynamic>? _spotsArgs;
var _spotsOpened = 0;

Future<void> _pumpHome(WidgetTester t) async {
  _spotsArgs = null;
  _spotsOpened = 0;
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(411, 891);
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    home: const Scaffold(body: Text('destinations')),
    getPages: [
      tripPages.firstWhere((p) => p.name == AppRoutes.tripName),
      GetPage(
        name: AppRoutes.tripSpots,
        page: () {
          _spotsOpened++;
          _spotsArgs = Get.arguments as Map?;
          return const Scaffold(body: Text('places'));
        },
      ),
    ],
  ));
}

Map<String, dynamic> _sent(FakeTripAdapter api, String method, String path) =>
    Map<String, dynamic>.from(api.calls(method, path).last.data as Map);

TripPlan _onePlan() => enginePlan([[2, 2]]);

TripPlan _twoCityPlan() => enginePlan([[2], [2]]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('name_flow_gs').path);
    await GetStorage.init();
  });
  setUp(StorageService.clearTripNewDraft);
  tearDown(Get.reset);

  testWidgets('destination_then_name_then_places', (t) async {
    await _pumpHome(t);
    TripNavigation.startWithCities([_nainital]);
    await t.pumpAndSettle();
    expect(find.byType(TripNameScreen), findsOneWidget);
    expect(find.text('Uttarakhand Hills Trip'), findsOneWidget);
    expect(_spotsOpened, 0);

    await t.tap(find.byType(PrimaryButton));
    await t.pumpAndSettle();
    expect(find.text('places'), findsOneWidget);
    expect(find.byType(TripNameScreen), findsNothing);
    expect(_spotsOpened, 1);
    expect((_spotsArgs!['city'] as TripCityModel).cityKey, 1);
    expect(TripNewDraft.readName(), 'Uttarakhand Hills Trip');
  });

  testWidgets('back_from_name_returns_to_the_destination_list', (t) async {
    TripNewDraft.save([TripDraftLeg(_almora, ['x'])]);
    final before = StorageService.getTripNewDraft();
    await _pumpHome(t);
    TripNavigation.startWithCities([_nainital]);
    await t.pumpAndSettle();
    expect(find.byType(TripNameScreen), findsOneWidget);

    Get.back();
    await t.pumpAndSettle();
    expect(find.text('destinations'), findsOneWidget);
    expect(_spotsOpened, 0);
    expect(StorageService.getTripNewDraft(), before);
    expect(TripNewDraft.readName(), isNull);
  });

  test('create_body_has_name', () async {
    final api = installFakeApi([
      FakeRoute('POST', '/trips/plan', (o) {
        final body = o.data as Map;
        final ids = [for (final s in body['spots'] as List) (s as Map)['id'] as String];
        return {
          'days': [
            {'day': 1, 'spotIds': ids, 'visitMinutes': 120, 'totalMinutes': 150},
          ],
          'osrmAvailable': true,
          'dayLimitMinutes': 300,
        };
      }),
      FakeRoute('POST', '/trips', (o) {
        final body = o.data as Map;
        return engineTripJson(
          TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)),
          extra: {'title': body['name'], 'nameChosen': true},
        );
      }),
    ]);
    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b'])]);
    TripNewDraft.saveName('  Family   Hills  ');
    final c = TripPlanController();
    addTearDown(c.onClose);
    await c.startFromSelection(_nainital, [_spot('a'), _spot('b')]);

    final body = _sent(api, 'POST', '/trips');
    expect(body['name'], 'Family Hills');
    expect(body.containsKey('title'), isFalse);
    expect(c.title, 'Family Hills');
    expect(StorageService.getTripNewDraft(), isNull);

    final fallback = TripPlanController();
    addTearDown(fallback.onClose);
    await fallback.startFromSelection(_nainital, [_spot('c')]);
    expect(_sent(api, 'POST', '/trips')['name'], 'Uttarakhand Hills Trip');
    expect(_sent(api, 'POST', '/trips').containsKey('title'), isFalse);
  });

  testWidgets('rename_over_60_is_refused_with_the_message', (t) async {
    final api = installFakeApi([
      FakeRoute('PUT', '/trips/{id}', (o) {
        final body = o.data as Map;
        return engineTripJson(TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)));
      }),
    ]);
    await t.pumpWidget(GetMaterialApp(
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [Positioned.fill(child: child!), Overlay(key: AppToast.overlayKey)],
      ),
      home: const Scaffold(body: SizedBox()),
    ));
    final c = engineRig(_onePlan());
    var ok = await c.rename('a' * 61);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 600));
    expect(ok, isFalse);
    expect(find.text('Trip name must be 1 to 60 characters'), findsOneWidget);
    expect(api.calls('PUT', '/trips/t1'), isEmpty);
    expect(c.title, 'Uttarakhand Hills Trip');

    await t.runAsync(() async => ok = await c.rename('   '));
    expect(ok, isFalse);
    expect(api.calls('PUT', '/trips/t1'), isEmpty);

    await t.runAsync(() async => ok = await c.rename('b' * 60));
    expect(ok, isTrue);
    expect(_sent(api, 'PUT', '/trips/t1')['name'], 'b' * 60);
    await t.pump(const Duration(seconds: 5));
  });

  test('save_without_rename_sends_neither_field', () async {
    final api = installFakeApi([
      FakeRoute('PUT', '/trips/{id}', (o) {
        final body = o.data as Map;
        return engineTripJson(
          TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)),
          extra: {'title': body['name'] ?? 'Uttarakhand Hills Trip', 'nameChosen': body['name'] != null},
        );
      }),
    ]);
    final c = engineRig(_onePlan());

    expect(await c.saveNow(), isTrue);
    var body = _sent(api, 'PUT', '/trips/t1');
    expect(body.containsKey('name'), isFalse);
    expect(body.containsKey('title'), isFalse);

    expect(await c.rename('  Lake   Days '), isTrue);
    body = _sent(api, 'PUT', '/trips/t1');
    expect(body['name'], 'Lake Days');
    expect(body.containsKey('title'), isFalse);

    expect(await c.saveNow(), isTrue);
    body = _sent(api, 'PUT', '/trips/t1');
    expect(body.containsKey('name'), isFalse);
    expect(body.containsKey('title'), isFalse);
    expect(api.calls('PUT', '/trips/t1').length, 3);
    expect(c.title, 'Lake Days');
  });

  testWidgets('resumed_draft_keeps_its_name_and_skips_the_step', (t) async {
    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b'])], days: 3);
    TripNewDraft.saveName('Kept Name');
    await _pumpHome(t);
    TripNavigation.startWithCities([_nainital]);
    await t.pumpAndSettle();
    expect(find.byType(TripNameScreen), findsNothing);
    expect(find.text('places'), findsOneWidget);
    expect((_spotsArgs!['draftLegs'] as List<TripDraftLeg>).single.ids, ['a', 'b']);
    final draft = TripNewDraft.read()!;
    expect(draft.name, 'Kept Name');
    expect(draft.days, 3);

    TripNewDraft.save([TripDraftLeg(_nainital, ['a', 'b', 'c'])]);
    expect(TripNewDraft.readName(), 'Kept Name');
    TripNewDraft.save(const []);
    expect(TripNewDraft.read(), isNull);
    expect(TripNewDraft.readName(), 'Kept Name');
  });

  testWidgets('a draft from an older build without a name gets the step', (t) async {
    TripNewDraft.save([TripDraftLeg(_nainital, ['a'])]);
    expect(TripNewDraft.readName(), isNull);
    await _pumpHome(t);
    TripNavigation.startWithCities([_nainital]);
    await t.pumpAndSettle();
    expect(find.byType(TripNameScreen), findsOneWidget);
    await t.enterText(find.byType(TextFormField), 'Old Draft Trip');
    await t.tap(find.byType(PrimaryButton));
    await t.pumpAndSettle();
    expect(find.text('places'), findsOneWidget);
    expect((_spotsArgs!['draftLegs'] as List<TripDraftLeg>).single.ids, ['a']);
    expect(TripNewDraft.read()!.name, 'Old Draft Trip');
  });

  test('accepted_suggestion_survives_a_city_change', () async {
    final c = TripPlanController();
    addTearDown(c.onClose);
    final one = _onePlan();
    c.plan.value = one;
    c.trip.value = TripModel.fromJson(engineTripJson(one, extra: {'nameChosen': true}));
    expect(c.title, 'Uttarakhand Hills Trip');
    c.plan.value = _twoCityPlan();
    expect(c.title, 'Uttarakhand Hills Trip');

    final renamed = engineRig(_onePlan());
    installFakeApi([
      FakeRoute('PUT', '/trips/{id}', (o) {
        final body = o.data as Map;
        return engineTripJson(
          TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)),
          extra: {'title': body['name'] ?? 'Nainital Trip', 'nameChosen': true},
        );
      }),
    ]);
    expect(await renamed.rename('Nainital Trip'), isTrue);
    renamed.plan.value = _twoCityPlan();
    expect(renamed.title, 'Nainital Trip');
  });

  test('suggested_name_from_create_survives_a_city_change', () async {
    final api = installFakeApi([
      FakeRoute('POST', '/trips/plan', (o) {
        final body = o.data as Map;
        final ids = [for (final s in body['spots'] as List) (s as Map)['id'] as String];
        return {
          'days': [
            {'day': 1, 'spotIds': ids, 'visitMinutes': 120, 'totalMinutes': 150},
          ],
          'osrmAvailable': true,
          'dayLimitMinutes': 300,
        };
      }),
      FakeRoute('POST', '/trips', (o) {
        final body = o.data as Map;
        return engineTripJson(
          TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)),
          extra: {'title': body['name'], 'nameChosen': true},
        );
      }),
      FakeRoute('PUT', '/trips/{id}', (o) {
        final body = o.data as Map;
        return engineTripJson(
          TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)),
          extra: {'title': body['name'] ?? 'Uttarakhand Hills Trip', 'nameChosen': true},
        );
      }),
    ]);
    expect(TripNewDraft.readName(), isNull);
    final c = TripPlanController();
    addTearDown(c.onClose);
    await c.startFromSelection(_nainital, [_spot('a'), _spot('b')]);
    expect(_sent(api, 'POST', '/trips')['name'], 'Uttarakhand Hills Trip');
    expect(c.title, 'Uttarakhand Hills Trip');

    c.plan.value = _twoCityPlan();
    expect(c.title, 'Uttarakhand Hills Trip');
    expect(await c.saveNow(), isTrue);
    final put = api.calls('PUT', '/trips/{id}'.replaceFirst('{id}', c.trip.value!.id));
    expect(put, isNotEmpty);
    final body = Map<String, dynamic>.from(put.last.data as Map);
    expect(body.containsKey('name'), isFalse);
    expect(body.containsKey('title'), isFalse);
    expect(c.title, 'Uttarakhand Hills Trip');
  });

  test('chosen_name_is_shown_as_is', () {
    final c = TripPlanController();
    addTearDown(c.onClose);
    final one = _onePlan();
    final oldDefault = TripStringsMcaA1.defaultTitle(['Nainital']);
    c.trip.value = TripModel.fromJson(engineTripJson(one, extra: {'title': oldDefault, 'nameChosen': true}));
    c.plan.value = _twoCityPlan();
    expect(c.title, oldDefault);
  });

  test('old_trip_title_still_follows_the_cities', () {
    final c = TripPlanController();
    addTearDown(c.onClose);
    final one = _onePlan();
    c.trip.value = TripModel.fromJson(engineTripJson(one, extra: {'title': TripStringsMcaA1.defaultTitle(['Nainital'])}));
    expect(c.trip.value!.nameChosen, isFalse);
    c.plan.value = _twoCityPlan();
    expect(c.title, TripStringsMcaA1.defaultTitle(['Nainital', 'Almora']));

    c.trip.value = TripModel.fromJson(engineTripJson(one, extra: {'title': 'My own old title'}));
    expect(c.title, 'My own old title');
  });

  testWidgets('name_and_customize_pages_are_registered_and_can_open', (t) async {
    expect(AppRoutes.isRegistered(AppRoutes.tripName), isTrue);
    expect(AppRoutes.isRegistered(AppRoutes.tripCustomize), isTrue);
    final auth = AuthController();
    expect(auth.canOpenRoute(AppRoutes.tripName), isTrue);
    expect(auth.canOpenRoute(AppRoutes.tripCustomize), isTrue);

    Map<dynamic, dynamic>? args;
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(411, 891);
    addTearDown(t.view.reset);
    await t.pumpWidget(GetMaterialApp(
      home: const Scaffold(body: SizedBox()),
      getPages: [
        GetPage(
          name: AppRoutes.tripCustomize,
          page: () {
            args = Get.arguments as Map?;
            return const Scaffold(body: Text('customize'));
          },
        ),
      ],
    ));
    TripNavigation.openCustomize(2);
    await t.pumpAndSettle();
    expect(find.text('customize'), findsOneWidget);
    expect(args, {'legIndex': 2});
  });
}
