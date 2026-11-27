import 'package:flutter/foundation.dart';

import '../config/user_roles.dart';
import '../utils/jwt_claims.dart';
import 'storage_service.dart';
import 'taxi_ring_service.dart' show RingRole;

class TaxiRingEnd {
  const TaxiRingEnd(this.offerId, this.reason, {this.role = RingRole.taxi});

  /// The taxi offer id, or the enquiry id of a stay ring.
  final String offerId;
  final String? reason;
  final RingRole role;
}

class TaxiRingRelaunch {
  TaxiRingRelaunch(this.offerId);

  final String offerId;
}

class TaxiRingSession {
  TaxiRingSession._();

  static final ValueNotifier<TaxiRingEnd?> ended = ValueNotifier<TaxiRingEnd?>(null);

  // A ring launch for the offer whose ring screen is already open; the screen holds again so the native cover lifts.
  static final ValueNotifier<TaxiRingRelaunch?> relaunched = ValueNotifier<TaxiRingRelaunch?>(null);

  static void reset() {
    ended.value = null;
    relaunched.value = null;
  }

  static bool isDriverToken(String? token) => JwtClaims.role(token) == UserRoleKeys.taxiDriver;

  // The background isolate must run StorageService.init() first.
  static Future<bool> isDriver() async {
    try {
      return isDriverToken(StorageService.getToken());
    } catch (_) {
      return false;
    }
  }

  static Future<bool> accepts(String? driverUserId) => _accepts(UserRoleKeys.taxiDriver, driverUserId);

  static bool isStayOwnerToken(String? token) => JwtClaims.role(token) == UserRoleKeys.stayOwner;

  // A stay ring for another account or a non Stay Owner session (role changed, logged out) never shows.
  static Future<bool> acceptsStay(String? ownerUserId) => _accepts(UserRoleKeys.stayOwner, ownerUserId);

  static Future<bool> _accepts(String role, String? userId) async {
    try {
      final token = StorageService.getToken();
      if (JwtClaims.role(token) != role) return false;
      if (userId == null || userId.isEmpty) return true;
      final me = JwtClaims.userId(token) ?? StorageService.getUser()?.id;
      return me != null && me.toLowerCase() == userId.toLowerCase();
    } catch (_) {
      return false;
    }
  }
}
