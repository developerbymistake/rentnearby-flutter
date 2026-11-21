import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../shared/buddy_result.dart';
import 'trip_limit_api.dart';
import 'trip_limit_models.dart';
import 'trip_limit_sheet.dart';
import 'trip_limit_strings.dart';

abstract final class TripLimitGate {
  static TripLimitApi api = const TripLimitApi();

  static void debugReset() => api = const TripLimitApi();

  static Future<bool> ensureSlot([BuildContext? context]) async {
    final r = await api.slots();
    if (r is! BuddyOk<TripSlots> || !r.value.isFull) return true;
    final ctx = context ?? Get.context;
    if (ctx == null || !ctx.mounted) return true;
    return TripLimitSheet.show(ctx, r.value, reason: TripLimitReason.plan);
  }

  static Future<bool> promptInvite(TripSlots slots, [BuildContext? context]) async {
    final ctx = context ?? Get.context;
    if (ctx == null || !ctx.mounted) return false;
    return TripLimitSheet.show(ctx, slots, reason: TripLimitReason.invite);
  }
}
