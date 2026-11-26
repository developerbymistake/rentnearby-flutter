import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_summary_controller.dart';
import 'package:bakhli/features/buddy/buddy_bindings.dart';
import 'package:bakhli/features/buddy/notices/controllers/notices_controller.dart';
import 'package:bakhli/features/buddy/offline/expense_queue_service.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_controller.dart';
import 'package:bakhli/features/seeker_home/seeker_home_bindings.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/enquiries/my_enquiry_count_controller.dart';
import 'package:bakhli/features/trip/traveller_session.dart';
import 'package:bakhli/navigation/traveller_gate.dart';
import 'package:bakhli/services/trip_push_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../support/owner_fakes.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Trips extends MyTripsController {
  int loads = 0;

  @override
  Future<void> load() async {
    loads++;
  }
}

class _Summary extends BuddySummaryController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Count extends MyEnquiryCountController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

_Auth _as(String role) {
  final a = _Auth();
  Get.put<AuthController>(a);
  a.roleKey.value = role;
  return a;
}

void main() {
  setUpAll(() => initTestStorage('owner_session_calls_test'));
  setUp(() {
    Get.testMode = true;
    OwnerSessionHooks.refreshHome = () async {};
  });
  tearDown(() {
    OwnerSessionHooks.refreshHome = () async {};
    Get.reset();
  });

  test('SeekerHomeBindings: an owner gets no seeker feed and no trips list', () {
    for (final role in [UserRoleKeys.stayOwner, UserRoleKeys.taxiDriver]) {
      Get.reset();
      _as(role);
      SeekerHomeBindings.ensure();
      expect(Get.isRegistered<SeekerFeedController>(), isFalse, reason: role);
      expect(Get.isRegistered<MyTripsController>(), isFalse, reason: role);
    }
  });

  test('the seeker feed condition is open for a seeker', () {
    _as(UserRoleKeys.seeker);
    expect(TravellerGate.allowed, isTrue);
  });

  test('BuddyBindings for a non-traveller registers the shared inbox only', () {
    _as(UserRoleKeys.stayOwner);
    BuddyBindings.ensure(traveller: false);
    expect(Get.isRegistered<NoticesController>(), isTrue);
    expect(Get.isRegistered<BuddySummaryController>(), isFalse);
    expect(Get.isRegistered<ExpenseQueueService>(), isFalse);
  });

  test('TripPushSync: a driver push never reloads My Trips for a driver', () {
    _as(UserRoleKeys.taxiDriver);
    final trips = _Trips();
    Get.put<MyTripsController>(trips);
    TripPushSync.refreshNow(AppRoutes.taxiRequests);
    expect(trips.loads, 0);
  });

  test('TripPushSync: the same push reloads My Trips for a seeker', () {
    _as(UserRoleKeys.seeker);
    final trips = _Trips();
    Get.put<MyTripsController>(trips);
    TripPushSync.refreshNow(AppRoutes.taxiRequests);
    expect(trips.loads, 1);
  });

  test('TravellerSession.clear removes traveller controllers and trip caches, keeps the city catalog', () {
    final box = GetStorage();
    box.write('trip_list_cache_u', '[]');
    box.write('trip_today_t1', '{}');
    box.write('trip_cities_cache', '{}');
    Get.put<MyTripsController>(MyTripsController(), permanent: true);
    Get.put<BuddySummaryController>(_Summary());
    Get.put<MyEnquiryCountController>(_Count());
    TravellerSession.clear();
    expect(Get.isRegistered<MyTripsController>(), isFalse);
    expect(Get.isRegistered<BuddySummaryController>(), isFalse);
    expect(Get.isRegistered<MyEnquiryCountController>(), isFalse);
    expect(box.hasData('trip_list_cache_u'), isFalse);
    expect(box.hasData('trip_today_t1'), isFalse);
    expect(box.hasData('trip_cities_cache'), isTrue);
  });
}
