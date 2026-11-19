import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/trip_routes.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/widgets/trip_not_found_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Trips extends MyTripsController {
  int loads = 0;
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async => loads++;
}

Future<void> _open(WidgetTester t, String? id) async {
  Get.put<TabConfigController>(_Tabs());
  await t.pumpWidget(GetMaterialApp(home: TripOverviewRoute(tripId: id)));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('overview_gone_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  testWidgets('a trip deleted on another phone shows Trip not found, not an endless loader', (t) async {
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', null, code: 404, errorType: 'TripNotFound')]);
    await _open(t, 'gone-1');
    expect(find.byType(TripNotFoundView), findsOneWidget);
    expect(find.text(TripStrings.tripNotFoundTitle), findsOneWidget);
  });

  testWidgets('Trip Planner turned off shows Not available right now', (t) async {
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', null, code: 403, errorType: 'TripPlannerDisabled')]);
    await _open(t, 'off-1');
    expect(find.text(TripStrings.plannerOff), findsOneWidget);
    expect(find.byType(StateCard), findsOneWidget);
  });

  testWidgets('a push with no trip id shows Trip not found', (t) async {
    installFakeApi(const []);
    await _open(t, null);
    expect(find.byType(TripNotFoundView), findsOneWidget);
  });

  testWidgets('closing the last trip page reloads My trips on every entry (summary, push), not only Continue', (t) async {
    installFakeApi([FakeRoute.value('GET', '/trips/{id}', null, code: 404, errorType: 'TripNotFound')]);
    final trips = _Trips();
    Get.put<MyTripsController>(trips);
    await _open(t, 'x-1');
    expect(trips.loads, 0);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(trips.loads, greaterThanOrEqualTo(1));
  });
}
