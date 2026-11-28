import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_strings_v2_plan.dart';

typedef TripSnackHandle = ScaffoldFeatureController<SnackBar, SnackBarClosedReason>;

abstract final class TripUndoSnack {
  static const Duration duration = Duration(seconds: 5);

  static ({ScaffoldMessengerState messenger, TripPlanController? plan, TripSnackHandle handle})? _live;

  // An action SnackBar that always times out. With [plan], Undo runs only while that controller is the live one.
  static TripSnackHandle? show(
    ScaffoldMessengerState? messenger,
    String text, {
    required VoidCallback onUndo,
    TripPlanController? plan,
    Duration duration = TripUndoSnack.duration,
    String actionLabel = TripStringsV2Plan.undo,
  }) {
    if (messenger == null || !messenger.mounted) return null;
    messenger.hideCurrentSnackBar();
    final handle = messenger.showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontFamily: FitnessAppTheme.fontName)),
        duration: duration,
        persist: false,
        action: SnackBarAction(
          label: actionLabel,
          onPressed: () {
            if (plan == null || isLive(plan)) onUndo();
          },
        ),
      ),
    );
    _live = (messenger: messenger, plan: plan, handle: handle);
    handle.closed.whenComplete(() {
      if (identical(_live?.handle, handle)) _live = null;
    });
    return handle;
  }

  // Context-free, safe from State.dispose(): clears the bar only when the last one shown here belongs to [plan].
  static void dismiss(TripPlanController plan) {
    final live = _live;
    if (live == null || !identical(live.plan, plan)) return;
    _live = null;
    final m = live.messenger;
    scheduleMicrotask(() {
      if (m.mounted) m.clearSnackBars();
    });
  }

  static bool isLive(TripPlanController c) =>
      !c.isClosed && Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), c);
}
