import 'dart:async';
import '../widgets/trip_update_ask_sheet.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_v2_plan.dart';
import '../widgets/trip_add_city_card.dart';
import '../widgets/trip_day_spot_list.dart';
import '../widgets/trip_days_sheet.dart';
import '../widgets/trip_easy_card.dart';
import '../widgets/trip_easy_mini_bar.dart';
import '../widgets/trip_filter_chips.dart';
import '../widgets/trip_leg_header.dart';
import '../widgets/trip_leg_menu_sheet.dart';
import '../widgets/trip_lifecycle_actions.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_plan_header.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_today_card.dart';
import '../widgets/trip_update_app_card.dart';
import 'trip_dates_sheet.dart';

class TripPlanScreen extends StatefulWidget {
  const TripPlanScreen({super.key});

  @override
  State<TripPlanScreen> createState() => _TripPlanScreenState();
}

class _TripPlanScreenState extends State<TripPlanScreen> with WidgetsBindingObserver {
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
  String? _tripId;
  String? _row;
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
    _rowDone = _row == null;
    final id = _tripId;
    _startWorker = ever<TripPlan?>(_c.plan, (_) => _checkStartFrom());
    _addedWorker = ever<int?>(_c.lastAddedLeg, _scrollToAdded);
    _rowWorker = ever<TripPlan?>(_c.plan, (_) => _tryOpenRow());
    _openWorker = ever<bool>(_c.isOpening, (_) => _tryOpenRow());
    _stepWorker = ever<int>(_c.planStep, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStartFrom());
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
    _scroll.dispose();
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

  void _tryOpenRow() {
    if ((_rowDone && _stepDone) || !mounted) return;
    final id = _tripId;
    if (_c.isOpening.value || _c.plan.value == null || (id != null && _c.trip.value?.id != id)) return;
    if (_c.tripGone.value || _c.plannerOff.value) return;
    _rowDone = true;
    if (_stepDone) return;
    _stepDone = true;
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
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(TripStringsV2Plan.renameTitle,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(80)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: const InputDecoration(hintText: TripStringsV2Plan.tripName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(TripStringsV2Plan.cancel, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text(TripStringsV2Plan.save,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (title == null || title.isEmpty || title == _c.title) return;
    await _c.rename(title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          TripPlanHeader(onMenu: _onMenu),
          _buildOffline(),
          _buildNotSaved(),
          _buildLegChips(),
          Expanded(
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: _buildBody()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                TripChipView(chip: TripFilterChip(label: TripStringsV2Plan.allCities, selected: filter == null, onTap: () => pick(null))),
                for (final leg in p.legs) ...[
                  const SizedBox(width: 6),
                  TripChipView(
                    chip: TripFilterChip(
                      label: TripStringsV2Plan.legChip(leg.cityName, p.legDayCount(leg.index)),
                      selected: filter == leg.index,
                      onTap: () => pick(leg.index),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildOffline() {
    return Obx(() {
      if (!_c.offline.value || _c.plannerOff.value || _c.plan.value == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(10)),
        child: const Row(
          children: [
            Icon(Iconsax.cloud_cross, size: 15, color: AppColors.textMedium),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                TripStringsV2Plan.offlineBanner,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
              ),
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
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Iconsax.warning_2, size: 15, color: AppColors.warningText),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                TripStrings.notSavedYet,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
              ),
            ),
            SizedBox(
              height: 36,
              child: saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warningText),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _c.retrySave,
                      child: const Text(
                        TripStringsV2Plan.retry,
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningText),
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBody() {
    return Obx(() {
      if (_c.tripGone.value) return ListView(children: const [TripNotFoundView()]);
      if (_c.plannerOff.value) {
        return ListView(children: const [
          EmptyStateView(
            icon: Iconsax.routing_2,
            title: TripStrings.plannerOff,
            subtitle: TripStrings.plannerOffSubtitle,
            palette: TripColors.palette,
          ),
        ]);
      }
      final plan = _c.plan.value;
      if (plan == null) {
        if (_c.openFailed.value) {
          return ListView(children: [
            EmptyStateView(
              icon: Iconsax.cloud_cross,
              title: TripStrings.tripFailed,
              subtitle: TripStrings.checkConnection,
              onRetry: _c.retryOpen,
              palette: TripColors.palette,
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
      return ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (_c.planFailed.value) ...[
            EmptyStateView(
              icon: Iconsax.cloud_cross,
              title: TripStrings.planFailed,
              subtitle: _c.planError.value ?? TripStrings.checkConnection,
              onRetry: _c.planRetryable.value ? _c.retryPlan : null,
              palette: TripColors.palette,
            ),
            const SizedBox(height: 20),
          ],
          const TripTodayCard(),
          if (editing) _editBanner(),
          if (step2) const TripEasyCard(),
          if (!step2) ...[
          for (final d in plan.days)
            if (_legFilter == null || plan.legAt(_legFilter!) == null || d.leg == _legFilter) ...[
            if (plan.isMultiCity && plan.legStart(d.leg) == d.day)
              TripLegHeader(key: ValueKey('trip-leg-${d.leg}'), legIndex: d.leg, anchorKey: _legKey(d.leg)),
            TripDaySpotList(d.day, key: ValueKey('trip-day-${d.day}')),
          ],
          if (plan.spotCount == 0 && !editing && editable) _emptyPlan(),
          if (editing && _c.canAddDay) _addDayButton(),
          if (editable && !editing) ...[
            const SizedBox(height: 2),
            const TripAddCityCard(),
            const SizedBox(height: 14),
            if (!_c.isCompleted) _nextButton(plan.spotCount),
          ] else
            const SizedBox(height: 8),
          ],
        ],
      );
    });
  }

  Widget _nextButton(int spots) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientButton(
            label: '${TripStringsV2Plan.next} · ${TripStringsV2Plan.nextSub}',
            height: 52,
            gradient: TripColors.gradient,
            shadowColor: TripColors.accent,
            onPressed: spots == 0 ? null : () => _c.planStep.value = 2,
          ),
          if (spots == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                TripStringsV2Plan.nextHintNoPlaces,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
              ),
            ),
        ],
      );

  Widget _stepBar(BuildContext context, bool bottomInset) => Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset ? AppInsets.bottomViewPadding(context) + 10 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _c.planStep.value = 1,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: TripColors.accent.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      TripStringsV2Plan.previous,
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    label: TripStringsV2Plan.done,
                    height: 52,
                    gradient: TripColors.gradient,
                    shadowColor: TripColors.accent,
                    onPressed: () => TripLifecycleActions.saveAndExit(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _editBanner() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Iconsax.edit_2, size: 15, color: TripColors.accentDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  TripStringsV2Plan.editBanner,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TripColors.accentDark),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _addDayButton() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton.icon(
          onPressed: () {
            _c.addDay();
            TripUpdateAskSheet.afterDaysEdit();
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: TripColors.accent.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Iconsax.add_circle, size: 18, color: TripColors.accentDark),
          label: const Text(
            TripStringsV2Plan.addDay,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark),
          ),
        ),
      );

  Widget _emptyPlan() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: EmptyStateView(
          icon: Iconsax.routing_2,
          title: TripStringsV2Plan.noPlanTitle,
          subtitle: TripStringsV2Plan.noPlanSub,
          onRetry: () => TripLegMenuSheet.addPlaces(1, pickDay: 1),
          retryLabel: TripStringsV2Plan.addPlace,
          palette: TripColors.palette,
        ),
      );

  Widget _skeletons() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [for (var i = 0; i < 4; i++) const TripDayCardSkeleton()],
      );

  Widget _completeBar(BuildContext context) {
    if (!_c.isLastDayOrAfter || !_c.canComplete) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                TripStrings.lastDayDone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const Text(
                TripStrings.remindersStop,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textLight),
              ),
              const SizedBox(height: 8),
              GradientButton(
                label: TripStrings.markTripComplete,
                height: 52,
                gradient: TripColors.gradient,
                shadowColor: TripColors.accent,
                onPressed: () => TripLifecycleActions.markComplete(context),
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
      if (_c.needsUpdate.value) return const TripUpdateAppCard();
      if (_c.plannerOff.value || _c.plan.value == null || _c.isCompleted) return const SizedBox.shrink();
      final complete = _c.isLastDayOrAfter && _c.canComplete;
      final mini = !_c.editMode.value && _c.easyInProgress != null;
      final nav = !_c.editMode.value && !_c.isReadOnly && _c.planStep.value == 2;
      if (!complete && !mini && !nav) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mini)
            Center(
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
      );
    });
  }
}
