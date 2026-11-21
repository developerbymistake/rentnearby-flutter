import 'package:flutter/foundation.dart';

import '../config/user_roles.dart';
import '../utils/jwt_claims.dart';
import 'storage_service.dart';

class TaxiRingEnd {
  const TaxiRingEnd(this.offerId, this.reason);

  final String offerId;
  final String? reason;
}

class TaxiRingSession {
  TaxiRingSession._();

  static final ValueNotifier<TaxiRingEnd?> ended = ValueNotifier<TaxiRingEnd?>(null);

  static void reset() => ended.value = null;

  static bool isDriverToken(String? token) => JwtClaims.role(token) == UserRoleKeys.taxiDriver;

  // The background isolate must run StorageService.init() first.
  static Future<bool> isDriver() async {
    try {
      return isDriverToken(StorageService.getToken());
    } catch (_) {
      return false;
    }
  }

  static Future<bool> accepts(String? driverUserId) async {
    try {
      final token = StorageService.getToken();
      if (!isDriverToken(token)) return false;
      if (driverUserId == null || driverUserId.isEmpty) return true;
      final me = JwtClaims.userId(token) ?? StorageService.getUser()?.id;
      return me != null && me.toLowerCase() == driverUserId.toLowerCase();
    } catch (_) {
      return false;
    }
  }
}
