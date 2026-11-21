import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../design/design.dart';
import '../../utils/app_toast.dart';
import 'controllers/trip_plan_controller.dart';
import 'controllers/trip_taxi_request_controller.dart';
import 'models/taxi_request_models.dart';
import 'models/trip_enquiry_model.dart';
import 'models/trip_plan_result_model.dart';
import 'screens/my_trips_screen.dart';
import 'screens/trip_customize_screen.dart';
import 'screens/trip_map_screen.dart';
import 'screens/trip_overview_screen.dart';
import 'screens/trip_plan_screen.dart';
import 'screens/trip_taxi_request_screen.dart';
import 'screens/trip_taxi_request_status_screen.dart';
import 'screens/trip_replies_screen.dart';
import 'screens/trip_spots_screen.dart';
import 'screens/trip_stay_screen.dart';
import 'screens/trip_where_screen.dart';
import '../buddy/sharing/widgets/owner_overview_seam.dart';
import 'trip_navigation.dart';
import 'trip_strings.dart';
import 'utils/taxi_result.dart';
import 'widgets/taxi_request/taxi_day_rows.dart';
import 'widgets/trip_exit_confirm.dart';
import 'widgets/trip_not_found_view.dart';

Map<dynamic, dynamic> _args() {
  final a = Get.arguments;
  return a is Map ? a : const {};
}

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;

final List<GetPage> tripPages = [
  GetPage(
    name: AppRoutes.tripCustomize,
    page: () {
      final a = _args();
      final leg = a['legIndex'] ?? a['leg'];
      final toast = a['toast'];
      return TripCustomizeScreen(legIndex: leg is int ? leg : null, toast: toast is TripCustomizeToast ? toast : null);
    },
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripOverview,
    page: () => TripOverviewRoute(tripId: _text(_args()['tripId'])),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripTaxiRequest,
    page: () {
      final a = _args();
      return TripTaxiRequestRoute(tripId: _text(a['tripId']), keepChoices: a['keepChoices'] != false);
    },
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripTaxiStatus,
    page: () {
      final a = _args();
      return TripTaxiStatusRoute(tripId: _text(a['tripId']), requestId: _text(a['requestId']));
    },
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripWhere,
    page: () => const TripWhereScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripSpots,
    page: () => const TripSpotsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripPlan,
    page: () => const TripPlanScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripStay,
    page: () => const TripStayScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripMap,
    page: () => const TripMapScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.myTrips,
    page: () => const MyTripsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.tripReplies,
    page: () => const TripRepliesScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
];

Widget _loadingPage() => Scaffold(
      backgroundColor: DesignColors.surface,
      body: Center(child: KitDots(color: ListingTone.indigo.g2)),
    );

// Keeps the trip of [heldTripId] open in TripPlanController while a taxi page shows it.
mixin _HoldsTrip<T extends StatefulWidget> on State<T> {
  late final TripPlanController _plan = TripPlanController.to;

  String? get heldTripId;

  bool _holds(String? id) {
    final t = _plan.trip.value;
    return t != null && (id == null || t.id == id) && _plan.plan.value != null;
  }

  void holdTrip() {
    _plan.openPages++;
    final id = heldTripId;
    if (id != null && !_holds(id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_holds(id) && !_plan.isOpening.value) _plan.open(id);
      });
    }
  }

  void releaseTrip() {
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
  }

  bool get _thisTrip {
    final id = heldTripId;
    return id == null || _plan.openingId == id || _plan.trip.value?.id == id;
  }

  bool get heldGone => _plan.tripGone.value && _thisTrip;

  Widget heldOrLoading(Widget Function() child) {
    final id = heldTripId;
    if (heldGone) {
      return Scaffold(
        backgroundColor: DesignColors.surface,
        body: SafeArea(child: ListView(children: const [TripNotFoundView()])),
      );
    }
    if (_plan.plannerOff.value && _thisTrip) {
      return Scaffold(
        backgroundColor: DesignColors.surface,
        body: Center(
          child: StateCard(
            asset: TravelIcon.route,
            title: TripStrings.plannerOff,
            message: TripStrings.plannerOffSubtitle,
            actionLabel: TripStrings.myTripsAction,
            onAction: TripNavigation.openTripsTab,
            layout: StateLayout.plain,
          ),
        ),
      );
    }
    if (_holds(id)) return child();
    if (id == null && !_plan.isOpening.value) {
      return Scaffold(
        backgroundColor: DesignColors.surface,
        body: SafeArea(child: ListView(children: const [TripNotFoundView()])),
      );
    }
    if (_plan.openFailed.value && id != null) {
      return Scaffold(
        backgroundColor: DesignColors.surface,
        body: Center(
          child: StateCard.error(
            title: TripStrings.tripFailed,
            message: TripStrings.checkConnection,
            actionLabel: TripStrings.retry,
            onAction: () => _plan.open(id),
            layout: StateLayout.plain,
          ),
        ),
      );
    }
    return _loadingPage();
  }
}

class TripOverviewRoute extends StatefulWidget {
  const TripOverviewRoute({super.key, required this.tripId});

  final String? tripId;

  @override
  State<TripOverviewRoute> createState() => _TripOverviewRouteState();
}

class _TripOverviewRouteState extends State<TripOverviewRoute> with _HoldsTrip {
  @override
  String? get heldTripId => widget.tripId;

  @override
  void initState() {
    super.initState();
    holdTrip();
  }

  @override
  void dispose() {
    OwnerOverviewSeam.release(widget.tripId);
    releaseTrip();
    super.dispose();
  }

  void _viewPlan(String tripId) => Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId});

  bool _askingExit = false;
  bool _stayBusy = false;

  Future<void> _stay() async {
    if (_stayBusy) return;
    _stayBusy = true;
    try {
      await TripNavigation.openStayFlow(context);
    } finally {
      _stayBusy = false;
    }
  }

  String? _cityOf(TripEnquiryModel e) {
    final p = _plan.plan.value;
    final d = e.day;
    return p == null || d == null ? null : p.cityNameOf(d);
  }

  Future<void> _exit() async {
    if (!_holds(heldTripId) || heldGone || _plan.plannerOff.value) {
      TripNavigation.openTripsTab();
      return;
    }
    if (_askingExit) return;
    _askingExit = true;
    try {
      if (await TripExitConfirm.ask(context)) TripNavigation.openTripsTab();
    } finally {
      _askingExit = false;
    }
  }

  void _taxi(TripOverviewTaxi taxi) {
    final t = _plan.trip.value;
    if (t == null) return;
    final ref = t.taxiRequest;
    if (taxi.hasRequest && ref != null) {
      TripNavigation.openTaxiStatus(tripId: t.id, requestId: ref.requestId);
    } else {
      TripNavigation.openTaxiRequest(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exit();
        },
        child: Obx(() {
          _plan.openFailed.value;
          _plan.enquiryList.length;
          final paused = Get.isRegistered<TripTaxiRequestController>() && Get.find<TripTaxiRequestController>().paused.value;
          return heldOrLoading(() {
            final t = _plan.trip.value!;
            final parts = _plan.parts;
            final showStay = !_plan.stayTabOff.value;
            final extras = OwnerOverviewSeam.of(context, t, progressPercent: parts.percent);
            return TripOverviewScreen(
              trip: t,
              parts: parts,
              subtitle: extras.subtitle,
              travellerCount: extras.travellerCount,
              extraCards: extras.extraCards,
              extraMenuItems: extras.extraMenuItems,
              compactCards: extras.compactCards,
              progressLine: extras.progressLine,
              showProgress: extras.showProgress,
              highlight: TripOverviewScreen.highlightOf(parts, showStay: showStay),
              paused: paused,
              taxiCanRate: _plan.taxiCanRate,
              onBack: () => Navigator.maybePop(context),
              onViewPlan: () => _viewPlan(t.id),
              onTaxi: _taxi,
              stay: TripOverviewStay.of(_plan.enquiryList, cityOf: _cityOf),
              showStay: showStay,
              onStay: (_) => _stay(),
              onDone: TripNavigation.openTripsTab,
            );
          });
        }),
      );
}

class TripTaxiRequestRoute extends StatefulWidget {
  const TripTaxiRequestRoute({super.key, required this.tripId, this.keepChoices = true});

  final String? tripId;
  final bool keepChoices;

  @override
  State<TripTaxiRequestRoute> createState() => _TripTaxiRequestRouteState();
}

class _TripTaxiRequestRouteState extends State<TripTaxiRequestRoute> with _HoldsTrip {
  final TripTaxiRequestController _req = TripTaxiRequestController.to;

  @override
  String? get heldTripId => widget.tripId;

  @override
  void initState() {
    super.initState();
    if (!widget.keepChoices) _req.form.value = null;
    holdTrip();
  }

  @override
  void dispose() {
    releaseTrip();
    super.dispose();
  }

  List<TaxiDayStat> _stats() => [
        for (final d in _plan.result.value?.days ?? const <TripPlanDay>[])
          TaxiDayStat(day: d.day, km: d.km.round().clamp(0, 2000).toInt(), minutes: d.totalMinutes.clamp(0, 1440).toInt()),
      ];

  @override
  Widget build(BuildContext context) => Obx(() {
        _plan.openFailed.value;
        _plan.result.value;
        return heldOrLoading(() {
          final t = _plan.trip.value!;
          final stats = _stats();
          return TripTaxiRequestScreen(
            controller: _req,
            tripId: t.id,
            rows: TaxiRequestDayRow.fromPlan(_plan.plan.value!, stats: stats),
            dayStats: stats,
            onSent: (r) => TripNavigation.openTaxiStatus(tripId: r.tripId, requestId: r.id, replace: true),
            onTryAnotherCity: TripNavigation.backToPlan,
          );
        });
      });
}

class TripTaxiStatusRoute extends StatefulWidget {
  const TripTaxiStatusRoute({super.key, required this.tripId, required this.requestId});

  final String? tripId;
  final String? requestId;

  @override
  State<TripTaxiStatusRoute> createState() => _TripTaxiStatusRouteState();
}

class _TripTaxiStatusRouteState extends State<TripTaxiStatusRoute> {
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _requestId = widget.requestId ?? _fromPlan();
    if (_requestId == null) WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final tripId = widget.tripId;
    if (tripId != null) {
      var res = await TripTaxiRequestController.to.loadForTrip(tripId);
      if (res case TaxiRefused(rateLimited: true, :final retryAfterSeconds) when mounted) {
        await Future<void>.delayed(Duration(seconds: retryAfterSeconds ?? 1));
        if (!mounted) return;
        res = await TripTaxiRequestController.to.loadForTrip(tripId);
      }
      if (!mounted) return;
      final r = res.valueOrNull;
      if (r != null && r.tripId == tripId) {
        setState(() => _requestId = r.id);
        return;
      }
      if (res is! TaxiOk && res is! TaxiNotFound) {
        AppToast.warning(TripStrings.couldNotLoad);
        TripNavigation.backToPlan();
        return;
      }
    }
    _openRequest(false);
  }

  String? _fromPlan() {
    if (!Get.isRegistered<TripPlanController>()) return null;
    final t = TripPlanController.to.trip.value;
    return t != null && t.id == widget.tripId ? t.taxiRequest?.requestId : null;
  }

  void _openRequest(bool keepChoices) {
    final tripId = widget.tripId;
    final plan = Get.isRegistered<TripPlanController>() ? TripPlanController.to : null;
    if (plan != null && plan.plan.value != null && (tripId == null || plan.trip.value?.id == tripId)) {
      TripNavigation.openTaxiRequest(context, keepChoices: keepChoices, replace: true);
    } else if (tripId != null) {
      Get.offNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId});
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _requestId;
    if (id == null) return _loadingPage();
    return TripTaxiRequestStatusScreen(
      requestId: id,
      onDone: TripNavigation.backToPlan,
      onOpenRequest: ({required bool keepChoices}) => _openRequest(keepChoices),
    );
  }
}
