import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../services/storage_service.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_city_model.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_format.dart';
import '../utils/trip_wizard_rules.dart';
import '../widgets/trip_add_city_card.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_change_request_sheet.dart';
import '../widgets/trip_withdraw_sheet.dart';
import '../widgets/trip_hero_card.dart';
import '../widgets/trip_leg_header.dart';
import '../widgets/trip_lifecycle_actions.dart';
import '../widgets/trip_milestone_card.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_sheet_frame.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_step_dot.dart';
import '../widgets/trip_step_row.dart';
import '../widgets/trip_today_card.dart';
import '../widgets/trip_update_app_card.dart';
import '../widgets/trip_wishlist_sheet.dart';
import 'trip_details_sheet.dart';

class TripPlanScreen extends StatefulWidget {
  const TripPlanScreen({super.key});

  @override
  State<TripPlanScreen> createState() => _TripPlanScreenState();
}

enum _MenuAction { rename, summary, map, mute, complete }

class _TripPlanScreenState extends State<TripPlanScreen> with WidgetsBindingObserver {
  late final TripPlanController _c;
  bool _saving = false;
  final _scroll = ScrollController();
  final _rowsKey = GlobalKey();
  final Map<int, GlobalKey> _legKeys = {};
  Worker? _startWorker;
  Worker? _nextWorker;
  Worker? _nextTripWorker;
  Worker? _addedWorker;
  Worker? _linkPlanWorker;
  Worker? _linkOpenWorker;
  bool _nextOpening = false;
  String? _tripId;
  String? _step;
  int? _linkDay;
  DateTime? _linkDate;
  int? _linkLeg;
  bool _linkDone = true;
  String? _pickUpKey;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c.trip.value != null) _c.refreshEnquiries();
  }

  static int? _int(Object? v) => v is int ? v : (v is String ? int.tryParse(v) : null);

  static DateTime? _dateArg(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c = TripPlanController.to;
    _c.openPages++;
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    _tripId = map['tripId'] as String?;
    final fresh = map['fresh'] == true;
    final step = map['step'];
    _step = step is String && step.isNotEmpty ? step : null;
    _linkDay = _int(map['day']);
    _linkDate = _dateArg(map['date']);
    _linkLeg = _int(map['legIndex']);
    _linkDone = _step == null;
    final id = _tripId;
    if (_step == null && id != null && (fresh || _c.trip.value?.id != id || _c.plan.value == null)) {
      _pickUpKey = StorageService.getTripWizardLast(id);
    }
    _startWorker = ever<TripPlan?>(_c.plan, (_) => _checkStartFrom());
    _nextWorker = ever<TripCityModel?>(_c.pendingNextCity, (_) => _openPendingNext());
    _nextTripWorker = ever(_c.trip, (_) => _openPendingNext());
    _addedWorker = ever<int?>(_c.lastAddedLeg, _scrollToAdded);
    _linkPlanWorker = ever<TripPlan?>(_c.plan, (_) => _tryLink());
    _linkOpenWorker = ever<bool>(_c.isOpening, (_) => _tryLink());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStartFrom();
      _openPendingNext();
    });
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!fresh && _c.trip.value?.id == id && _c.plan.value != null) {
          _c.refreshEnquiries();
        } else {
          await _c.open(id, fresh: fresh);
        }
        _tryLink();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryLink());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startWorker?.dispose();
    _nextWorker?.dispose();
    _nextTripWorker?.dispose();
    _addedWorker?.dispose();
    _linkPlanWorker?.dispose();
    _linkOpenWorker?.dispose();
    _scroll.dispose();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _c)) {
      _c.openPages--;
      _c.releaseIfIdle();
    }
    super.dispose();
  }

  void _checkStartFrom() {
    if (!mounted || _c.plan.value == null || _c.startFrom != null || _c.isReadOnly) return;
    unawaited(_c.ensureStartFrom());
  }

  void _openPendingNext() {
    final next = _c.pendingNextCity.value;
    if (!mounted || _nextOpening || next == null || _c.trip.value == null || _c.isReadOnly) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _nextOpening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _nextOpening = false;
        return;
      }
      if (next.isReady) {
        await TripNavigation.openSpots(next, tripId: _c.trip.value?.id, newLeg: true);
      } else {
        await _c.addLeg(next, const []);
      }
      if (identical(_c.pendingNextCity.value, next)) _c.pendingNextCity.value = null;
      _nextOpening = false;
    });
  }

  void _tryLink() {
    if (_linkDone || !mounted) return;
    final id = _tripId;
    if (_c.isOpening.value || _c.plan.value == null || (id != null && _c.trip.value?.id != id)) return;
    if (_c.tripGone.value || _c.plannerOff.value) {
      _linkDone = true;
      return;
    }
    final steps = _c.wizardSteps;
    if (steps.isEmpty) return;
    _linkDone = true;
    final key = _resolve(steps);
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) _openStep(key);
    });
  }

  String? _resolve(List<TripStepInfo> steps) {
    final raw = _step;
    if (raw == null) return null;
    final parsed = TripStepKey.parse(raw);
    if (parsed != null) return steps.any((s) => s.key.id == parsed.id) ? parsed.id : null;
    final kind = TripWizardStepKind.parse(raw);
    switch (kind) {
      case TripWizardStepKind.stay || TripWizardStepKind.taxi || TripWizardStepKind.places:
        final day = (_linkDate != null ? _c.dayOfDate(_linkDate) : null) ?? _linkDay;
        if (day == null) return null;
        return steps.firstWhereOrNull((s) => s.key.kind == kind && s.day == day)?.key.id;
      case TripWizardStepKind.travel:
        final leg = _linkLeg;
        if (leg == null) return null;
        return steps.firstWhereOrNull((s) => s.key.kind == kind && s.key.legIndex == leg)?.key.id;
      case TripWizardStepKind.gettingThere || TripWizardStepKind.comingBack || TripWizardStepKind.basics:
        return steps.firstWhereOrNull((s) => s.key.kind == kind)?.key.id;
      case null:
        return null;
    }
  }

  void _openStep(String key) => TripNavigation.openStep(_c.trip.value?.id ?? _tripId ?? '', key);

  void _scrollToAdded(int? legIndex) {
    if (legIndex == null) return;
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

  Future<void> _save() async {
    if (_saving || _c.isSaving.value || _c.spotCount == 0) return;
    setState(() => _saving = true);
    await _c.saveNow(markPlanned: true);
    if (mounted) setState(() => _saving = false);
  }

  void _openSummary() {
    final id = _c.trip.value?.id;
    if (id != null) TripLifecycleActions.openSummary(id);
  }

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.rename:
        await _rename();
      case _MenuAction.summary:
        _openSummary();
      case _MenuAction.map:
        TripNavigation.openMap(day: _c.defaultMapDay, tripId: _c.trip.value?.id);
      case _MenuAction.mute:
        await TripLifecycleActions.toggleMute(context);
      case _MenuAction.complete:
        await TripLifecycleActions.markComplete(context);
    }
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _c.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(TripStringsWizard.renameTrip,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(80)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: const InputDecoration(hintText: TripStringsWizard.tripName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(TripStringsWizard.cancel, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text(TripStringsWizard.save,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || title == _c.title) return;
    await _c.rename(title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildNotSaved(),
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

  String? _subtitle() {
    final s = _c.settings;
    final start = s.startDate;
    final end = s.endDate(_c.dayCount);
    final dates = start == null || end == null ? null : TripFormat.dayMonthRange(start, end);
    final people = s.peopleSummary;
    if (dates == null) return null;
    return people == null ? dates : '$dates · $people';
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(4, top + 6, 4, 12),
      child: Obx(() {
        final plan = _c.plan.value;
        _c.trip.value;
        _c.needsUpdate.value;
        final off = _c.plannerOff.value;
        final pill = _headerPill();
        final sub = plan == null ? null : _subtitle();
        final editable = plan != null && !_c.isReadOnly && !_c.needsUpdate.value;
        return Row(
          children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan == null ? TripStringsWizard.trip : _c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      if (pill != null) ...[const SizedBox(width: 8), pill],
                    ],
                  ),
                  if (plan != null && !off)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: editable
                          ? () => TripDetailsSheet.edit(context,
                              heading: sub == null ? TripStringsWizard.addDates : null)
                          : null,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 28),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                sub ?? TripStringsWizard.addDates,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  decoration: sub == null ? TextDecoration.underline : null,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ),
                            if (editable) ...[
                              const SizedBox(width: 4),
                              Icon(Iconsax.edit_2, size: 13, color: Colors.white.withValues(alpha: 0.9)),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (plan != null && !off) _menu(),
          ],
        );
      }),
    );
  }

  Widget? _headerPill() {
    if (_c.isCompleted) return const TripBookingStatePill(TripBookingState.completed);
    if (_c.plan.value == null || !_c.isPastTrip) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: const Text(
        TripStrings.pastTrip,
        maxLines: 1,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }

  Widget _menu() {
    return PopupMenuButton<_MenuAction>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: _onMenu,
      itemBuilder: (_) {
        final saved = _c.trip.value != null;
        return [
          if (!_c.needsUpdate.value) _menuItem(_MenuAction.rename, Iconsax.edit_2, TripStringsWizard.rename),
          if (saved) _menuItem(_MenuAction.summary, Iconsax.receipt_text, TripStrings.summary),
          _menuItem(_MenuAction.map, Iconsax.map, TripStringsWizard.mapOfTrip),
          if (saved) _muteItem(),
          if (saved && _c.canComplete) _menuItem(_MenuAction.complete, Iconsax.tick_circle, TripStrings.markTripComplete),
        ];
      },
    );
  }

  PopupMenuItem<_MenuAction> _muteItem() {
    final muted = _c.trip.value?.isMuted ?? false;
    return PopupMenuItem(
      value: _MenuAction.mute,
      height: 52,
      child: Row(
        children: [
          const Icon(Iconsax.notification, size: 18, color: AppColors.textDark),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TripStrings.muteReminders,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark),
                ),
                Text(
                  TripStrings.eventAlertsStillCome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          IgnorePointer(child: Switch(value: muted, activeThumbColor: TripColors.accent, onChanged: (_) {})),
        ],
      ),
    );
  }

  PopupMenuItem<_MenuAction> _menuItem(_MenuAction value, IconData icon, String label, {Color color = AppColors.textDark}) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: color)),
          ],
        ),
      );

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
                        TripStrings.retry,
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
      final steps = _c.wizardSteps;
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
          TripHeroCard(
            onStep: _openStep,
            onWishlist: () => TripWishlistSheet.show(context, onPick: _openStep),
            onSummary: _openSummary,
            onSeeAll: () => _scrollTo(_rowsKey),
            pickUpKey: _pickUpKey,
          ),
          TripMilestoneCard(onStep: _openStep),
          const SizedBox(height: 8),
          KeyedSubtree(key: _rowsKey, child: const SizedBox.shrink()),
          ..._rows(plan, steps),
        ],
      );
    });
  }

  static String _rowTitle(TripStepInfo s) => switch (s.key.kind) {
        TripWizardStepKind.places => TripStringsWizard.places,
        TripWizardStepKind.taxi => TripStringsWizard.sightseeingTaxi,
        TripWizardStepKind.stay => TripStringsWizard.stay,
        _ => s.title,
      };

  String _group(TripStepInfo s) => switch (s.key.kind) {
        TripWizardStepKind.basics || TripWizardStepKind.gettingThere => 'before',
        TripWizardStepKind.travel => 'travel:${s.key.legIndex}',
        TripWizardStepKind.comingBack => 'end',
        _ => 'day:${s.day}',
      };

  List<Widget> _rows(TripPlan plan, List<TripStepInfo> steps) {
    final next = TripWizardRules.nextStep(steps);
    final readOnly = _c.isReadOnly;
    final out = <Widget>[];
    String? group;
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final g = _group(s);
      if (g != group) {
        if (g == 'end' && !readOnly && !_c.needsUpdate.value) {
          out.addAll([const SizedBox(height: 6), const TripAddCityCard(), const SizedBox(height: 10)]);
        }
        out.addAll(_groupHeader(plan, s, g));
        if (g == 'before') out.add(_undatedRow());
        group = g;
      }
      out.add(TripStepRow(
        key: ValueKey('step-${s.key.id}'),
        info: s,
        number: i + 1,
        title: _rowTitle(s),
        isNext: next?.key.id == s.key.id,
        readOnly: readOnly,
        onTap: () => _openStep(s.key.id),
      ));
    }
    return out;
  }

  List<Widget> _groupHeader(TripPlan plan, TripStepInfo s, String g) {
    if (g == 'before') return [_label(TripStringsWizard.groupBefore)];
    if (g == 'end') return [_label(TripStringsWizard.groupEnd(_leaveLabel()))];
    if (s.key.kind == TripWizardStepKind.travel) {
      final k = s.key.legIndex ?? 2;
      return [_label(TripStringsWizard.groupBetween(plan.legEnd(k - 1), plan.legStart(k)))];
    }
    final day = s.day ?? 1;
    final legIndex = plan.legIndexOf(day);
    final firstOfLeg = plan.legStart(legIndex) == day;
    final date = _c.dateOf(day);
    final start = _c.startOf(day);
    return [
      if (plan.isMultiCity && firstOfLeg)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TripLegHeader(key: ValueKey('trip-leg-$legIndex'), legIndex: legIndex, anchorKey: _legKey(legIndex)),
        ),
      _label(
        TripStringsWizard.groupDay(day, _c.cityNameOf(day), date == null ? null : TripFormat.shortDate(date)),
        sub: switch (start.kind) {
          TripStartKind.stay || TripStartKind.stayUnconfirmed || TripStartKind.ownStay => TripStringsWizard.startsAt(start.heading),
          TripStartKind.notChosen => TripStringsWizard.startNotChosen,
          TripStartKind.noStay => TripStringsWizard.startNoStay,
          TripStartKind.arrival || TripStartKind.checkOut => start.heading,
        },
      ),
    ];
  }

  String _leaveLabel() {
    final date = _c.stepDate(TripStepRole.comingBack);
    if (date == null) return TripStringsWizard.dateNotSet;
    final d = TripFormat.shortDate(date);
    return _c.steps.comingBack.leaveOnOrDefault == TripLeaveOn.lastDayEvening
        ? TripStringsWizard.leaveEvening(_c.dayCount, d)
        : TripStringsWizard.leaveCheckOut(d);
  }

  Widget _label(String text, {String? sub}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textLight)),
            if (sub != null)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
          ],
        ),
      );

  Widget _undatedRow() {
    final dated = _c.hasDates;
    final rows = dated ? _c.enquiriesOutsideDates : _c.undatedBookedRows;
    if (rows.isEmpty || _c.isReadOnly) return const SizedBox.shrink();
    final mark = TripStepMark.of(TripStepState.attention);
    return GestureDetector(
      onTap: () => _undatedSheet(rows),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TripStatusColors.failed.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            mark.badge(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(dated ? TripStringsWizard.outsideBookings(rows.length) : TripStringsWizard.undatedBookings(rows.length),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ),
            const Text(TripStringsWizard.fix,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.errorText)),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Future<void> _undatedSheet(List<TripEnquiryModel> rows) async {
    final dated = _c.hasDates;
    await TripSheetFrame.show<void>(
      context,
      Builder(
        builder: (sheetCtx) => TripSheetFrame(
          title: dated ? TripStringsWizard.outsideBookings(rows.length) : TripStringsWizard.undatedBookings(rows.length),
          description: dated ? TripStringsWizard.outsideHint : TripStringsWizard.undatedHint,
          footer: dated ? null : GradientButton(
            label: TripStringsWizard.addDates,
            height: 48,
            gradient: TripColors.gradient,
            shadowColor: TripColors.accent,
            onPressed: () {
              Navigator.pop(sheetCtx);
              TripDetailsSheet.edit(context, heading: TripStringsWizard.addDates);
            },
          ),
          children: [
            for (final e in rows)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Icon(e.isTaxi ? Iconsax.car : Iconsax.building_4, size: 18, color: AppColors.textMedium),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.listingName.isEmpty ? (e.isTaxi ? TripStrings.driver : TripStrings.stay) : e.listingName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          Text(e.datesLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                    if (dated && !e.isTaxi && e.isBooked)
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(sheetCtx);
                          final sent = await TripChangeRequestSheet.show(context, enquiry: e, prefill: _c.settings);
                          if (sent && mounted) await _c.refreshEnquiries();
                        },
                        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                        child: const Text(TripStringsWizard.changeDates,
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
                      ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        if (e.isBooked) {
                          TripCancelSheet.show(context, enquiry: e, ownerSide: false);
                        } else {
                          TripWithdrawSheet.show(context, enquiry: e);
                        }
                      },
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      child: Text(e.isBooked ? TripStringsWizard.cancel : TripStrings.withdraw,
                          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.error)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _skeletons() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          TripShimmers.rowBox(height: 170, radius: 18),
          const SizedBox(height: 18),
          for (var i = 0; i < 5; i++) const TripStepRowSkeleton(),
        ],
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
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
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
      if (_c.isPlanned) return _completeBar(context);
      final empty = _c.spotCount == 0;
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
                if (empty) ...[
                  const Text(
                    TripStringsA4.addPlaceToSave,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 8),
                ],
                GradientButton(
                  label: TripStrings.saveTrip,
                  height: 52,
                  isLoading: _saving || _c.isSaving.value,
                  gradient: TripColors.gradient,
                  shadowColor: TripColors.accent,
                  onPressed: empty ? null : _save,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
