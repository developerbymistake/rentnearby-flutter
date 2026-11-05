import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../models/browse_item.dart';
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
import '../trip_strings_mca_a3.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_add_city_card.dart';
import '../widgets/trip_day_tile.dart';
import '../widgets/trip_leg_chips.dart';
import '../widgets/trip_leg_header.dart';
import '../widgets/trip_leg_menu_sheet.dart';
import '../widgets/trip_lifecycle_actions.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_plan_hint_strip.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_status_card.dart';
import '../widgets/trip_step_card.dart';
import '../widgets/trip_step_skip_sheet.dart';
import '../widgets/trip_steps_strip.dart';
import '../widgets/trip_summary_strip.dart';
import '../widgets/trip_today_card.dart';
import '../widgets/trip_travel_tile.dart';
import '../widgets/trip_update_app_card.dart';
import 'trip_details_sheet.dart';

class TripPlanScreen extends StatefulWidget {
  const TripPlanScreen({super.key});

  @override
  State<TripPlanScreen> createState() => _TripPlanScreenState();
}

enum _MenuAction { rename, addPlaces, delete, myTrips, summary, mute, complete }

class _TripPlanScreenState extends State<TripPlanScreen> with WidgetsBindingObserver {
  late final TripPlanController _c;
  bool _saving = false;
  final _scroll = ScrollController();
  final _gettingKey = GlobalKey();
  final _comingKey = GlobalKey();
  final Map<int, GlobalKey> _dayKeys = {};
  final Map<int, GlobalKey> _legKeys = {};
  Worker? _startWorker;
  Worker? _nextWorker;
  Worker? _nextTripWorker;
  Worker? _addedWorker;
  bool _nextOpening = false;

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
    final args = Get.arguments;
    final tripId = args is Map ? args['tripId'] as String? : null;
    final fresh = args is Map && args['fresh'] == true;
    _startWorker = ever<TripPlan?>(_c.plan, (_) => _checkStartFrom());
    _nextWorker = ever<TripCityModel?>(_c.pendingNextCity, (_) => _openPendingNext());
    _nextTripWorker = ever(_c.trip, (_) => _openPendingNext());
    _addedWorker = ever<int?>(_c.lastAddedLeg, _scrollToAdded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStartFrom();
      _openPendingNext();
    });
    if (tripId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!fresh && _c.trip.value?.id == tripId && _c.plan.value != null) {
          _c.refreshEnquiries();
        } else {
          _c.open(tripId, fresh: fresh);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startWorker?.dispose();
    _nextWorker?.dispose();
    _nextTripWorker?.dispose();
    _addedWorker?.dispose();
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

  void _scrollToAdded(int? legIndex) {
    if (legIndex == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _scrollTo(_legKey(legIndex));
      if (_c.lastAddedLeg.value == legIndex) _c.lastAddedLeg.value = null;
    });
  }

  GlobalKey _dayKey(int day) => _dayKeys.putIfAbsent(day, () => GlobalKey());

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

  void _onStep(TripStepKind kind) {
    switch (kind) {
      case TripStepKind.itinerary:
        _scrollTo(_dayKey(1));
      case TripStepKind.gettingThere:
        _scrollTo(_gettingKey);
      case TripStepKind.stay:
        _scrollTo(_dayKey(_c.stayStep.firstUnsorted ?? 1));
      case TripStepKind.localTaxi:
        _scrollTo(_dayKey(_c.taxiStep.firstUnsorted ?? 1));
      case TripStepKind.comingBack:
        _scrollTo(_comingKey);
    }
  }

  void _onStepLong(TripStepKind kind) => TripStepSkipSheet.show(context, step: kind);

  Future<void> _save() async {
    if (_saving || _c.isSaving.value || _c.spotCount == 0) return;
    setState(() => _saving = true);
    await _c.saveNow(markPlanned: true);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.rename:
        await _rename();
      case _MenuAction.addPlaces:
        _addPlaces();
      case _MenuAction.delete:
        await _delete();
      case _MenuAction.summary:
        final id = _c.trip.value?.id;
        if (id != null) TripLifecycleActions.openSummary(id);
      case _MenuAction.mute:
        await TripLifecycleActions.toggleMute(context);
      case _MenuAction.complete:
        await TripLifecycleActions.markComplete(context);
      case _MenuAction.myTrips:
        if (Get.previousRoute == AppRoutes.myTrips) {
          Get.back();
        } else {
          TripNavigation.replaceWithMyTrips();
        }
    }
  }

  Future<void> _askAgain(bool taxi, int day) async {
    final batch = await _c.askAgain(kind: taxi ? TripEnquiryKinds.taxi : TripEnquiryKinds.stay, day: day);
    if (batch == null) return;
    if (taxi) {
      TripNavigation.openTaxiReplies(day);
    } else {
      TripNavigation.openReplies(day);
    }
  }

  void _addPlaces() {
    final picked = _c.picked;
    final plan = _c.plan.value;
    if (plan != null && plan.isMultiCity) {
      TripLegMenuSheet.addPlaces(plan.legCount);
      return;
    }
    if (picked == null || plan == null) return;
    TripNavigation.openSpots(picked, tripId: _c.trip.value?.id, existingIds: plan.spotIds);
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _c.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename trip', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(80)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: const InputDecoration(hintText: 'Trip name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || title == _c.title) return;
    await _c.rename(title);
  }

  Future<void> _delete() async {
    final hosts = {
      for (final e in _c.enquiries)
        if (e.isOpen) e.owner.id ?? e.listingId,
    }.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(TripStrings.deleteTrip, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: Text(hosts > 0 ? TripStrings.deleteTripTold(hosts) : 'This cannot be undone.',
            style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await _c.deleteTrip()) Get.until((r) => r.settings.name == AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildNotSaved(),
          _buildSteps(),
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

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 4, 16),
      child: Obx(() {
        final plan = _c.plan.value;
        _c.trip.value;
        _c.isSaving.value;
        final off = _c.plannerOff.value;
        final days = _c.dayCount;
        final spots = _c.spotCount;
        _c.enquiryList.length;
        _c.result.value;
        _c.needsUpdate.value;
        final saved =(_c.isPlanned || _c.isCompleted) && !_c.saveFailed.value && !_c.isSaving.value;
        final completed = _c.isCompleted;
        final pill = _headerPill();
        final overDay = plan == null ? null : _overLimitDay(plan);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan == null ? 'Trip' : _c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                          if (pill != null) ...[
                            const SizedBox(width: 8),
                            pill,
                          ],
                        ],
                      ),
                      if (plan != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$days ${days == 1 ? 'day' : 'days'} · $spots ${spots == 1 ? 'spot' : 'spots'}'
                                '${plan.isMultiCity ? ' · ${TripStringsMcaA3.cities(plan.legCount)}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _subtitleStyle,
                              ),
                            ),
                            if (saved) ...[
                              Text(' · ', style: _subtitleStyle),
                              const Icon(Iconsax.tick_circle, size: 14, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(TripStrings.saved, style: _subtitleStyle),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (plan != null && !off) ...[
                  _mapChip(),
                  _menu(),
                ],
              ],
            ),
            if (plan != null && !off)
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 4, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _datesChip(plan.settings, days),
                    _peopleChip(plan.settings),
                    _headerChip(Iconsax.timer_1, plan.settings.paceLabel),
                  ],
                ),
              ),
            if (plan != null && !off && overDay != null && !completed)
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 8, 12, 0),
                child: Row(
                  children: [
                    const Icon(Iconsax.warning_2, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        TripStringsA4.overLimitHint(overDay),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _subtitleStyle,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }

  int? _overLimitDay(TripPlan plan) {
    if (plan.settings.maxDays == null) return null;
    for (final d in plan.days) {
      if (d.spots.isNotEmpty && _c.isOverLimit(d.day)) return d.day;
    }
    return null;
  }

  Widget? _headerPill() {
    if (_c.isCompleted) return const TripBookingStatePill(TripBookingState.completed);
    if (_c.plan.value == null) return null;
    if (_c.isPastTrip) {
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
    if (_c.isPlanned && _isPlanOnly()) return const TripBookingStatePill(TripBookingState.planOnly);
    return null;
  }

  bool _isPlanOnly() {
    if (_c.spotCount == 0) return false;
    if (!_c.hasDates) return true;
    final live = _c.enquiryList.any((e) => e.isOpen || e.isBooked);
    return !_c.hasChoice && !live;
  }

  static final TextStyle _subtitleStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white.withValues(alpha: 0.85),
  );

  Widget _datesChip(TripSettings settings, int days) {
    final start = settings.startDate;
    final end = settings.endDate(days);
    if (start == null || end == null) {
      return _headerChip(Iconsax.calendar_add, TripStrings.addDates, outlined: true);
    }
    return _headerChip(Iconsax.calendar_1, TripFormat.dateRange(start, end));
  }

  Widget _peopleChip(TripSettings settings) {
    final people = settings.peopleSummary;
    if (people == null) return _headerChip(Iconsax.people, TripStrings.addPeople, outlined: true);
    final rooms = settings.roomsSummary;
    return _headerChip(Iconsax.people, rooms == null ? people : '$people · $rooms');
  }

  Widget _headerChip(IconData icon, String label, {bool outlined = false}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Align(
        widthFactor: 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _c.isReadOnly || _c.needsUpdate.value ? null : () => TripDetailsSheet.edit(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: outlined ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: outlined ? 0.7 : 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapChip() {
    return GestureDetector(
      onTap: () => TripNavigation.openMap(day: _c.defaultMapDay),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.map, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text('Map', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
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
        final editable = !_c.isReadOnly && !_c.needsUpdate.value;
        return [
          if (!_c.needsUpdate.value) _menuItem(_MenuAction.rename, Iconsax.edit_2, 'Rename'),
          if (editable) _menuItem(_MenuAction.addPlaces, Iconsax.add_circle, TripStringsA4.addPlaces),
          if (saved) _menuItem(_MenuAction.summary, Iconsax.receipt_text, TripStrings.summary),
          if (saved) _muteItem(),
          if (saved && _c.canComplete)
            _menuItem(_MenuAction.complete, Iconsax.tick_circle, TripStrings.markTripComplete),
          _menuItem(_MenuAction.myTrips, Iconsax.routing_2, TripStrings.myTrips),
          _menuItem(_MenuAction.delete, Iconsax.trash, 'Delete trip', color: AppColors.error),
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
          Icon(Iconsax.notification, size: 18, color: AppColors.textDark),
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
          IgnorePointer(
            child: Switch(
              value: muted,
              activeThumbColor: TripColors.accent,
              onChanged: (_) {},
            ),
          ),
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
                      onPressed: () => _c.saveNow(),
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

  bool get _showSteps =>
      _c.plan.value != null &&
      !_c.tripGone.value &&
      !_c.plannerOff.value &&
      !_c.needsUpdate.value &&
      !(_c.isPlanning.value && _c.result.value == null && !_c.planFailed.value);

  Widget _buildSteps() {
    return Obx(() {
      _c.trip.value;
      if (!_showSteps) return const SizedBox.shrink();
      final multi = _c.plan.value?.isMultiCity ?? false;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TripStepsStrip(onTap: _onStep, onLongPress: _c.isReadOnly ? null : _onStepLong),
                if (multi) ...[
                  const SizedBox(height: 6),
                  TripLegChips(onTap: (k) => _scrollTo(_legKey(k))),
                ],
              ],
            ),
          ),
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
      final steps = !_c.needsUpdate.value;
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
          _offlineStrip(),
          const TripTodayCard(),
          if (steps) ...[
            TripStepCard(role: TripStepRole.gettingThere, anchorKey: _gettingKey),
            const SizedBox(height: 14),
          ],
          if (!plan.isMultiCity) const TripPlanHintStrip(),
          if (!_c.isReadOnly) _redBanner(),
          ...(plan.isMultiCity
              ? [for (var k = 1; k <= plan.legCount; k++) ..._legSection(plan, k)]
              : [for (final d in plan.days) ..._dayTile(d.day)]),
          if (!_c.isReadOnly && !_c.needsUpdate.value) ...[
            const TripAddCityCard(),
            const SizedBox(height: 14),
          ],
          if (steps && plan.days.isNotEmpty) ...[
            TripStepCard(role: TripStepRole.comingBack, anchorKey: _comingKey),
            const SizedBox(height: 14),
          ],
          ..._outsideDates(),
          const TripSummaryStrip(),
        ],
      );
    });
  }

  List<Widget> _dayTile(int day) => [
        KeyedSubtree(key: _dayKey(day), child: TripDayTile(day, key: ValueKey('trip-day-$day'))),
        const SizedBox(height: 14),
      ];

  List<Widget> _legSection(TripPlan plan, int k) => [
        if (k >= 2) ...[
          TripTravelTile(key: ValueKey('trip-travel-$k'), legIndex: k),
          const SizedBox(height: 12),
        ],
        TripLegHeader(key: ValueKey('trip-leg-$k'), legIndex: k, anchorKey: _legKey(k)),
        TripPlanHintStrip(key: ValueKey('trip-hint-$k'), legIndex: k),
        for (final d in plan.daysOf(k)) ..._dayTile(d.day),
      ];

  Widget _offlineStrip() {
    if (!_c.offline.value || _c.todayDay != null || _c.isCompleted) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(12)),
        child: const Row(
          children: [
            Icon(Iconsax.cloud_cross, size: 16, color: AppColors.textMedium),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                TripStrings.offlineSaved,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _redBanner() {
    if (_c.bannerDismissed.value || _c.isCompleted) return const SizedBox.shrink();
    final stayDay = _c.showStayOption ? _c.firstRedDay : null;
    final taxiDay = stayDay == null && _c.showTaxiOption ? _c.firstRedTaxiDay : null;
    final day = stayDay ?? taxiDay;
    final e = stayDay != null
        ? _c.primaryEnquiry(stayDay)
        : (taxiDay != null ? _c.primaryTaxiEnquiry(taxiDay) : null);
    if (day == null || e == null) return const SizedBox.shrink();
    final taxi = taxiDay != null;
    final label = e.display == TripDisplayStatus.cancelled && e.cancelledBy == 'owner'
        ? TripStrings.hostCancelled
        : TripStatusVisuals.label(e.display, taxi: taxi);
    final again = _c.canAskAgain(taxi ? TripEnquiryKinds.taxi : TripEnquiryKinds.stay, day);
    final text = taxi
        ? (again ? '${e.listingName} · $label.' : '${e.listingName} · $label. ${TripStrings.askAnother} ›')
        : (again ? '$label.' : '$label. ${TripStrings.findAnother} ›');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: TripStatusColors.failedSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => taxi ? TripNavigation.openTaxiReplies(day) : TripNavigation.openReplies(day),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Iconsax.warning_2, size: 16, color: TripStatusColors.failed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.errorText),
                  ),
                ),
                if (again)
                  TextButton(
                    onPressed: _c.askBusy.value ? null : () => _askAgain(taxi, day),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      TripStrings.askAgain,
                      maxLines: 1,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripStatusColors.failed),
                    ),
                  ),
                IconButton(
                  onPressed: () => _c.bannerDismissed.value = true,
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.errorText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _outsideDates() {
    final items = _c.enquiriesOutsideDates;
    if (items.isEmpty) return const [];
    return [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          TripStrings.notInDates,
          style: TextStyle(
              fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textLight),
        ),
      ),
      for (final e in items) ...[
        TripStatusCard(
          key: ValueKey('outside-${e.id}'),
          status: e.display,
          onTap: () => e.isTaxi
              ? TripNavigation.openTaxiReplies(e.days.isEmpty ? 1 : e.days.first, enquiryId: e.id)
              : TripNavigation.openReplies(e.day ?? 1, enquiryId: e.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(e.isTaxi ? Iconsax.car : Iconsax.building_4, size: 15, color: AppColors.textMedium),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      e.listingName.isEmpty ? (e.isTaxi ? TripStrings.driver : TripStrings.stay) : e.listingName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: TripStatusPill(e.display, taxi: e.isTaxi)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _outsidePrice(e) == null ? e.datesLabel : TripStrings.oldDates(e.datesLabel, BrowseItem.inr(_outsidePrice(e)!)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 4),
    ];
  }

  static int? _outsidePrice(TripEnquiryModel e) =>
      e.isTaxi ? (e.taxi?.agreedFare ?? e.taxi?.driverFare) : (e.agreedTotal ?? e.openOffer?.total);

  Widget _skeletons() => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, _) => const TripDayTileSkeleton(),
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
