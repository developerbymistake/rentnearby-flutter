import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_tour_state.dart';
import '../config/tour_registry.dart';
import '../controllers/tour_controller.dart';
import 'tour_info_dialog.dart';
import 'tour_overlay.dart';

/// Permanently-mounted, purely reactive host for the coach-mark tour —
/// stacked as the topmost child of GetMaterialApp's own builder (see
/// main.dart), always present regardless of route/tab, rendering nothing
/// until TourController decides to show a step.
///
/// Deliberately reads only the bare top-level Rx vars in app_tour_state.dart
/// — never Get.find<TourController>() at build time — so this widget is safe
/// to mount before TourController is ever registered (splash/login/before
/// MainScreen mounts, since TourController is only Get.put inside
/// MainScreen.initState()). Get.find<TourController>() is only ever called
/// lazily, inside the onNext/onSkip tap callbacks below, which can only fire
/// while a step is actually showing — and a step can only be showing because
/// TourController itself set it, i.e. it's already registered by then.
///
/// One accepted trade-off: toasts (AppToast, used for this feature's own
/// error reporting) render via the Navigator's own Overlay, which lives
/// inside `child` — several layers below this widget's Stack position in
/// main.dart. A toast fired while a tour is visible paints underneath the
/// tour's scrim. In practice the only AppToast.error calls reachable while a
/// tour is showing are inside TourController._teardown's state-reset
/// try/catch, which fires in the same synchronous call that flips
/// tourInProgress false — at most a one-frame overlap before this widget
/// collapses to nothing. Not worth reordering for.
class TourHost extends StatelessWidget {
  const TourHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Checked first: dialog and spotlight step are mutually exclusive by
      // construction in TourController, but checking this one first means
      // even a future bug that briefly leaves both non-null fails safe
      // (shows the dialog, not a spotlight underneath a dialog).
      final dialog = tourDialogContent.value;
      if (dialog != null) {
        return TourInfoDialog(
          content: dialog,
          onPrimary: () => dialog.phase == TourDialogPhase.intro
              ? Get.find<TourController>().startTourFromIntro()
              : Get.find<TourController>().finishTour(),
          onSecondary: dialog.secondaryLabel == null
              ? null
              : () => Get.find<TourController>().skip(),
        );
      }
      final step = currentTourStep.value;
      if (step == null) return const SizedBox.shrink();
      return TourOverlay(
        step: step,
        index: tourStepIndex.value,
        total: tourTotalSteps.value,
        tourLabel: currentTourLabel.value,
        onNext: () => Get.find<TourController>().next(),
        onSkip: () => Get.find<TourController>().skip(),
      );
    });
  }
}
