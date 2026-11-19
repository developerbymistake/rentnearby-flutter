import 'dart:async';
import 'package:bakhli/design/design.dart';
import '../widgets/trip_update_ask_sheet.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_dayplan.dart';
import '../trip_strings_name.dart';
import '../utils/trip_name_rules.dart';
import '../widgets/trip_leg_fold_state.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../trip_strings_v2_plan.dart';
import '../widgets/trip_add_city_card.dart';
import '../widgets/trip_day_spot_list.dart';
import '../widgets/trip_day_chips.dart';
import '../widgets/trip_days_sheet.dart';
import '../widgets/trip_exit_confirm.dart';
import '../widgets/trip_leg_header.dart';
import '../widgets/trip_leg_menu_sheet.dart';
import '../widgets/trip_lifecycle_actions.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_plan_header.dart';
import '../widgets/trip_today_card.dart';
import '../widgets/trip_update_app_card.dart';
import 'trip_dates_sheet.dart';

class TripPlanScreen extends StatefulWidget {
  const TripPlanScreen({super.key});

  static const Key lockedBannerKey = ValueKey('plan-locked-banner');
  static const Key viewButtonKey = ValueKey('plan-view-taxi');
  static const Key renameFieldKey = ValueKey('plan-rename-field');
  static const Key saveTripKey = ValueKey('plan-save-trip');
  static const Key noteKey = ValueKey('plan-note');

  @override
  State<TripPlanScreen> createState() => _TripPlanScreenState();
}

class _TripPlanScreenState extends State<TripPlanScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  late final List<Animation<double>> _slots = List.generate(8, (i) => templateInterval(_anim, i, 8));

  Widget _in(int i, Widget child) =>
      TemplateEntrance(animation: _slots[i > 7 ? 7 : i], animationController: _anim, child: child);
  late final TripPlanController _c;
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _legKeys = {};
  final TripLegFoldState _fold = TripLegFoldState();
  Worker? _startWorker;
  Worker? _addedWorker;
  String? _tripId;
  int? _legFilter;
  bool _savingTrip = false;
  String? _note;
  Timer? _noteTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c.trip.value != null) _c.refreshEnquiries();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c = TripPlanController.to;
    _c.openPages++;
    _c.editMode.value = false;
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    _tripId = map['tripId'] as String?;
    final fresh = map['fresh'] == true;
    final id = _tripId;
    _startWorker = ever<TripPlan?>(_c.plan, (_) => _checkStartFrom());
    _addedWorker = ever<int?>(_c.lastAddedLeg, _scrollToAdded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anim.forward();
      _checkStartFrom();
    });
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!fresh && _c.trip.value?.id == id && _c.plan.value != null) {
          _c.refreshEnquiries();
        } else {
          await _c.open(id, fresh: fresh);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startWorker?.dispose();
    _addedWorker?.dispose();
    _scroll.dispose();
    _fold.dispose();
    _anim.dispose();
    _noteTimer?.cancel();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _c)) {
      _c.editMode.value = false;
      _c.openPages--;
      _c.releaseIfIdle();
    }
    super.dispose();
  }

  void _checkStartFrom() {
    if (!mounted || _c.plan.value == null || _c.startFrom != null || _c.isReadOnly) return;
    unawaited(_c.ensureStartFrom());
  }

  void _scrollToAdded(int? legIndex) {
    if (legIndex == null) return;
    if (_legFilter != null) setState(() => _legFilter = null);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _scrollTo(_legKey(legIndex));
      if (_c.lastAddedLeg.value == legIndex) _c.lastAddedLeg.value = null;
    });
  }

  GlobalKey _legKey(int legIndex) => _legKeys.putIfAbsent(legIndex, () => GlobalKey());

  Future<void> _scrollTo(GlobalKey key) async {
    if (key.currentContext == null && _scroll.hasClients) {
      _scroll.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
    }
    for (var i = 0; i < 40 && mounted; i++) {
      final ctx = key.currentContext;
      if (ctx != null) {
        if (!ctx.mounted) return;
        await Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.04);
        return;
      }
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.pixels >= pos.maxScrollExtent) return;
      _scroll.jumpTo(math.min(pos.pixels + pos.viewportDimension, pos.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _onMenu(TripPlanMenu action) async {
    switch (action) {
      case TripPlanMenu.saveExit:
        await TripLifecycleActions.saveAndExit(context);
      case TripPlanMenu.editDays:
        await TripDaysSheet.show(context);
        if (mounted) _c.editMode.value = true;
      case TripPlanMenu.editDates:
        await TripDatesSheet.edit(context);
      case TripPlanMenu.rename:
        await _rename();
      case TripPlanMenu.summary:
        final id = _c.trip.value?.id;
        if (id != null) TripLifecycleActions.openSummary(id);
      case TripPlanMenu.map:
        TripNavigation.openMap(day: _c.todayDay == null ? TripDayChips.all : _c.defaultMapDay, tripId: _c.trip.value?.id);
      case TripPlanMenu.mute:
        await TripLifecycleActions.toggleMute(context);
      case TripPlanMenu.complete:
        await TripLifecycleActions.markComplete(context);
      case TripPlanMenu.delete:
        await TripLifecycleActions.deleteFromPlan(context);
    }
  }

  Future<void> _rename() async {
    final current = _c.title;
    final title = await Dialog3D.show<String>(
      context,
      builder: (ctx) => _RenameDialog(initial: current.length > TripNameRules.max ? current.substring(0, TripNameRules.max) : current),
    );
    if (title == null || title == current) return;
    await _c.rename(title);
  }

  Future<void> _openCustomize(int leg) async {
    if (!_c.canEditStructure) return;
    final before = _c.plan.value;
    await Get.toNamed(AppRoutes.tripCustomize, arguments: {'tripId': _c.trip.value?.id, 'leg': leg, 'toast': _customizeToast});
    if (!mounted || identical(before, _c.plan.value) || _c.plan.value?.legAt(leg) == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollTo(_legKey(leg));
    });
  }

  void _customizeToast(bool success, String message) {
    if (!success || !mounted) {
      AppToast.warning(message);
      return;
    }
    _noteTimer?.cancel();
    setState(() => _note = message);
    _noteTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _note = null);
    });
  }

  Widget _buildNote() {
    final note = _note;
    if (note == null) return const SizedBox.shrink();
    return Positioned(
      left: DS.s(18),
      right: DS.s(18),
      bottom: DS.gv(20),
      child: Semantics(
        liveRegion: true,
        child: Container(
          key: TripPlanScreen.noteKey,
          constraints: BoxConstraints(minHeight: DS.s(48)),
          padding: DS.sym(h: 18, v: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: TripLook.ink, borderRadius: DS.circular(14)),
          child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, DesignColors.surface, letterSpacing: 0)),
        ),
      ),
    );
  }

  void _openLockedStatus() {
    Get.toNamed(AppRoutes.tripTaxiStatus, arguments: {'tripId': _c.trip.value?.id, 'requestId': _c.planLockRequestId});
  }

  bool get _exitGuard => _c.trip.value != null && _c.plan.value != null && !_c.tripGone.value && !_c.plannerOff.value;

  bool _askingExit = false;

  Future<void> _askExit() async {
    if (_askingExit) return;
    _askingExit = true;
    try {
      if (await TripExitConfirm.ask(context)) TripNavigation.openTripsTab();
    } finally {
      _askingExit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page(context);
    return Obx(() => PopScope(
          canPop: !_exitGuard,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _askExit();
          },
          child: page,
        ));
  }

  Widget _page(BuildContext context) {
    return Container(
      color: DesignColors.scaffold,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          TemplateEntrance(
            animation: templateInterval(_anim, 0, 2),
            animationController: _anim,
            child: TripPlanHeader(onMenu: _onMenu),
          ),
          _buildOffline(),
          _buildNotSaved(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildBody(),
                    _buildNote(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  Widget _buildLegChips() {
    return Obx(() {
      final p = _c.plan.value;
      if (p == null || _c.plannerOff.value || _c.tripGone.value || !p.isMultiCity) return const SizedBox.shrink();
      final filter = _legFilter != null && p.legAt(_legFilter!) != null ? _legFilter : null;
      void pick(int? k) => setState(() => _legFilter = k);
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(14), DS.s(18), DS.s(8)),
            child: Row(
              children: [
                _LegChip(art: ListingArt.worldMap, label: TripStringsV2Plan.allCities, on: filter == null, onTap: () => pick(null)),
                for (final leg in p.legs) ...[
                  Gap.h(10),
                  _LegChip(
                    art: ListingArt.mountain,
                    label: TripStringsV2Plan.legChip(leg.cityName, p.legDayCount(leg.index)),
                    on: filter == leg.index,
                    onTap: () => pick(leg.index),
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
      );
    });
  }

  EdgeInsets _bannerMargin() => EdgeInsets.fromLTRB(DS.s(18), DS.gv(10), DS.s(18), 0);

  Widget _buildOffline() {
    return Obx(() {
      if (!_c.offline.value || _c.plannerOff.value || _c.plan.value == null) return const SizedBox.shrink();
      return Banner3D(
        kind: BannerKind.info,
        art: ListingArt.worldMap,
        title: TripStringsV2Plan.offlineBanner,
        margin: _bannerMargin(),
      );
    });
  }

  Widget _buildLocked() {
    return Obx(() {
      _c.trip.value;
      if (!_c.isPlanLocked || _c.plannerOff.value || _c.plan.value == null) return const SizedBox.shrink();
      final palette = ListingPalette.indigo;
      return Container(
        key: TripPlanScreen.lockedBannerKey,
        margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(16), DS.s(18), 0),
        padding: DS.insets(l: 16, t: 12, r: 16, b: 12),
        decoration: BoxDecoration(color: palette.tint, borderRadius: DS.br(TripLegSectionHeader.lockRadius)),
        child: Row(
          children: [
            const Art3D(asset: ListingArt.locked, size: 34, shadowBlur: 2, shadowOffset: Offset(1, 2)),
            Gap.h(12),
            Expanded(
              child: Text(_c.planLockMessage, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, palette.text, height: 1.45, letterSpacing: 0)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNotSaved() {
    return Obx(() {
      if (!_c.saveFailed.value || _c.plannerOff.value || _c.plan.value == null) return const SizedBox.shrink();
      final saving = _c.isSaving.value;
      return Stack(
        alignment: Alignment.centerRight,
        children: [
          Banner3D(
            kind: BannerKind.warn,
            art: ListingArt.clipboard,
            title: TripStrings.notSavedYet,
            actionLabel: saving ? null : TripStringsV2Plan.retry,
            onAction: saving ? null : _c.retrySave,
            margin: _bannerMargin(),
          ),
          if (saving) Padding(padding: EdgeInsets.only(right: DS.s(34), top: DS.s(10)), child: const KitDots(color: DesignColors.warning)),
        ],
      );
    });
  }

  Widget _buildBody() {
    return Obx(() {
      if (_c.tripGone.value) return ListView(children: const [TripNotFoundView()]);
      if (_c.plannerOff.value) {
        return ListView(padding: EdgeInsets.only(top: DS.s(40)), children: const [
          StateCard(
            asset: TravelIcon.route,
            title: TripStrings.plannerOff,
            message: TripStrings.plannerOffSubtitle,
            layout: StateLayout.plain,
          ),
        ]);
      }
      final plan = _c.plan.value;
      if (plan == null) {
        if (_c.openFailed.value) {
          return ListView(padding: EdgeInsets.only(top: DS.s(40)), children: [
            StateCard.error(
              title: TripStrings.tripFailed,
              message: TripStrings.checkConnection,
              actionLabel: TripStrings.retry,
              onAction: _c.retryOpen,
              layout: StateLayout.plain,
            ),
          ]);
        }
        return _skeletons();
      }
      if (_c.isPlanning.value && _c.result.value == null && !_c.planFailed.value) return _skeletons();
      _c.trip.value;
      _c.enquiryList.length;
      _c.result.value;
      final editable = _c.canEditStructure;
      final editing = _c.editMode.value && editable;
      final addCity = editable && !editing;
      return ListenableBuilder(
        listenable: _fold,
        builder: (_, _) {
          var n = 0;
          Widget w(Widget child) => _in(n++, child);
          final shownLegs = [
            for (final leg in plan.legs)
              if (_legFilter == null || plan.legAt(_legFilter!) == null || leg.index == _legFilter) leg,
          ];
          return ListView(
            controller: _scroll,
            padding: EdgeInsets.only(bottom: _note == null ? DS.s(20) : DS.gv(40) + DS.s(48)),
            children: [
              _buildLocked(),
              if (!editing) w(TripPlanStepCard(onMenu: _onMenu)),
              MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: _buildLegChips()),
              if (_c.planFailed.value)
                w(StateCard.error(
                  title: TripStrings.planFailed,
                  message: _c.planError.value ?? TripStrings.checkConnection,
                  actionLabel: _c.planRetryable.value ? TripStrings.retry : null,
                  onAction: _c.planRetryable.value ? _c.retryPlan : null,
                )),
              w(const TripTodayCard()),
              if (editing) _editBanner(),
              for (final (i, leg) in shownLegs.indexed)
                  w(TripLegHeader(
                    key: ValueKey('trip-leg-${leg.index}'),
                    legIndex: leg.index,
                    anchorKey: _legKey(leg.index),
                    folded: _fold.isFolded(leg.index),
                    onToggle: () => _fold.toggle(leg.index),
                    onCustomize: () => _openCustomize(leg.index),
                    gapBelow: i < shownLegs.length - 1
                        ? DS.gv(44)
                        : addCity && plan.spotCount > 0
                            ? DS.gv(24)
                            : 0,
                    body: [
                      for (final d in plan.days)
                        if (d.leg == leg.index) TripDaySpotList(d.day, key: ValueKey('trip-day-${d.day}'), inSection: true),
                    ],
                  )),
              if (plan.spotCount == 0 && !editing && editable) _emptyPlan(),
              if (editing && _c.canAddDay) _addDayButton(),
              if (addCity) w(const TripAddCityCard()),
            ],
          );
        },
      );
    });
  }

  static BoxDecoration get _barDecoration => BoxDecoration(
    color: DesignColors.surface,
    borderRadius: DS.br(const BorderRadius.vertical(top: Radius.circular(24))),
    boxShadow: DS.shadows(Ink3D.topEdge),
  );

  Future<void> _saveTrip() async {
    if (_savingTrip) return;
    if (_c.isNewUnsaved) {
      final ok = await TripDatesSheet.saveTrip(context);
      final id = _c.trip.value?.id;
      if (!mounted || !ok || id == null) return;
      TripNavigation.enterOverview(id);
      return;
    }
    setState(() => _savingTrip = true);
    final ok = await _c.flushPendingSave();
    if (!mounted) return;
    setState(() => _savingTrip = false);
    final id = _c.trip.value?.id;
    if (!ok || id == null) {
      if (!_c.saveFailed.value) AppToast.error(TripStringsDayplan.saveTripFailed);
      return;
    }
    if (Get.previousRoute == AppRoutes.tripOverview) {
      Get.back();
    } else {
      await Get.offNamed(AppRoutes.tripOverview, arguments: {'tripId': id});
    }
  }

  Widget _nextButton(int spots) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientPillButton(
            key: TripPlanScreen.saveTripKey,
            tone: ListingTone.indigo,
            label: _c.isNewUnsaved ? TripStringsDayplan.saveTrip : TripStringsDayplan.backToOverview,
            loading: _savingTrip,
            shadows: TripLook.pillShadow,
            onTap: spots == 0 ? null : _saveTrip,
          ),
          if (spots == 0)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(10)),
              child: Text(
                TripStringsV2Plan.nextHintNoPlaces,
                textAlign: TextAlign.center,
                style: Ink3D.text(13, FontWeight.w600, Ink3D.grey),
              ),
            ),
        ],
      );

  EdgeInsets _barPadding(BuildContext context, bool bottomInset) =>
      EdgeInsets.fromLTRB(DS.s(16), DS.s(12), DS.s(16), (bottomInset ? AppInsets.bottomViewPadding(context) : 0) + DS.s(16));

  Widget _nextBar(BuildContext context, bool bottomInset, int spots) => Container(
        padding: _barPadding(context, bottomInset),
        decoration: _barDecoration,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _nextButton(spots),
          ),
        ),
      );

  Widget _viewBar(BuildContext context, bool bottomInset) => Container(
        padding: _barPadding(context, bottomInset),
        decoration: _barDecoration,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: GradientPillButton(
              key: TripPlanScreen.viewButtonKey,
              tone: ListingTone.indigo,
              label: _c.planLock.byBooking ? TripStringsDayplan.viewBooking : TripStringsDayplan.viewRequest,
              shadows: TripLook.pillShadow,
              onTap: _openLockedStatus,
            ),
          ),
        ),
      );

  Widget _editBanner() => Banner3D(
        kind: BannerKind.warn,
        art: ListingArt.roundPushpin,
        title: TripStringsV2Plan.editBanner,
        compact: true,
        margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(14), DS.s(18), 0),
      );

  Widget _addDayButton() => Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(4), DS.s(18), DS.gv(10)),
        child: WhitePillButton(
          tone: ListingTone.indigo,
          label: TripStringsV2Plan.addDay,
          height: 56,
          onTap: () {
            _c.addDay();
            TripUpdateAskSheet.afterDaysEdit();
          },
        ),
      );

  Widget _emptyPlan() => StateCard(
        asset: TravelIcon.route,
        title: TripStringsV2Plan.noPlanTitle,
        message: TripStringsV2Plan.noPlanSub,
        actionLabel: TripStringsV2Plan.addPlace,
        onAction: () => TripLegMenuSheet.addPlaces(1, pickDay: 1),
      );

  Widget _skeletons() => ListView(
        padding: EdgeInsets.only(bottom: DS.s(24)),
        children: [for (var i = 0; i < 4; i++) const WideCardSkeleton()],
      );

  Widget _completeBar(BuildContext context) {
    if (!_c.isLastDayOrAfter || !_c.canComplete) return const SizedBox.shrink();
    return Container(
      padding: _barPadding(context, true),
      decoration: _barDecoration,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                TripStrings.lastDayDone,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(14.5, FontWeight.w700, Ink3D.title),
              ),
              Text(
                TripStrings.remindersStop,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(12, FontWeight.w400, Ink3D.grey),
              ),
              Gap.v(10),
              GradientPillButton(
                tone: ListingTone.indigo,
                label: TripStrings.markTripComplete,
                shadows: TripLook.pillShadow,
                onTap: () => TripLifecycleActions.markComplete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      _c.trip.value;
      if (_c.tripGone.value) return const SizedBox.shrink();
      if (_c.needsUpdate.value) return const _BarIn(child: TripUpdateAppCard());
      if (_c.plannerOff.value || _c.plan.value == null || _c.isCompleted) return const SizedBox.shrink();
      final complete = _c.isLastDayOrAfter && _c.canComplete;
      final nextNav = !_c.editMode.value && !_c.isReadOnly && !_c.isPlanLocked;
      final locked = _c.isPlanLocked && !_c.editMode.value && !_c.isReadOnly;
      if (!complete && !nextNav && !locked) return const SizedBox.shrink();
      return _BarIn(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (locked) _viewBar(context, !complete),
          if (nextNav) _nextBar(context, !complete, _c.plan.value!.spotCount),
          if (complete) _completeBar(context),
        ],
      ));
    });
  }
}

class _LegChip extends StatelessWidget {
  const _LegChip({required this.art, required this.label, required this.on, required this.onTap});

  final String art;
  final String label;
  final bool on;
  final VoidCallback onTap;

  static const BorderRadius _radius = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(22),
    bottomLeft: Radius.circular(14),
    bottomRight: Radius.circular(14),
  );

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: on,
      exclude: true,
      child: Container(
        height: DS.s(40),
        padding: DS.sym(h: 14),
        decoration: BoxDecoration(
          gradient: on ? tone.gradient : null,
          color: on ? null : DesignColors.surface,
          borderRadius: DS.br(_radius),
          boxShadow: DS.shadows(on ? TripLook.chipOnShadow : TripLook.chipOffShadow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Art3D(asset: art, size: 24, shadowBlur: 0, shadowAlpha: 0),
            Gap.h(8),
            Text(label, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, on ? DesignColors.surface : Ink3D.sub, letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}

class _BarIn extends StatefulWidget {
  const _BarIn({required this.child});
  final Widget child;

  @override
  State<_BarIn> createState() => _BarInState();
}

class _BarInState extends State<_BarIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _a = templateInterval(_c, 0, 1);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TemplateEntrance(animation: _a, animationController: _c, child: widget.child);
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = TripNameRules.clean(_ctrl.text);
    final error = TripNameRules.problem(name);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    return Dialog3D(
      tone: ListingTone.indigo,
      art: ListingArt.pushpin,
      title: TripStringsV2Plan.renameTitle,
      minBodyLines: 0,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillField(
            fieldKey: TripPlanScreen.renameFieldKey,
            tone: ListingTone.indigo,
            controller: ctrl,
            autofocus: true,
            maxLength: TripNameRules.max,
            counterText: '',
            errorRing: _error != null,
            hint: TripStringsV2Plan.tripName,
            textInputAction: TextInputAction.done,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripNameRules.max)],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          FieldMessage(
            error: _error,
            counter: TripStringsName.counter(ctrl.text.length),
            reserve: true,
          ),
        ],
      ),
      secondaryLabel: TripStringsV2Plan.cancel,
      onSecondary: () => Navigator.pop(context),
      primaryLabel: TripStringsV2Plan.save,
      onPrimary: _save,
    );
  }
}
