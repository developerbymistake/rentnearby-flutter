import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_tour_state.dart';
import '../config/tour_registry.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../services/storage_service.dart';
import '../utils/app_toast.dart';
import '../utils/rx_safe_call.dart';
import '../utils/tour_target_ready.dart';

/// Coach-mark tour engine — one persistent singleton driving 4 independent,
/// one-time, first-visit tours (see tour_registry.dart). Purely a decision
/// engine: it decides WHEN a step (or, for Home, an intro/outro dialog) should
/// show and mutates the bare top-level Rx vars in app_tour_state.dart
/// (currentTourStep/tourStepIndex/tourTotalSteps/tourDialogContent/
/// tourInProgress). Rendering is entirely someone else's job — TourHost
/// (lib/widgets/tour_host.dart), permanently mounted in main.dart's builder,
/// reacts to those vars. This controller never touches an Overlay or
/// Navigator (deliberately: TourDismissObserver dismisses on any root-
/// Navigator push, so a real Dialog/showDialog would self-destruct the
/// instant it opened — see _showDialog).
///
/// Every ever() worker here goes through rxSafe(): GetX's stream dispatch
/// (get_rx/rx_stream/mini_stream.dart, FastList._notifyData) has no
/// exception isolation between listeners, and workers registered in
/// MainScreen.initState() run ahead of the Obx(IndexedStack) that only
/// subscribes during build() — an uncaught throw here would silently stop
/// that IndexedStack from ever rebuilding for a tab tap.
///
/// Running out of ready target widgets is never treated as "the tour is
/// done" — only Skip and Next-past-the-final-step mark a tour permanently
/// seen (see _teardown's markSeen). Everything else, including exhausting
/// the bounded retry in _searchForReadyStep, leaves the seen flag untouched
/// so the next natural trigger gets a fresh attempt.
class TourController extends GetxController {
  TourDefinition? _activeTour;
  int _retryAttempt = 0;
  int _generation = 0;

  static const int _maxFrameRetries = 2;
  static const int _totalRetryBudget = 4;
  static const Duration _delayedRetryGap = Duration(milliseconds: 500);
  static const Duration _preTourPause = Duration(milliseconds: 2000);

  late final AuthController _auth;
  late final LocationController _locationCtrl;

  Worker? _tabIndexWorker;
  Worker? _userWorker;
  Worker? _offlineWorker;
  Worker? _gpsWorker;
  Worker? _districtWorker;

  @override
  void onInit() {
    super.onInit();
    _auth = Get.find<AuthController>();
    _locationCtrl = Get.find<LocationController>();

    _tabIndexWorker = ever<int>(_auth.tabIndex, rxSafe('tour.tabIndex', (_) {
      if (tourInProgress.value) _teardown(markSeen: false);
      WidgetsBinding.instance.addPostFrameCallback((_) => attemptShowTourForCurrentTab());
    }));

    _userWorker = ever(_auth.user, rxSafe('tour.user', (u) {
      if (u == null && tourInProgress.value) _teardown(markSeen: false);
    }));

    _offlineWorker = ever(_locationCtrl.isOffline, rxSafe('tour.isOffline', (_) => _checkGatesAndDismiss()));
    _gpsWorker = ever(_locationCtrl.gpsEnabled, rxSafe('tour.gpsEnabled', (_) => _checkGatesAndDismiss()));
    _districtWorker = ever(_locationCtrl.districtUnavailable, rxSafe('tour.districtUnavailable', (_) => _checkGatesAndDismiss()));

    WidgetsBinding.instance.addPostFrameCallback((_) => attemptShowTourForCurrentTab());
  }

  @override
  void onClose() {
    _tabIndexWorker?.dispose();
    _userWorker?.dispose();
    _offlineWorker?.dispose();
    _gpsWorker?.dispose();
    _districtWorker?.dispose();
    try {
      _teardown(markSeen: false);
    } catch (_) {}
    super.onClose();
  }

  void _checkGatesAndDismiss() {
    if (tourInProgress.value && _locationCtrl.hasActiveGate) {
      _teardown(markSeen: false);
    }
  }

  /// Called by TourDismissObserver.didPush — any route pushed on the root
  /// Navigator while a tour is showing invalidates its spotlight target.
  void forceDismissForNavigation() {
    if (tourInProgress.value) _teardown(markSeen: false);
  }

  void attemptShowTourForCurrentTab() {
    if (tourInProgress.value) return;
    final tour = tourRegistry[_auth.tabIndex.value];
    if (tour == null) return;
    if (StorageService.getTourSeen(tour.storageKey)) return;
    if (_locationCtrl.hasActiveGate) return;

    // _activeTour is deliberately NOT set here — it's only assigned once
    // _beginTourAttempt actually re-validates after the pause, so there's no
    // window where _activeTour is set but nothing is guaranteed to happen.
    _retryAttempt = 0;
    _generation++;
    final generation = _generation;
    Future.delayed(_preTourPause, () => _beginTourAttempt(tour, generation));
  }

  // The single re-validation checkpoint after _preTourPause — up to half a
  // second has passed since attemptShowTourForCurrentTab's own checks, so
  // every one of them is re-checked here, plus one more: attemptShow's early
  // return for a tab with no registry entry (Explore/Profile) never bumps
  // _generation, so switching to such a tab during the pause wouldn't
  // otherwise invalidate this pending closure — IndexedStack keeps Home
  // mounted underneath, so without this check its dialog/spotlight could pop
  // up half a second later while the user is looking at a different tab.
  void _beginTourAttempt(TourDefinition tour, int generation) {
    if (generation != _generation) return;
    if (tourInProgress.value) return;
    if (StorageService.getTourSeen(tour.storageKey)) return;
    if (_locationCtrl.hasActiveGate) return;
    if (_auth.user.value == null) return;
    if (_auth.tabIndex.value != tour.tabIndex) return;

    _activeTour = tour;
    final intro = tour.introContent;
    if (intro != null) {
      _showDialog(intro);
      return;
    }
    _searchForReadyStep(0, generation);
  }

  /// The intro dialog's "Start Tour" — resumes into the exact same
  /// step-picking entry point _beginTourAttempt uses when there's no intro.
  void startTourFromIntro() {
    final tour = _activeTour;
    if (tour == null || tourDialogContent.value == null) return;
    tourDialogContent.value = null;
    _retryAttempt = 0;
    _generation++;
    _searchForReadyStep(0, _generation);
  }

  /// The outro dialog's "Start Exploring" — the actual markSeen:true moment
  /// for a tour that has an outro (deferred from next()'s final-step branch).
  void finishTour() {
    if (_activeTour == null || tourDialogContent.value == null) return;
    _teardown(markSeen: true);
  }

  void next() {
    final tour = _activeTour;
    if (tour == null) return;
    if (tourStepIndex.value >= tour.steps.length - 1) {
      // Already on the physically final step — this is the user finishing.
      final outro = tour.outroContent;
      if (outro != null) {
        _showDialog(outro);
        return;
      }
      _teardown(markSeen: true);
      return;
    }
    _retryAttempt = 0;
    _generation++;
    _searchForReadyStep(tourStepIndex.value + 1, _generation);
  }

  void skip() => _teardown(markSeen: true);

  void _showDialog(TourDialogContent content) {
    currentTourStep.value = null; // dialog and spotlight are mutually exclusive
    tourDialogContent.value = content;
    tourInProgress.value = true;
  }

  // [generation] pins a retry chain to the specific attempt that scheduled
  // it. Re-reading _activeTour instead of comparing generations would be
  // insufficient here: once a newer attempt reassigns _activeTour to a
  // different tour, a stale closure from an OLDER attempt would silently
  // start comparing itself against that NEW tour and could corrupt its
  // in-flight retry/step state — comparing tabIndex alone can't detect this,
  // since the new tour's tabIndex trivially matches by construction.
  void _searchForReadyStep(int fromIndex, int generation) {
    if (generation != _generation) return; // superseded by a newer attempt
    final tour = _activeTour;
    if (tour == null) return;
    // hasActiveGate is only checked once at attemptShowTourForCurrentTab's
    // entry — the bounded retry below can span close to a second, and if
    // offline/GPS/district goes bad mid-retry, showing the tour anyway would
    // visually cover MainScreen's own gate (TourHost sits above MainScreen's
    // entire Stack). Re-check on every attempt, not just the first.
    if (_locationCtrl.hasActiveGate) {
      _teardown(markSeen: false);
      return;
    }
    // Same reasoning as hasActiveGate above, for logout: the user-worker only
    // tears down if tourInProgress is already true. A retry pending across a
    // logout would otherwise still find a ready target and set currentTourStep
    // — and since TourHost lives in main.dart's builder, outliving MainScreen,
    // the tour would render on top of the login screen.
    if (_auth.user.value == null) {
      _teardown(markSeen: false);
      return;
    }

    for (var i = fromIndex; i < tour.steps.length; i++) {
      if (isTourTargetReady(tour.steps[i].key)) {
        tourTotalSteps.value = tour.steps.length;
        currentTourLabel.value = tour.label;
        _showStepAt(i);
        return;
      }
    }

    if (_retryAttempt >= _totalRetryBudget) {
      _teardown(markSeen: false);
      return;
    }
    _retryAttempt++;
    if (_retryAttempt <= _maxFrameRetries) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchForReadyStep(fromIndex, generation));
    } else {
      Future.delayed(_delayedRetryGap, () => _searchForReadyStep(fromIndex, generation));
    }
  }

  void _showStepAt(int idx) {
    final tour = _activeTour;
    if (tour == null) return;
    tourDialogContent.value = null; // dialog and spotlight are mutually exclusive
    tourStepIndex.value = idx;
    currentTourStep.value = tour.steps[idx];
    tourInProgress.value = true;
  }

  void _teardown({required bool markSeen}) {
    // Bumped unconditionally, even though every reachable caller already
    // guards on tourInProgress/state — cheap insurance against a future
    // teardown trigger being added that doesn't, per the same reasoning
    // that makes generation checks matter in _searchForReadyStep.
    _generation++;

    final tour = _activeTour;
    _activeTour = null;
    _retryAttempt = 0;

    try {
      currentTourStep.value = null;
      tourStepIndex.value = 0;
      tourTotalSteps.value = 0;
      currentTourLabel.value = '';
      tourDialogContent.value = null;
      tourInProgress.value = false;
    } catch (e) {
      AppToast.error('Tour: teardown state reset threw: $e');
    }

    if (markSeen && tour != null) {
      try {
        StorageService.saveTourSeen(tour.storageKey);
      } catch (e) {
        AppToast.error('Tour: saving seen-flag failed: $e');
      }
    }
  }
}
