import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/notification_types.dart';
import 'package:bakhli/features/stay_owner/ring/stay_ring_screen.dart';
import 'package:bakhli/features/stay_owner/stay_owner_tabs.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

String _read(String path) => File(path).readAsStringSync().replaceAll(String.fromCharCode(13), '');

class _Svc extends GetxService implements NotificationService {
  final opened = <(String, Map<String, dynamic>?)>[];
  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  void openActionRoute(String route, Map<String, dynamic>? args) => opened.add((route, args));
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

String _fn(String src, String head) {
  final start = src.indexOf(head);
  expect(start, greaterThan(0), reason: head);
  return src.substring(start, src.indexOf('\n  }\n', start));
}

void main() {
  final notif = _read('lib/services/notification_service.dart');

  test('UC10 native lock screen launch accepts the stay ring payload the app builds', () {
    final kt = _read('android/app/src/main/kotlin/com/rentnearby/rentnearby/MainActivity.kt');
    final push = TaxiRingPush.tryParse({
      'kind': 'stay_ring',
      'v': '1',
      'enquiryId': 'e1',
      'expiresAt': '2026-12-10T09:46:07Z',
    })!;
    final data = TaxiRingNotification.routeData(push);
    expect(kt, contains('private const val STAY_RING_TYPE = "${data['notification_type']}"'));
    expect(kt, contains('private const val STAY_RING_ROUTE = "${TaxiRingPush.stayRingRoute}"'));
    expect(kt, contains('payload.optString("notification_type") == STAY_RING_TYPE && payload.optString("action_route") == STAY_RING_ROUTE'));
    expect(kt, contains('payload.optString("notification_type") == RING_TYPE && payload.optString("action_route") == RING_ROUTE'));
    expect('setRingAlert(true)'.allMatches(kt).length, 1);
  });

  test('stay ring routes are Stay Owner routes on top of main', () {
    expect(AppRoutes.stayEnquiryRing, TaxiRingPush.stayRingRoute);
    expect(AppRoutes.stayOwnerNewRoutes, containsAll([AppRoutes.stayEnquiryRing, AppRoutes.stayRingReady]));
    expect(AppRoutes.stayOwnerOnly, containsAll([AppRoutes.stayEnquiryRing, AppRoutes.stayRingReady]));
    expect(AppRoutes.isRegistered(AppRoutes.stayEnquiryRing), isTrue);
    expect(AppRoutes.isRegistered(AppRoutes.stayRingReady), isTrue);
    expect(NotificationService.isOnTopOfMain(AppRoutes.stayEnquiryRing), isTrue);
    expect(NotificationService.isOnTopOfMain(AppRoutes.stayRingReady), isTrue);
    expect(AppRoutes.travellerOnly.contains(AppRoutes.stayEnquiryRing), isFalse);
  });

  test('wire names match the server', () {
    expect(TaxiRingNotification.stayRingType, 'stay_enquiry_ring');
    expect(NotificationTypeKeys.stayEnquiryRingWire, 'stay_enquiry_ring');
    expect(NotificationTypeKeys.stayEnquiryRingMissedWire, 'stay_enquiry_ring_missed');
    expect(NotificationTypeKeys.isOwnerWork(NotificationTypeKeys.stayEnquiryRingMissedWire), isTrue);
    expect(TaxiRingNotification.stayRingChannelId, 'stay_enquiry_ring_v1');
    expect(TaxiRingNotification.stayUpdatesChannelId, 'stay_enquiry_updates_v1');
  });

  test('UC6 Decline on a stay ring makes no server call', () {
    final decline = _fn(notif, 'void _declineStayRing(');
    expect(decline, isNot(contains('ApiService')));
    expect(decline, isNot(contains('OwnerApi')));
    expect(decline, isNot(contains('StayRingApi')));
    expect(decline, isNot(contains('_dispatchNotificationRoute')));
    expect(decline, contains('_localNotifications.cancel('));
    expect(decline, contains('StayRingEnds.declinedHere'));
    final tap = _fn(notif, 'void _openRingTap(');
    expect(tap, contains('if (stay && actionId == TaxiRingNotification.declineAction) return _declineStayRing(id, tag);'));
    expect(tap, contains('auth.canOpenRoute(stay ? TaxiRingPush.stayRingRoute : TaxiRingPush.ringRoute)'));
    final screen = _read('lib/features/stay_owner/ring/stay_ring_screen.dart');
    final screenDecline = _fn(screen, 'Future<void> _decline()');
    expect(screenDecline, isNot(contains('StayRingApi')));
    expect(screen, isNot(contains("'Declined'")));
  });

  test('UC10 the stay channels are created at start and in the background isolate', () {
    final init = _fn(notif, 'Future<void> _initLocalNotifications()');
    expect(init, contains('createNotificationChannel(TaxiRingNotification.stayRingChannel)'));
    expect(init, contains('createNotificationChannel(TaxiRingNotification.stayUpdatesChannel)'));
    expect(notif, contains('createNotificationChannel(TaxiRingNotification.ringChannelFor(ring.role))'));
  });

  test('UC4 the stay ring adds no write to the enquiry code', () {
    for (final f in Directory('lib/features/stay_owner/ring').listSync().whereType<File>()) {
      final src = f.readAsStringSync();
      expect(src, isNot(contains('TripEnquiryRepository')), reason: f.path);
      expect(src, isNot(contains('StayEnquiriesController')), reason: f.path);
      expect(src, isNot(contains('/trips/enquiries')), reason: f.path);
    }
  });

  test('UC14 the ring screen reads no phone field', () {
    final screen = _read('lib/features/stay_owner/ring/stay_ring_screen.dart');
    final service = _read('lib/services/taxi_ring_service.dart');
    for (final src in [screen, service]) {
      expect(src.toLowerCase(), isNot(contains("'phone")));
      expect(src, isNot(contains('travellerPhone')));
    }
  });

  test('UC5 Accept opens the Enquiries tab on that enquiry through the existing push route', () {
    Get.reset();
    Get.testMode = true;
    final svc = _Svc();
    Get.put<NotificationService>(svc, permanent: true);
    addTearDown(Get.reset);
    StayRingScreen.openEnquiry('e1');
    expect(svc.opened, hasLength(1));
    expect(svc.opened.single.$1, AppRoutes.stayEnquiries);
    expect(svc.opened.single.$2, {'enquiryId': 'e1'});
    expect(StayOwnerTabs.tabForRoute(AppRoutes.stayEnquiries, {'enquiryId': 'e1'}), AppTabs.centre);
    final screen = _read('lib/features/stay_owner/ring/stay_ring_screen.dart');
    final accept = _fn(screen, 'Future<void> _accept()');
    expect(accept, contains('await _stopRing();'));
    expect(accept, contains('StayRingScreen.openEnquiry(_id);'));
    expect(accept, isNot(contains('TripEnquiryRepository')));
  });
}
