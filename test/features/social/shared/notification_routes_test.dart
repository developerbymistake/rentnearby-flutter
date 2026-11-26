import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buddy list and trip view sit on top of main, so a push keeps a half-filled page below', () {
    for (final route in [AppRoutes.buddies, AppRoutes.tripView, AppRoutes.settings, AppRoutes.editProfile, AppRoutes.people, AppRoutes.dmRoom]) {
      expect(NotificationService.isOnTopOfMain(route), isTrue, reason: route);
    }
  });

  test('buddy list and trip view refresh in place when the push is for the open page', () {
    for (final route in [AppRoutes.buddies, AppRoutes.tripView, AppRoutes.people, AppRoutes.joinRequests]) {
      expect(NotificationService.refreshesInPlace(route), isTrue, reason: route);
    }
  });
}
