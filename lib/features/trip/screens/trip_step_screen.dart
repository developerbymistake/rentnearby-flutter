import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/pulse_once.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_wizard_controller.dart';
import '../../../models/browse_item.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';
import '../widgets/trip_accept_sheet.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_mcb_a1.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_format.dart';
import '../utils/trip_wizard_rules.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_day_spot_list.dart';
import '../widgets/trip_going_home_row.dart';
import '../widgets/trip_leg_menu_sheet.dart';
import '../widgets/trip_night_chooser.dart';
import '../widgets/trip_no_taxi_flow.dart';
import '../widgets/trip_own_booking_sheet.dart';
import '../widgets/trip_phone_booking_sheet.dart';
import '../widgets/trip_start_card.dart';
import '../widgets/trip_step_dot.dart';
import '../widgets/trip_step_journey_body.dart';
import '../widgets/trip_taxi_booking_sheet.dart';
import '../widgets/trip_withdraw_sheet.dart';
import '../widgets/trip_wrong_city_strip.dart';
import 'trip_details_sheet.dart';

class TripStepScreen extends StatefulWidget {
  const TripStepScreen({super.key});

  @override
  State<TripStepScreen> createState() => _TripStepScreenState();
}

class _TripStepScreenState extends State<TripStepScreen> {
  late final TripPlanController _c;
  late final TripWizardController _w;
  late final String _tripId;
  late final String _tag;
  final Map<String, bool> _counted = {};
  final Set<int> _supplyRetried = {};
  int? _placesDay;
  int _pulse = 0;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _c = TripPlanController.to;
    _c.openPages++;
    _tripId = (args is Map ? args['tripId'] as String? : null) ?? _c.trip.value?.id ?? '';
    final key = (args is Map ? args['key'] as String? : null) ?? '';
    _tag = TripWizardController.nextTag(_tripId);
    _w = Get.put(TripWizardController(_tripId, key), tag: _tag);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _w.route ??= ModalRoute.of(context);
  }

  @override
  void dispose() {
    final seen = _placesDay;
    if (seen != null) {
      final c = _c;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.clearStartNote(seen));
    }
    if (Get.isRegistered<TripWizardController>(tag: _tag)) Get.delete<TripWizardController>(tag: _tag);
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _c)) {
      _c.openPages--;
      _c.releaseIfIdle();
    }
    super.dispose();
  }

  bool _readOnlyFor(int? day) =>
      _c.isReadOnly || _c.needsUpdate.value || (day != null && _c.isDayPast(day));

  void _watchPlaces(TripStepInfo? cur) {
    final day = cur?.key.kind == TripWizardStepKind.places ? cur?.day : null;
    final seen = _placesDay;
    if (seen == day) return;
    _placesDay = day;
    if (seen != null) WidgetsBinding.instance.addPostFrameCallback((_) => _c.clearStartNote(seen));
  }

  void _watchDone(TripStepInfo cur) {
    final was = _counted[cur.key.id];
    _counted[cur.key.id] = cur.counted;
    if (was == false && cur.counted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pulse++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) TripNavigation.backToList();
      },
      child: Obx(() {
        _c.plan.value;
        _c.trip.value;
        _c.netOff;
        _c.enquiryList.length;
        _c.result.value;
        _w.currentKey.value;
        final steps = _w.steps;
        final cur = _w.current;
        if (cur != null) _watchDone(cur);
        _watchPlaces(cur);
        final p = TripWizardRules.progress(steps);
        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: Column(
            children: [
              _header(context, cur, steps.length),
              LinearProgressIndicator(
                value: p.total == 0 ? 0 : p.percent / 100,
                minHeight: 4,
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation(TripColors.accent),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: cur == null
                        ? (_c.plan.value == null && !_c.isOpening.value
                            ? EmptyStateView(
                                icon: Iconsax.cloud_cross,
                                title: TripStrings.placesFailed,
                                subtitle: TripStrings.checkConnection,
                                onRetry: TripNavigation.backToList,
                                retryLabel: 'Back to trip',
                                palette: TripColors.palette,
                              )
                            : const Center(child: CircularProgressIndicator(color: TripColors.accent)))
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(key: ValueKey(cur.key.id), child: _body(context, cur)),
                          ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: cur == null ? null : _footer(context),
        );
      }),
    );
  }

  String _subtitle(TripStepInfo cur, int total) {
    final i = _w.index + 1;
    final day = cur.day;
    final leg = cur.legIndex;
    final place = day != null
        ? _c.cityNameOf(day)
        : (leg != null ? (_c.legAt(leg)?.cityName ?? _c.title) : _c.title);
    return TripStringsWizard.stepOf(place, i, total);
  }

  Widget _header(BuildContext context, TripStepInfo? cur, int total) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(4, top + 6, 8, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: TripNavigation.backToList,
            tooltip: TripStringsWizard.list,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cur?.title ?? _c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (cur != null)
                  Text(
                    _subtitle(cur, total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
              ],
            ),
          ),
          if (_c.isReadOnly) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: const Text(TripStrings.pastTrip,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 4),
          ],
          TextButton.icon(
            onPressed: TripNavigation.backToList,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Iconsax.task_square, size: 18, color: Colors.white),
            label: const Text(TripStringsWizard.list,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) => TripStepFooter(
        showPrev: !_w.isFirst,
        nextTitle: _w.following?.title,
        pulse: _pulse,
        onPrev: _w.prev,
        onNext: _w.next,
        onDone: TripNavigation.backToList,
        openCount: _w.openCount,
        onSkipRest: () => _confirmSkipRest(context),
      );

  Future<void> _confirmSkipRest(BuildContext context) async {
    final n = _w.openCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Skip the rest?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17)),
        content: Text('$n open ${n == 1 ? 'step' : 'steps'} will be marked as arranged by you. You can change any later.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Skip',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    if (ok == true) _w.skipRest();
  }

  Widget _body(BuildContext context, TripStepInfo cur) {
    final children = switch (cur.key.kind) {
      TripWizardStepKind.basics => _basics(context, cur),
      TripWizardStepKind.gettingThere => [
          TripJourneyStepBody(role: TripStepRole.gettingThere, state: _stateBlock(cur)),
        ],
      TripWizardStepKind.comingBack => [
          TripJourneyStepBody(role: TripStepRole.comingBack, state: _stateBlock(cur), extra: Column(children: [const TripGoingHomeRow(), _leaveChooser()])),
        ],
      TripWizardStepKind.travel => [
          TripJourneyStepBody(legIndex: cur.legIndex ?? cur.key.legIndex, state: _stateBlock(cur)),
        ],
      TripWizardStepKind.places => _places(context, cur),
      TripWizardStepKind.taxi => _taxi(context, cur),
      TripWizardStepKind.stay => _stay(context, cur),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: children,
    );
  }

  TripEnquiryModel? _row(String? id) => id == null ? null : _c.enquiryList.firstWhereOrNull((e) => e.id == id);

  Widget _stateBlock(TripStepInfo cur, {String? sub, Color? subColor}) {
    final mark = TripStepMark.of(cur.state);
    final extra = [?cur.note, ?sub].join(' · ');
    final extraColor = subColor ??
        (cur.state == TripStepState.todo || cur.state == TripStepState.own || cur.state == TripStepState.skipped
            ? AppColors.textMedium
            : AppColors.warningText);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mark.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mark.badge(size: 28, pop: cur.state == TripStepState.done, reduceMotion: reduceMotion),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(TripStringsWizard.stateLabel(cur.state, needsYou: cur.needsYou, kind: cur.key.kind),
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: mark.text)),
                Text(cur.line,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600, color: mark.text)),
                if (extra.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(extra,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: extraColor)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _question(String heading, String? sub) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            if (sub != null)
              Text(sub, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ],
        ),
      );

  Widget _infoLine(String text, {IconData icon = Iconsax.info_circle, Color color = AppColors.textLight}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      );

  Widget _addDatesLine() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Iconsax.calendar_add, size: 16, color: AppColors.warningText),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(TripStringsWizard.addDatesToAsk,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.warningText)),
            ),
            TextButton(
              onPressed: () => TripDetailsSheet.edit(context, heading: TripStringsMcbA1.addDatesFirst),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text(TripStringsWizard.addDates,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.warningText)),
            ),
          ],
        ),
      );

  Widget _primary(String label, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GradientButton(
          label: label,
          height: 48,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: onTap,
        ),
      );

  Widget _option(IconData icon, String label, VoidCallback? onTap, {Color color = TripColors.accentDark}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: color),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            alignment: Alignment.centerLeft,
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _netPrimary(String label, VoidCallback? onTap) => _c.netOff ? const SizedBox.shrink() : _primary(label, onTap);

  Widget _netOption(IconData icon, String label, VoidCallback? onTap, {Color color = TripColors.accentDark}) =>
      _c.netOff ? const SizedBox.shrink() : _option(icon, label, onTap, color: color);

  Widget _offlineLine(bool readOnly) => _c.netOff && !readOnly
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoLine(TripStringsWizard.connectToAsk, icon: Iconsax.wifi_square, color: AppColors.warningText),
            _textAction(TripStrings.retry, () => _c.retryConnection()),
          ],
        )
      : const SizedBox.shrink();

  Widget _textAction(String label, VoidCallback onTap, {Color color = TripColors.accentDark}) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 4)),
          child: Text(label,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ),
      );

  List<Widget> _basics(BuildContext context, TripStepInfo cur) {
    final s = _c.settings;
    final start = s.startDate;
    final end = s.endDate(_c.dayCount);
    final readOnly = _readOnlyFor(null);
    void edit() {
      if (!readOnly) TripDetailsSheet.edit(context);
    }

    final people = s.peopleSummary;
    final rooms = s.roomsSummary;
    return [
      _question(TripStringsWizard.basicsQuestion, TripStringsWizard.basicsHint),
      _stateBlock(cur),
      const SizedBox(height: 12),
      _detailRow(Iconsax.calendar_1, TripStringsWizard.dates,
          start == null || end == null ? null : TripFormat.dateRange(start, end), TripStringsWizard.addDates, edit),
      _detailRow(Iconsax.people, TripStringsWizard.people,
          people == null ? null : (rooms == null ? people : '$people · $rooms'), TripStringsWizard.addPeople, edit),
      _detailRow(Iconsax.timer_1, TripStringsWizard.pace, s.paceLabel, null, edit),
      _detailRow(Iconsax.location, TripStringsWizard.startingCity, _c.startFrom?.name, TripStringsWizard.addStartingCity, edit),
    ];
  }

  Widget _detailRow(IconData icon, String label, String? value, String? empty, VoidCallback onTap) {
    final missing = value == null || value.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: missing ? TripColors.accent.withValues(alpha: 0.5) : AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: TripColors.accentDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
                      Text(missing ? (empty ?? '') : value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: missing ? TripColors.accentDark : AppColors.textDark)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _switchLeave(TripLeaveOn value) async {
    final rows = _c.leaveImpact(value);
    if (rows.isEmpty) return _c.setLeaveOn(value);
    final booked = rows.any((e) => e.isBooked);
    Widget action(BuildContext ctx, String label, bool? result, {bool strong = false, Color? color}) => TextButton(
          onPressed: () => Navigator.pop(ctx, result),
          style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                  color: color ?? (strong ? TripColors.accentDark : AppColors.textMedium))),
        );
    final cancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(TripStringsWizard.leaveChangeTitle,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(TripStringsWizard.leaveChangeBody,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
            const SizedBox(height: 8),
            for (final e in rows)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(TripStringsWizard.leaveCar(e.context.journeyLegIndex ?? 1, e.listingName, e.isBooked),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ),
          ],
        ),
        actions: [
          action(ctx, TripStringsWizard.notNow, null),
          if (booked) action(ctx, TripStringsWizard.cancelBookings, true, color: AppColors.error),
          action(ctx, booked ? TripStringsWizard.keepBookings : TripStringsWizard.changeTime, false, strong: true),
        ],
      ),
    );
    if (cancel == null || !mounted) return;
    await _c.setLeaveOn(value, cancelBooked: cancel);
  }

  Widget _leaveChooser() {
    final n = _c.dayCount;
    final evening = _c.steps.comingBack.leaveOn == TripLeaveOn.lastDayEvening;
    final readOnly = _readOnlyFor(null);
    final outDate = _c.dateOf(n + 1);
    final lastDate = _c.dateOf(n);
    Widget row(bool on, String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: on ? TripColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: readOnly || on ? null : onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? TripColors.accent : AppColors.divider, width: on ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 20, color: on ? TripColors.accentDark : AppColors.textHint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: on ? TripColors.accentDark : AppColors.textDark)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    final nightHasStay = evening && (_c.plan.value?.dayAt(n)?.stay?.isSkipped == false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(TripStringsWizard.whenLeave,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        row(!evening, TripStringsWizard.checkOutMorning(outDate == null ? null : TripFormat.shortDate(outDate)),
            () => _switchLeave(TripLeaveOn.checkOut)),
        row(evening, TripStringsWizard.dayEvening(n, lastDate == null ? null : TripFormat.shortDate(lastDate)),
            () => _switchLeave(TripLeaveOn.lastDayEvening)),
        if (nightHasStay) _infoLine(TripStringsWizard.leaveButStay(n), icon: Iconsax.warning_2, color: AppColors.warningText),
      ],
    );
  }

  List<Widget> _places(BuildContext context, TripStepInfo cur) {
    final d = cur.day ?? 1;
    final plan = _c.plan.value;
    final day = plan?.dayAt(d);
    final legIndex = plan?.legIndexOf(d) ?? 1;
    final readOnly = _readOnlyFor(d);
    final spots = day?.spots.length ?? 0;
    final notReady = (plan?.legAt(legIndex)?.notReady ?? false) || _c.legUnavailable(legIndex);
    final rest = cur.state == TripStepState.skipped;
    return [
      TripStartCard(day: d, showMap: spots > 0),
      const SizedBox(height: 16),
      _question(TripStringsWizard.placesQuestion(d), null),
      _stateBlock(cur),
      const SizedBox(height: 12),
      if (notReady && spots == 0) _infoLine(TripStringsWizard.cityNotReady),
      if (rest) ...[
        if (!readOnly) _option(Iconsax.undo, TripStringsWizard.undo, () => _c.setRestDay(d, false)),
      ] else ...[
        TripDaySpotList(d),
        if (spots > 0) _timeLeft(d),
        if (!readOnly && !notReady) _option(Iconsax.add_circle, TripStringsWizard.addPlace,
            () => TripLegMenuSheet.addPlaces(legIndex, pickDay: d)),
        if (!readOnly && notReady) _option(Iconsax.add_circle, TripStringsWizard.addPlace,
            () => TripLegMenuSheet.addPlaces(legIndex)),
        if (spots > 0)
          _option(Iconsax.map, TripStringsWizard.seeRouteOnMap, () => TripNavigation.openMap(day: d, tripId: _tripId)),
        if (!readOnly && spots == 0) _option(Iconsax.coffee, TripStringsWizard.noPlacesThisDay, () => _c.setRestDay(d, true)),
      ],
    ];
  }

  Widget _timeLeft(int d) {
    final left = _c.dayMinutesLeft(d);
    return left >= 0
        ? _infoLine(TripStringsWizard.timeLeftToday(TripFormat.duration(left)), icon: Iconsax.timer_1)
        : _infoLine(TripStringsWizard.overBy(TripFormat.duration(-left)), icon: Iconsax.warning_2, color: AppColors.warningText);
  }

  void _ensureTaxiSupply(int d) {
    if (_readOnlyFor(d) || !_c.supplyAvailableFor(d) || _c.taxiSupplyFor(d) != null) return;
    final leg = _c.plan.value?.legIndexOf(d) ?? 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.ensureSupply(leg));
  }

  List<Widget> _taxi(BuildContext context, TripStepInfo cur) {
    final d = cur.day ?? 1;
    final id = cur.key.id;
    final readOnly = _readOnlyFor(d);
    _c.taxiSupplyByLeg.length;
    _c.taxiTabOff.value;
    _ensureTaxiSupply(d);
    final rows = _c.taxiEnquiriesForDay(d);
    final booked = _row(cur.enquiryId) ?? _c.bookedTaxiEnquiryFor(d);
    final hint = _c.journeyHintFor(d);
    final updates = _c.driverUpdatesFor(d);
    final taxi = _c.plan.value?.dayAt(d)?.taxi;
    final out = <Widget>[
      _question(TripStringsWizard.taxiQuestion(d), TripStringsWizard.taxiCounts),
      _stateBlock(cur),
      if (hint != null) _infoLine(hint, icon: Iconsax.car),
      if (!_c.hasDates && !readOnly) _addDatesLine(),
      _offlineLine(readOnly),
    ];
    if (updates.isNotEmpty && !readOnly) {
      for (final e in rows.where((e) => updates.containsKey(e.id))) {
        final phone = e.owner.phone;
        if (phone == null || ContactLauncher.tenDigits(phone).isEmpty) continue;
        out.add(_option(Iconsax.message, TripStringsWizard.tellDriverNamed(e.listingName), () async {
          final message = _c.driverUpdateMessage(d, e.listingName);
          await TripEnquiryController.to.updateLead(e.id);
          await ContactLauncher.whatsApp(phone, message: message);
        }));
        out.add(_option(Iconsax.call, TripStringsWizard.callDriverNamed(e.listingName), () async {
          await TripEnquiryController.to.updateLead(e.id);
          await ContactLauncher.call(phone);
        }));
      }
    }
    if (readOnly) return out;
    final own = _c.ownTaxiOf(d);
    final conflict = cur.state == TripStepState.attention &&
        (taxi?.isSkipped == true || taxi?.isOwn == true) &&
        booked != null &&
        booked.isBooked &&
        !_c.wrongOnDay(booked, d);
    if (conflict) {
      out.addAll([
        _primary(TripStringsWizard.keepBooking, () => _c.clearTaxi(d)),
        _option(Iconsax.close_circle, TripStringsWizard.keepOwn,
            () => TripCancelSheet.show(context, enquiry: booked, ownerSide: false)),
      ]);
      return out;
    }
    switch (cur.state) {
      case TripStepState.todo:
        out.addAll(_taxiFinder(d, id));
        out.addAll(_taxiOwnOptions(d));
      case TripStepState.waiting:
        if (rows.isNotEmpty) out.add(_netPrimary(TripStringsWizard.seeReplies, () => TripNavigation.openTaxiReplies(d, fromStep: id)));
        if (booked != null && booked.status == TripEnquiryStatuses.bookedByTraveller) {
          out.add(_option(Iconsax.edit_2, TripStringsWizard.editBooking,
              () => TripTaxiBookingSheet.show(context, taxi: null, day: d, enquiry: booked)));
          final phone = _driverPhone(booked);
          if (phone != null) out.add(_option(Iconsax.call, TripStringsWizard.callDriver, () => ContactLauncher.call(phone)));
          out.add(_option(Iconsax.close_circle, TripStringsWizard.cancelBooking,
              () => TripCancelSheet.show(context, enquiry: booked, ownerSide: false), color: AppColors.error));
        }
        if (_c.canFindTaxiOn(d)) {
          out.add(rows.isEmpty
              ? _netPrimary(TripStringsWizard.askDriver, () => TripNavigation.openTaxi(d, fromStep: id))
              : _netOption(Iconsax.search_normal, TripStringsWizard.findAnotherDriver,
                  () => TripNavigation.openTaxi(d, fromStep: id)));
        }
        out.addAll(_taxiOwnOptions(d));
      case TripStepState.attention:
        final problem = _row(cur.enquiryId);
        if (_c.canAskAgain(TripEnquiryKinds.taxi, d)) {
          out.add(_netPrimary(TripStringsWizard.askAgain, () => _askAgain(TripEnquiryKinds.taxi, d, id)));
        }
        if (rows.isNotEmpty) out.add(_netOption(Iconsax.receipt_text, TripStringsWizard.seeReplies, () => TripNavigation.openTaxiReplies(d, fromStep: id)));
        if (_c.canFindTaxiOn(d)) {
          out.add(_netOption(Iconsax.search_normal, TripStringsWizard.findAnotherDriver,
              () => TripNavigation.openTaxi(d, fromStep: id)));
        }
        out.addAll(_taxiOwnOptions(d));
        if (problem != null && !problem.isOpen) {
          out.add(_textAction(TripStringsWizard.dismiss, () => _c.dismissProblem(problem.id), color: AppColors.textLight));
        }
      case TripStepState.done:
        if (rows.isNotEmpty) {
          out.add(_option(Iconsax.receipt_text, TripStringsWizard.seeBooking, () => TripNavigation.openTaxiReplies(d, fromStep: id)));
        }
        if (booked != null && booked.isBooked && _c.canFindTaxiOn(d)) {
          out.add(_netOption(Iconsax.refresh, TripStringsWizard.changeTaxi, () => TripNavigation.openTaxi(d, fromStep: id)));
        }
        final phone = booked == null ? null : _driverPhone(booked);
        if (phone != null) out.add(_option(Iconsax.call, TripStringsWizard.callDriver, () => ContactLauncher.call(phone)));
        if (booked != null && booked.isBooked) {
          out.add(_option(Iconsax.close_circle, TripStringsWizard.cancelBooking,
              () => TripCancelSheet.show(context, enquiry: booked, ownerSide: false), color: AppColors.error));
        }
      case TripStepState.own:
        if (own != null) {
          out.add(_option(Iconsax.edit_2, TripStringsWizard.editDetails,
              () => TripOwnBookingSheet.show(context, day: d, kind: TripOwnKind.taxi, existingTaxi: own)));
        }
        out.add(_option(Iconsax.undo, TripStringsWizard.undo, () => _c.clearOwnTaxi(d)));
      case TripStepState.skipped:
        out.add(_option(Iconsax.undo, TripStringsWizard.undo, () => _c.clearSkippedTaxiDay(d)));
    }
    out.add(_wrongCity(context, d, taxi: true, prefer: _row(cur.enquiryId)));
    return out;
  }

  List<Widget> _taxiFinder(int d, String id) {
    if (_c.supplyCheckFailedFor(d) && !_c.netOff) {
      if (_supplyRetried.add(_c.isMultiCity ? _c.legIndexOf(d) : 1)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _c.retrySupply(d);
        });
      }
      return [
        _infoLine(TripStringsWizard.couldNotCheckDrivers, icon: Iconsax.info_circle, color: AppColors.textMedium),
        _textAction(TripStrings.retry, () => _c.retrySupply(d)),
      ];
    }
    if (_c.supplyPendingFor(d) ||
        (_c.supplyAvailableFor(d) && !_c.taxiTabOff.value && _c.taxiSupplyFor(d) == null)) {
      return [_infoLine(TripStringsWizard.checkingDrivers, icon: Iconsax.clock)];
    }
    if (_c.canFindTaxiOn(d)) return [_netPrimary(TripStringsWizard.findDriver, () => TripNavigation.openTaxi(d, fromStep: id))];
    return [
      _infoLine(_c.taxiTabOff.value ? TripStringsWizard.taxisPaused : TripStringsWizard.noDriversHere(_c.cityNameOf(d)),
          icon: Iconsax.info_circle, color: AppColors.textMedium),
      _textAction(TripStringsWizard.askLater, _w.next),
    ];
  }

  List<Widget> _taxiOwnOptions(int d) => [
        _option(Iconsax.car, TripStringsWizard.haveTaxi,
            () => TripOwnBookingSheet.show(context, day: d, kind: TripOwnKind.taxi), color: TaxiColors.accentDark),
        _option(Iconsax.minus_cirlce, TripStringsWizard.noTaxiThisDay, () => _noTaxi(d), color: AppColors.textMedium),
      ];

  Future<void> _noTaxi(int d) => TripNoTaxiFlow.run(context, d);

  List<Widget> _stay(BuildContext context, TripStepInfo cur) {
    final d = cur.day ?? 1;
    _c.staySupplyByDistrict.length;
    if (!_readOnlyFor(d) && _c.supplyAvailableFor(d) && _c.staySupplyFor(d) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _c.ensureStaySupply(d));
    }
    final id = cur.key.id;
    final readOnly = _readOnlyFor(d);
    final stay = _c.plan.value?.dayAt(d)?.stay;
    final rows = _c.enquiriesForNight(d);
    final linked = _row(cur.enquiryId);
    final booked = linked != null && linked.isBooked ? linked : rows.firstWhereOrNull((e) => e.isBooked);
    final confirmed = booked;
    final out = <Widget>[
      _question(TripStringsWizard.stayQuestion(d), TripStringsWizard.stayCounts),
      _stateBlock(cur),
      if (!_c.hasDates && !readOnly) _addDatesLine(),
      _offlineLine(readOnly),
    ];
    if (readOnly) return out;
    final conflict = cur.state == TripStepState.attention &&
        (stay?.isSkipped == true || stay?.isOwn == true) &&
        booked != null &&
        !_c.wrongOnDay(booked, d);
    if (conflict) {
      out.addAll([
        _primary(TripStringsWizard.keepBooking, () => _c.clearStay(d)),
        _option(Iconsax.close_circle, TripStringsWizard.keepOwn,
            () => TripCancelSheet.show(context, enquiry: booked, ownerSide: false)),
      ]);
      return out;
    }
    final hostUpdates = _c.stayUpdatesFor(d);
    for (final e in rows.where((e) => e.isOpen && hostUpdates.containsKey(e.id))) {
      out.add(_netOption(Iconsax.refresh, TripStringsWizard.sendHostPlaces(e.listingName),
          () => TripEnquiryController.to.refreshContext(e.id)));
    }
    switch (cur.state) {
      case TripStepState.todo:
        out.addAll(_stayFinder(d, id));
        out.addAll(_stayOwnOptions(d));
      case TripStepState.waiting:
        final sameChange = stay?.isSameStay == true ? _c.sameStayNeedsChange(d) : null;
        if (sameChange != null) {
          out.add(_netPrimary(TripStringsWizard.askHost, () => TripNightChooser.askAddNight(context, _c, d, sameChange)));
        } else if (rows.isNotEmpty) {
          out.add(_netPrimary(TripStringsWizard.seeReplies, () => TripNavigation.openReplies(d, fromStep: id)));
        }
        if (booked != null && booked.status == TripEnquiryStatuses.confirmedByTraveller) {
          final phone = _hostPhone(booked);
          if (phone != null) out.add(_option(Iconsax.call, TripStringsWizard.callHost, () => ContactLauncher.call(phone)));
          if (booked.hostConfirm.canResend(DateTime.now())) {
            out.add(_netOption(Iconsax.refresh, TripStrings.resendLink, () => _resendLink(booked)));
          }
          out.add(_option(Iconsax.close_circle, TripStringsWizard.cancelBooking,
              () => TripCancelSheet.show(context, enquiry: booked, ownerSide: false), color: AppColors.error));
        }
        if (_c.canFindStayOn(d)) {
          out.add(rows.isEmpty && sameChange == null
              ? _netPrimary(TripStringsWizard.askHosts, () => TripNavigation.openStay(d, fromStep: id))
              : _netOption(Iconsax.search_normal, TripStringsWizard.findDifferentStay,
                  () => TripNavigation.openStay(d, fromStep: id)));
        }
        out.addAll(_stayOwnOptions(d));
      case TripStepState.attention:
        final problem = linked;
        if (_c.canAskAgain(TripEnquiryKinds.stay, d)) {
          out.add(_netPrimary(TripStringsWizard.askAgain, () => _askAgain(TripEnquiryKinds.stay, d, id)));
        }
        if (rows.isNotEmpty) out.add(_netOption(Iconsax.receipt_text, TripStringsWizard.seeReplies, () => TripNavigation.openReplies(d, fromStep: id)));
        if (_c.canFindStayOn(d)) {
          out.add(_netOption(Iconsax.search_normal, TripStringsWizard.findAnotherStay,
              () => TripNavigation.openStay(d, fromStep: id)));
        }
        out.addAll(_stayOwnOptions(d));
        if (problem != null && !problem.isOpen) {
          out.add(_textAction(TripStringsWizard.dismiss, () => _c.dismissProblem(problem.id), color: AppColors.textLight));
        }
      case TripStepState.done:
        if (confirmed != null) out.addAll(_stayDoneActions(d, id, confirmed, rows));
        if (rows.isNotEmpty) {
          out.add(_option(Iconsax.receipt_text, TripStringsWizard.seeBooking, () => TripNavigation.openReplies(d, fromStep: id)));
        }
        if (confirmed != null && _c.canFindStayOn(d)) {
          out.add(_netOption(Iconsax.refresh, TripStringsWizard.changeStay,
              () => TripNavigation.openStay(d, fromStep: id, replaceEnquiryId: confirmed.id)));
        }
        if (confirmed != null) {
          final phone = _hostPhone(confirmed);
          if (phone != null) out.add(_option(Iconsax.call, TripStringsWizard.callHost, () => ContactLauncher.call(phone)));
          out.add(_option(Iconsax.close_circle, TripStringsWizard.cancelBooking,
              () => TripCancelSheet.show(context, enquiry: confirmed, ownerSide: false), color: AppColors.error));
        }
      case TripStepState.own:
        final own = _c.ownStayOf(d);
        final same = stay?.isSameStay == true;
        if (own != null) {
          out.add(_option(Iconsax.edit_2, TripStringsWizard.editDetails,
              () => TripOwnBookingSheet.show(context, day: same ? stay!.sameAsDay! : d, existingStay: own)));
        }
        out.add(_option(Iconsax.undo, TripStringsWizard.undo, () => same ? _c.clearStay(d) : _c.clearOwnStay(d)));
      case TripStepState.skipped:
        out.add(_option(Iconsax.undo, TripStringsWizard.undo, () => TripNightChooser.undoNoStay(d)));
    }
    out.add(_wrongCity(context, d, taxi: false, prefer: linked));
    return out;
  }

  List<Widget> _stayDoneActions(int d, String id, TripEnquiryModel e, List<TripEnquiryModel> rows) {
    final out = <Widget>[];
    final revised = e.pendingRevised;
    if (e.advance.isPending && e.conversationId != null) {
      out.add(_netPrimary(TripStringsWizard.payAdvance, () => TripNavigation.openChatForEnquiry(e)));
    }
    if (e.advance.isPending) {
      out.add(_netOption(Iconsax.tick_circle, TripStrings.iSentProof, () => TripEnquiryController.to.proofSent(e.id)));
    }
    if (revised != null && !_c.isReadOnly) {
      out.add(_netPrimary(TripStrings.acceptNewPrice, () => TripAcceptSheet.show(context, enquiry: e, offer: revised)));
      final kept = BrowseItem.inr(e.agreedTotalLocked ?? 0);
      out.add(_netOption(Iconsax.close_circle, TripStrings.keepPrice(kept), () => _keepPrice(e, revised, kept)));
    }
    final offer = rows.firstWhereOrNull((x) => x.id != e.id && x.status == TripEnquiryStatuses.offered);
    if (offer != null) {
      out.add(_option(Iconsax.receipt_text, TripStringsWizard.seeOffer, () => TripNavigation.openReplies(d, fromStep: id)));
    }
    return out;
  }

  Future<void> _keepPrice(TripEnquiryModel e, TripOfferModel revised, String money) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(TripStrings.keepPriceQ(money),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
        content: const Text(TripStrings.keepPriceBody,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.4)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(TripStrings.cancelAction, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(TripStrings.keepPrice(money),
                style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textDark, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) await TripEnquiryController.to.keepPrice(e.id, revised.id);
  }

  Future<void> _resendLink(TripEnquiryModel e) async {
    final r = await TripEnquiryController.to.resendLink(e.id);
    if (r == null || !mounted) return;
    _c.rememberLink(r);
    await TripConfirmLinkSheet.show(context, r);
  }

  static String? _driverPhone(TripEnquiryModel e) {
    final p = e.owner.phone;
    return p != null && ContactLauncher.tenDigits(p).isNotEmpty ? p : null;
  }

  static String? _hostPhone(TripEnquiryModel e) {
    for (final p in [e.owner.phone, e.phoneBooking?.hostPhone]) {
      if (p != null && ContactLauncher.tenDigits(p).isNotEmpty) return p;
    }
    return null;
  }

  List<Widget> _stayFinder(int d, String id) {
    if (_c.supplyPendingFor(d)) return [_infoLine(TripStringsWizard.checkingStays, icon: Iconsax.clock)];
    if (_c.canFindStayOn(d)) return [_netPrimary(TripStringsWizard.findStay, () => TripNavigation.openStay(d, fromStep: id))];
    return [
      _infoLine(_c.stayTabOff.value ? TripStringsWizard.staysPaused : TripStringsWizard.noStaysHere(_c.cityNameOf(d)),
          icon: Iconsax.info_circle, color: AppColors.textMedium),
      _textAction(TripStringsWizard.askLater, _w.next),
    ];
  }

  List<Widget> _stayOwnOptions(int d) => [
        if (TripNightChooser.baseOf(_c, d) != null && _c.plan.value?.dayAt(d)?.stay?.isSameStay != true)
          _option(Iconsax.repeat, TripStrings.sameAsLastNight,
              () => TripNightChooser.pick(context, d, TripNightMode.same), color: StayColors.accentDark),
        if (_c.ownStayOf(d) == null)
          _option(Iconsax.building_4, TripStringsWizard.haveStay, () => TripOwnBookingSheet.show(context, day: d),
              color: StayColors.accentDark),
        if (_c.plan.value?.dayAt(d)?.stay?.isSkipped != true)
          _option(Iconsax.moon, TripStrings.noStayTonight, () => TripNightChooser.noStay(context, d),
              color: AppColors.textMedium),
      ];

  Future<void> _askAgain(String kind, int d, String id) async {
    final batch = await _c.askAgain(kind: kind, day: d);
    if (batch == null) return;
    if (kind == TripEnquiryKinds.taxi) {
      TripNavigation.openTaxiReplies(d, fromStep: id);
    } else {
      TripNavigation.openReplies(d, fromStep: id);
    }
  }

  Widget _wrongCity(BuildContext context, int d, {required bool taxi, TripEnquiryModel? prefer}) {
    final e = prefer != null && _c.wrongOnDay(prefer, d) ? prefer : _c.wrongCityForDay(d);
    final info = e == null ? null : _c.wrongCityOf(e);
    if (e == null || info == null || e.isTaxi != taxi) return const SizedBox.shrink();
    VoidCallback? cancel;
    if (e.isWithdrawable) {
      cancel = () => TripWithdrawSheet.show(context, enquiry: e);
    } else if (e.isBooked) {
      cancel = () => TripCancelSheet.show(context, enquiry: e, ownerSide: false);
    }
    final plan = _c.plan.value;
    final changeDays = plan == null
        ? null
        : () => plan.isMultiCity
            ? TripLegMenuSheet.changeDays(context, _c.wrongCityHomeLeg(info) ?? plan.legIndexOf(d))
            : TripDetailsSheet.edit(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TripWrongCityStrip(enquiry: e, info: info, onCancel: cancel, onChangeDays: changeDays),
    );
  }
}

class TripStepFooter extends StatelessWidget {
  final bool showPrev;
  final String? nextTitle;
  final int pulse;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onDone;
  final int openCount;
  final VoidCallback? onSkipRest;

  const TripStepFooter({
    super.key,
    required this.showPrev,
    required this.nextTitle,
    this.pulse = 0,
    required this.onPrev,
    required this.onNext,
    required this.onDone,
    this.openCount = 0,
    this.onSkipRest,
  });

  @override
  Widget build(BuildContext context) {
    final next = nextTitle;
    Widget primary = GradientButton(
      label: next == null ? TripStringsWizard.doneBackToList : TripStringsWizard.nextTo(next),
      height: 50,
      gradient: TripColors.gradient,
      shadowColor: TripColors.accent,
      onPressed: next == null ? onDone : onNext,
    );
    if (pulse > 0) primary = PulseOnce(key: ValueKey('next-pulse-$pulse'), pulseCount: 1, child: primary);
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
            children: [
              if (openCount > 1 && onSkipRest != null)
                TextButton(
                  onPressed: onSkipRest,
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: Text('Skip the rest · $openCount open',
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                ),
              Row(
            children: [
              if (showPrev) ...[
                OutlinedButton(
                  onPressed: onPrev,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 50),
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(TripStringsWizard.prev,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: primary),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }
}
