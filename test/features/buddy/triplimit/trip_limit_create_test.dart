import 'dart:io';

import 'package:bakhli/services/api_service.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/buddy/viewer/viewer_deps.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_dates_sheet.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../journeys/fake_api.dart';
import '../../../support/real_phone.dart';
import '../../trip/support/engine_rig.dart';

const _nainital = TripCityModel(cityKey: 1, name: 'Nainital', stateName: 'Uttarakhand', latitude: 29.4, longitude: 79.4);

TripSpotModel _spot(String id) => TripSpotModel.fromJson({
      'id': id,
      'name': id,
      'latitude': 29.4,
      'longitude': 79.4,
      'category': 'attraction',
      'visitMinutes': 60,
    });

FakeRoute _planRoute() => FakeRoute('POST', '/trips/plan', (o) {
      final body = o.data as Map;
      final ids = [for (final s in body['spots'] as List) (s as Map)['id'] as String];
      return {
        'days': [
          {'day': 1, 'spotIds': ids, 'visitMinutes': 120, 'totalMinutes': 150},
        ],
        'osrmAvailable': true,
        'dayLimitMinutes': 300,
      };
    });

Map<String, dynamic> _echo(RequestOptions o) {
  final body = o.data as Map;
  return engineTripJson(
    TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)),
    extra: {'title': body['name'], 'nameChosen': true},
  );
}

Map<String, dynamic> _full() => {
      'limit': 3,
      'count': 3,
      'trips': [
        {'id': 't1', 'title': 'Old Manali Trip', 'role': 'Owner', 'startDate': null, 'endDate': null, 'ownerName': null},
        {'id': 't2', 'title': 'Goa Trip', 'role': 'Viewer', 'startDate': null, 'endDate': null, 'ownerName': 'Aman'},
        {'id': 't3', 'title': 'Hills Trip', 'role': 'Owner', 'startDate': null, 'endDate': null, 'ownerName': null},
      ],
    };

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('trip_limit_gs').path);
    await GetStorage.init();
  });
  setUp(StorageService.clearTripNewDraft);
  tearDown(() {
    ViewerDeps.debugReset();
    Get.reset();
  });

  test('createNew answers limitReached with the parsed slots and creates nothing', () async {
    final api = installFakeApi([
      _planRoute(),
      FakeRoute.value('POST', '/trips', _full(), code: 409, errorType: 'TripLimitReached'),
    ]);
    final c = TripPlanController();
    addTearDown(c.onClose);
    await c.startFromSelection(_nainital, [_spot('a'), _spot('b')]);
    final r = await c.createNew(name: 'Family Hills', startDate: null, adults: 2, kids: 0);
    expect(r, TripCreateOutcome.limitReached);
    expect(c.limitSlots?.trips.length, 3);
    expect(c.limitSlots?.limit, 3);
    expect(c.isNewUnsaved, isTrue);
    expect(c.trip.value, isNull);
    expect(api.calls('POST', '/trips'), hasLength(1));
  });

  testWidgets('dates sheet shows the limit sheet and creates again after a leave', (t) async {
    Get.put<TabConfigController>(_Tabs());
    final okApi = FakeTripAdapter([
      _planRoute(),
      FakeRoute('POST', '/trips', _echo),
      FakeRoute.value('POST', '/trips/t2/leave', {'status': 'Left', 'hasShare': false}),
    ]);
    final fullApi = installFakeApi([
      _planRoute(),
      FakeRoute.value('POST', '/trips', _full(), code: 409, errorType: 'TripLimitReached'),
      FakeRoute('POST', '/trips/t2/leave', (o) {
        ApiService.dio.httpClientAdapter = okApi;
        return {'status': 'Left', 'hasShare': false};
      }),
    ]);
    final c = TripPlanController();
    Get.put<TripPlanController>(c, permanent: true);
    await t.runAsync(() => c.startFromSelection(_nainital, [_spot('a'), _spot('b')]));
    bool? result;
    await pumpPhone(
      t,
      Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(key: const ValueKey('open'), onPressed: () async => result = await TripDatesSheet.saveTrip(ctx), child: const Text('open')),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.enterText(find.descendant(of: find.byKey(TripDatesSheet.nameKey), matching: find.byType(EditableText)), 'Family Hills');
    await t.pump();
    await t.tap(find.byKey(TripDatesSheet.ctaKey));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Trip limit reached'), findsOneWidget);
    expect(fullApi.calls('POST', '/trips'), hasLength(1));

    await t.tap(find.byKey(const ValueKey('trip_limit_action_t2')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text('Leave').last);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(okApi.calls('POST', '/trips'), hasLength(1));
    expect(result, isTrue);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(minutes: 2));
  });
}
