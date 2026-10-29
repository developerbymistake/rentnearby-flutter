import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/plan_controller.dart';
import '../models/go_live_result.dart';
import '../utils/app_toast.dart';
import '../widgets/go_live_submitted_dialog.dart';
import '../widgets/go_live_success_dialog.dart';
import '../widgets/plan_limit_reached_sheet.dart';
import '../widgets/swap_live_sheet.dart';

class GoLiveFlow {
  GoLiveFlow._();

  static Future<void> run(
    BuildContext context, {
    required bool isPlot,
    required Color accent,
    required Future<GoLiveResult> Function() goLive,
    required Future<bool> Function(String pauseId) swap,
    required List<SwapOption> liveOptions,
    bool preferSwap = false,
  }) async {
    final plans = Get.find<PlanController>();
    if (preferSwap && liveOptions.isNotEmpty) {
      await plans.refreshPlan(force: true);
      if (!plans.hasRoomForLive) {
        if (!context.mounted) return;
        await _offerSwap(context, accent: accent, swap: swap, liveOptions: liveOptions);
        return;
      }
    }
    final result = await goLive();
    if (!context.mounted) return;
    final unit = isPlot ? 'plot' : 'room';
    switch (result) {
      case GoLiveSuccess():
        Get.dialog(
          GoLiveSuccessDialog(
            isPlot: isPlot,
            validUntil: result.validUntil,
            live: result.live,
            limit: result.limit,
            onDismiss: () {},
          ),
          barrierDismissible: false,
        );
      case GoLiveSubmittedForReview():
        Get.dialog(GoLiveSubmittedDialog(isPlot: isPlot, onDismiss: () {}), barrierDismissible: false);
      case GoLiveLimitReached():
        PlanLimitReachedSheet.show(
          context,
          limit: result.limit,
          unitSingular: unit,
          unitPlural: '${unit}s',
          accent: accent,
          liveLimit: true,
          onSwap: liveOptions.isEmpty
              ? null
              : () => _offerSwap(context, accent: accent, swap: swap, liveOptions: liveOptions),
        );
      case GoLivePausedByAdmin():
        AppToast.error(result.message);
      case GoLiveConcurrentUpdate():
        AppToast.error(result.message);
      case GoLiveFailure():
        AppToast.error(result.message);
    }
  }

  static Future<void> _offerSwap(
    BuildContext context, {
    required Color accent,
    required Future<bool> Function(String pauseId) swap,
    required List<SwapOption> liveOptions,
  }) async {
    final pauseId = await SwapLiveSheet.show(context, options: liveOptions, accent: accent);
    if (pauseId == null) return;
    if (await swap(pauseId)) {
      AppToast.success('Listing is live.');
    }
  }
}
