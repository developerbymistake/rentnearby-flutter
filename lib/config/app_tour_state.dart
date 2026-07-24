import 'package:get/get.dart';
import 'tour_registry.dart';

/// True while any coach-mark tour overlay is showing. Widgets with an
/// attention-grabbing animation (PulseOnce) pause while true so they don't
/// compete with the tour's own spotlight.
final RxBool tourInProgress = false.obs;

/// These three plus [tourInProgress] together are "is a tour showing, and if
/// so, on which step" — owned here rather than by TourController so a
/// permanently-mounted widget (TourHost, in main.dart) can read them via Obx
/// without depending on TourController being registered yet (it's only
/// Get.put from inside MainScreen.initState()). Same rationale as
/// tourInProgress above.
final Rxn<TourStep> currentTourStep = Rxn<TourStep>();
final RxInt tourStepIndex = 0.obs;
final RxInt tourTotalSteps = 0.obs;

/// The active tour's display name (e.g. 'Home Tour'), used only to render
/// the "HOME TOUR · 1 OF 5" eyebrow label above each step's title — the
/// "N OF M" part is computed at render time from tourStepIndex/tourTotalSteps
/// above, never hand-authored per step.
final RxString currentTourLabel = ''.obs;

/// Non-null exactly while the active tour's intro or outro dialog is
/// showing — mutually exclusive with currentTourStep by construction
/// (TourController never sets both; TourHost checks this one first). Bare
/// top-level like currentTourStep above, same rationale.
final Rxn<TourDialogContent> tourDialogContent = Rxn<TourDialogContent>();
