import 'dart:async';
import 'package:bakhli/design/design.dart';
import '../widgets/trip_update_ask_sheet.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_plan_guide.dart';
import '../models/trip_plan_model.dart';
import '../utils/trip_guide_rules.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_v2_plan.dart';
import '../widgets/trip_add_city_card.dart';
import '../widgets/trip_day_spot_list.dart';
import '../widgets/trip_days_sheet.dart';
import '../widgets/trip_easy_card.dart';
import '../widgets/guide/trip_guide_view.dart';
import '../widgets/trip_easy_mini_bar.dart';
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
  Worker? _stepWorker;
  bool _stepDone = false;
  bool _fresh = false;
  Worker? _startWorker;
  Worker? _addedWorker;
  Worker? _rowWorker;
  Worker? _openWorker;
  Worker? _guideWorker;
  String? _tripId;
  String? _row;
  String? _stepArg;
  bool _nudge = false;
  bool _reopen = false;
  String? _nameArg;
  bool _rowDone = true;
  int? _legFilter;

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
    _fresh = fresh;
    _c.planStep.value = 1;
    final row = map['row'];
    _row = row is String && row.isNotEmpty ? row : null;
    final step = map['step'];
    _stepArg = step is String && step.isNotEmpty ? step : _row;
    _nudge = _flag(map['nudge']);
    _reopen = _flag(map['reopen']);
    final name = map['name'];
    _nameArg = name is String && name.isNotEmpty ? name : null;
    _rowDone = _row == null && _stepArg == null;
    final id = _tripId;
    _startWorker = ever<TripPlan?>(_c.plan, (_) => _checkStartFrom());
    _addedWorker = ever<int?>(_c.lastAddedLeg, _scrollToAdded);
    _rowWorker = ever<TripPlan?>(_c.plan, (_) => _tryOpenRow());
    _openWorker = ever<bool>(_c.isOpening, (_) => _tryOpenRow());
    _guideWorker = everAll(
      [_c.plan, _c.planStep, _c.editMode, _c.needsUpdate, _c.tripGone, _c.plannerOff, _c.trip],
      (_) => _c.guideRefresh(),
    );
    _stepWorker = ever<int>(_c.planStep, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) _scroll.jumpTo(0);
        _anim.forward(from: 0);
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anim.forward();
      _checkStartFrom();
      _c.guideRefresh();
    });
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!fresh && _c.trip.value?.id == id && _c.plan.value != null) {
          _c.refreshEnquiries();
        } else {
          await _c.open(id, fresh: fresh);
        }
        _tryOpenRow();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpenRow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startWorker?.dispose();
    _addedWorker?.dispose();
    _rowWorker?.dispose();
    _openWorker?.dispose();
    _stepWorker?.dispose();
    _guideWorker?.dispose();
    _scroll.dispose();
    _anim.dispose();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _c)) {
      _c.editMode.value = false;
      _c.openPages--;
      _c.releaseIfIdle();
    }
    super.dispose();
  }

  static bool _flag(Object? v) => v == true || v == 'true';

  void _checkStartFrom() {
    if (!mounted || _c.plan.value == null || _c.startFrom != null || _c.isReadOnly) return;
    unawaited(_c.ensureStartFrom());
  }

  void _tryOpenRow() {
    if ((_rowDone && _stepDone) || !mounted) return;
    final id = _tripId;
    if (_c.isOpening.value || _c.plan.value == null || (id != null && _c.trip.value?.id != id)) return;
    if (_c.tripGone.value || _c.plannerOff.value) return;
    _rowDone = true;
    if (_stepDone) return;
    _stepDone = true;
    final step = _stepArg;
    if (step != null && TripGuideRules.isStepKey(step)) {
      _c.guideJumpTo(step, nudge: _nudge, reopen: _reopen, name: _nameArg);
      return;
    }
    _c.planStep.value = _row != null ? 2 : (_fresh ? 1 : _c.initialStep);
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
        if (mounted) {
          _c.planStep.value = 1;
          _c.editMode.value = true;
        }
      case TripPlanMenu.editDates:
        await TripDatesSheet.edit(context);
      case TripPlanMenu.rename:
        await _rename();
      case TripPlanMenu.summary:
        final id = _c.trip.value?.id;
        if (id != null) TripLifecycleActions.openSummary(id);
      case TripPlanMenu.map:
        TripNavigation.openMap(day: _c.defaultMapDay, tripId: _c.trip.value?.id);
      case TripPlanMenu.mute:
        await TripLifecycleActions.toggleMute(context);
      case TripPlanMenu.complete:
        await TripLifecycleActions.markComplete(context);
      case TripPlanMenu.delete:
        await TripLifecycleActions.deleteFromPlan(context);
      case TripPlanMenu.easy:
        _c.planStep.value = _c.pendingStep;
    }
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _c.title);
    final title = await Dialog3D.show<String>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.indigo,
        art: ListingArt.pushpin,
        title: TripStringsV2Plan.renameTitle,
        minBodyLines: 0,
        content: PillField(
          tone: ListingTone.indigo,
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          hint: TripStringsV2Plan.tripName,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(80)],
        ),
        secondaryLabel: TripStringsV2Plan.cancel,
        onSecondary: () => Navigator.pop(ctx),
        primaryLabel: TripStringsV2Plan.save,
        onPrimary: () => Navigator.pop(ctx, ctrl.text.trim()),
      ),
    );
    ctrl.dispose();
    if (title == null || title.isEmpty || title == _c.title) return;
    await _c.rename(title);
  }

  @override
  Widget build(BuildContext context) {
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
                child: Obx(() => _c.guideState.on.value ? const TripGuideView() : _buildBody()),
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
      if (p == null || _c.plannerOff.value || _c.tripGone.value || !p.isMultiCity || _c.guideState.on.value) return const SizedBox.shrink();
      final filter = _legFilter != null && p.legAt(_legFilter!) != null ? _legFilter : null;
      void pick(int? k) => setState(() => _legFilter = k);
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ChipCPRow(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            children: [
              ChipCP(tone: ListingTone.indigo, art: ListingArt.worldMap, label: TripStringsV2Plan.allCities, off: filter != null, onTap: () => pick(null)),
              for (final leg in p.legs)
                ChipCP(
                  tone: ListingTone.indigo,
                  art: ListingArt.mountain,
                  label: TripStringsV2Plan.legChip(leg.cityName, p.legDayCount(leg.index)),
                  off: filter != leg.index,
                  onTap: () => pick(leg.index),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildOffline() {
    return Obx(() {
      if (!_c.offline.value || _c.plannerOff.value || _c.plan.value == null) return const SizedBox.shrink();
      return const Banner3D(
        kind: BannerKind.info,
        art: ListingArt.worldMap,
        title: TripStringsV2Plan.offlineBanner,
        margin: EdgeInsets.fromLTRB(18, 10, 18, 0),
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
            margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          ),
          if (saving) const Padding(padding: EdgeInsets.only(right: 34, top: 10), child: KitDots(color: DesignColors.warning)),
        ],
      );
    });
  }

  Widget _buildBody() {
    return Obx(() {
      if (_c.tripGone.value) return ListView(children: const [TripNotFoundView()]);
      if (_c.plannerOff.value) {
        return ListView(padding: const EdgeInsets.only(top: 40), children: const [
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
          return ListView(padding: const EdgeInsets.only(top: 40), children: [
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
      final editing = _c.editMode.value && !_c.isReadOnly && !_c.needsUpdate.value;
      final editable = !_c.isReadOnly && !_c.needsUpdate.value;
      final step2 = !editing && !_c.isCompleted && _c.planStep.value == 2;
      var n = 0;
      Widget w(Widget child) => _in(n++, child);
      return ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
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
          if (step2) w(_g(const TripEasyCard())),
          if (!step2) ...[
          for (final d in plan.days)
            if (_legFilter == null || plan.legAt(_legFilter!) == null || d.leg == _legFilter) ...[
            if (plan.isMultiCity && plan.legStart(d.leg) == d.day)
              w(TripLegHeader(key: ValueKey('trip-leg-${d.leg}'), legIndex: d.leg, anchorKey: _legKey(d.leg))),
            w(TripDaySpotList(d.day, key: ValueKey('trip-day-${d.day}'))),
          ],
          if (plan.spotCount == 0 && !editing && editable) _emptyPlan(),
          if (editing && _c.canAddDay) _addDayButton(),
          if (editable && !editing) ...[
            w(const TripAddCityCard()),
            const SizedBox(height: 14),
            if (!_c.isCompleted) w(_g(_nextButton(plan.spotCount))),
          ] else
            const SizedBox(height: 8),
          ],
        ],
      );
    });
  }

  static const _barDecoration = BoxDecoration(
    color: DesignColors.surface,
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    boxShadow: Ink3D.topEdge,
  );

  Widget _g(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: child);

  Widget _nextButton(int spots) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientPillButton(
            tone: ListingTone.indigo,
            label: '${TripStringsV2Plan.next} · ${TripStringsV2Plan.nextSub}',
            onTap: spots == 0
                ? null
                : () {
                    _c.planStep.value = 2;
                  },
          ),
          if (spots == 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                TripStringsV2Plan.nextHintNoPlaces,
                textAlign: TextAlign.center,
                style: Ink3D.text(13, FontWeight.w600, Ink3D.grey),
              ),
            ),
        ],
      );

  Widget _stepBar(BuildContext context, bool bottomInset) => Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset ? AppInsets.bottomViewPadding(context) + 10 : 10),
        decoration: _barDecoration,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Row(
              children: [
                Expanded(
                  child: WhitePillButton(tone: ListingTone.indigo, label: TripStringsV2Plan.previous, onTap: () => _c.planStep.value = 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientPillButton(
                    tone: ListingTone.indigo,
                    label: TripStringsV2Plan.done,
                    onTap: () => TripLifecycleActions.saveAndExit(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _editBanner() => const Banner3D(
        kind: BannerKind.warn,
        art: ListingArt.roundPushpin,
        title: TripStringsV2Plan.editBanner,
        compact: true,
        margin: EdgeInsets.fromLTRB(18, 14, 18, 0),
      );

  Widget _addDayButton() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
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
        padding: const EdgeInsets.only(bottom: 24),
        children: [for (var i = 0; i < 4; i++) const WideCardSkeleton()],
      );

  Widget _completeBar(BuildContext context) {
    if (!_c.isLastDayOrAfter || !_c.canComplete) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
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
              const SizedBox(height: 10),
              GradientPillButton(
                tone: ListingTone.indigo,
                label: TripStrings.markTripComplete,
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
      final guided = _c.guideState.on.value;
      final mini = !guided && !_c.editMode.value && _c.easyInProgress != null;
      final nav = !guided && !_c.editMode.value && !_c.isReadOnly && _c.planStep.value == 2;
      if (!complete && !mini && !nav) return const SizedBox.shrink();
      return _BarIn(
        key: ValueKey(_c.planStep.value),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mini)
            Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, complete || nav ? 8 : AppInsets.bottomViewPadding(context) + 8),
                  child: const TripEasyMiniBar(),
                ),
              ),
            ),
          if (nav) _stepBar(context, !complete),
          if (complete) _completeBar(context),
        ],
      ));
    });
  }
}

class _BarIn extends StatefulWidget {
  const _BarIn({super.key, required this.child});
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
