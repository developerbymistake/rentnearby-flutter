import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/services/trip_push_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    OwnerSessionHooks.refreshHome = () async {};
    Get.reset();
  });

  test('FX-19 a burst of trip enquiry pushes reloads the owner Home once', () async {
    var homeLoads = 0;
    OwnerSessionHooks.refreshHome = () async => homeLoads++;
    TripPushSync.onPush('TripEnquiryCreated', null);
    TripPushSync.onPush('trip_enquiry_created', null);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    expect(homeLoads, 1);
  });

  test('FX-19 a driver push reloads the driver Home once', () async {
    var homeLoads = 0;
    OwnerSessionHooks.refreshHome = () async => homeLoads++;
    TripPushSync.onPush('taxi_selected', null);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    expect(homeLoads, 1);
  });

  test('a non-trip push reloads nothing', () async {
    var homeLoads = 0;
    OwnerSessionHooks.refreshHome = () async => homeLoads++;
    TripPushSync.onPush('broadcast', null);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    expect(homeLoads, 0);
  });
}
