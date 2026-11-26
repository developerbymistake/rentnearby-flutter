import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/buddy/buddy_routes.dart';
import 'package:bakhli/features/trip/trip_routes.dart';
import 'package:bakhli/navigation/traveller_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';

enum _Who { seeker, stay, taxi, unknown }

void main() {
  setUpAll(() => initTestStorage('traveller_route_table_test'));
  late FakeAuth auth;

  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    auth = FakeAuth();
    Get.put<AuthController>(auth);
  });
  tearDown(Get.reset);

  void as(_Who who) => switch (who) {
        _Who.seeker => auth.signIn(role: UserRoleKeys.seeker),
        _Who.stay => auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved'),
        _Who.taxi => auth.signIn(role: UserRoleKeys.taxiDriver, taxiStatus: 'Approved'),
        _Who.unknown => auth.signIn(role: 'SOMETHING_NEW'),
      };

  test('travellerOnly is exactly the trip pages, the buddy pages and the two journey pages', () {
    final want = {
      for (final p in tripPages) p.name,
      for (final p in buddyPages) p.name,
      AppRoutes.myJourneys,
      AppRoutes.savedJourney,
    };
    expect(AppRoutes.travellerOnly, want);
    expect(AppRoutes.travellerOnly, hasLength(27));
  });

  test('every traveller route opens for a seeker only', () {
    for (final r in AppRoutes.travellerOnly) {
      for (final (who, open) in [(_Who.seeker, true), (_Who.stay, false), (_Who.taxi, false), (_Who.unknown, false)]) {
        as(who);
        expect(auth.canOpenRoute(r), open, reason: '$r as $who');
      }
    }
  });

  test('owner and shared routes still open for their role', () {
    as(_Who.taxi);
    for (final r in [AppRoutes.tripLeads, AppRoutes.taxiRequests, AppRoutes.taxiRequestDetail, AppRoutes.taxiBookings, AppRoutes.taxiRating, AppRoutes.taxiReady]) {
      expect(auth.canOpenRoute(r), isTrue, reason: r);
    }
    as(_Who.stay);
    for (final r in [AppRoutes.stayEnquiries, AppRoutes.myStays, AppRoutes.stayShareDetails]) {
      expect(auth.canOpenRoute(r), isTrue, reason: r);
    }
    for (final who in [_Who.seeker, _Who.stay, _Who.taxi]) {
      as(who);
      for (final r in [
        AppRoutes.chatConversation,
        AppRoutes.chatsList,
        AppRoutes.notifications,
        AppRoutes.stayDetail,
        AppRoutes.taxiDetail,
        AppRoutes.taxiWays,
        AppRoutes.journeyPlan,
        AppRoutes.journeyRoad,
      ]) {
        expect(auth.canOpenRoute(r), isTrue, reason: '$r as $who');
      }
    }
  });

  test('travellerOnly shares no route with the owner sets', () {
    expect(AppRoutes.travellerOnly.intersection(AppRoutes.ownerOnly), isEmpty);
    expect(AppRoutes.travellerOnly.intersection(AppRoutes.stayOwnerOnly), isEmpty);
    expect(AppRoutes.travellerOnly.intersection(AppRoutes.taxiDriverOnly), isEmpty);
  });

  test('each traveller page carries exactly one TravellerOnlyMiddleware, no other page has one', () {
    for (final p in AppRoutes.routes) {
      final n = (p.middlewares ?? const []).whereType<TravellerOnlyMiddleware>().length;
      expect(n, AppRoutes.travellerOnly.contains(p.name) ? 1 : 0, reason: p.name);
    }
    for (final r in AppRoutes.travellerOnly) {
      expect(AppRoutes.routes.where((p) => p.name == r), hasLength(1), reason: r);
    }
  });
}
