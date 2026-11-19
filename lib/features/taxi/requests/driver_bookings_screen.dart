import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_insets.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../trip/utils/taxi_result.dart';
import '../../trip/widgets/taxi_status/taxi_driver_card.dart' show TaxiStateChip;
import 'controllers/driver_bookings_controller.dart';
import 'models/driver_request_models.dart';
import 'strings/driver_bookings_strings.dart';
import 'widgets/driver_withdraw_sheet.dart';

class DriverBookingsScreen extends StatefulWidget {
  const DriverBookingsScreen({super.key, this.controller, this.onCall});

  final DriverBookingsController? controller;
  final void Function(String phone)? onCall;

  @override
  State<DriverBookingsScreen> createState() => _DriverBookingsScreenState();
}

class _DriverBookingsScreenState extends State<DriverBookingsScreen> {
  late final DriverBookingsController _c = widget.controller ?? DriverBookingsController.to;

  @override
  void initState() {
    super.initState();
    _c.reload();
  }

  void _call(String phone) => (widget.onCall ?? ContactLauncher.call)(phone);

  void _report<T>(TaxiResult<T> r, String okMessage) {
    switch (r) {
      case TaxiOk<T>():
        AppToast.success(okMessage);
      case TaxiStateInvalid<T>():
        AppToast.info(DriverBookingsStrings.alreadyChanged);
      case TaxiOffline<T>():
        AppToast.error(DriverBookingsStrings.offline);
      default:
        AppToast.error(DriverBookingsStrings.failed);
    }
  }

  Future<void> _withdraw(DriverBooking b) async {
    final chip = await DriverWithdrawSheet.show(context);
    if (chip == null) return;
    final r = await _c.withdraw(b, chip);
    if (mounted) _report(r, DriverBookingsStrings.withdrawn);
  }

  void _changeMonth(DateTime m) {
    _c.bookings.value = null;
    _c.loadMonth(m);
  }

  Future<void> _end(DriverBooking b) async {
    final r = await _c.endBooking(b);
    if (mounted) _report(r, DriverBookingsStrings.ended);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          Obx(() {
            final sub = DriverBookingsStrings.monthName(_c.month.value);
            return MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: ModuleHeader(
                title: DriverBookingsStrings.title,
                subtitle: sub,
                titleStyle: TripCustomizeLook.headerTitle,
                subtitleWidget: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TripCustomizeLook.headerSubtitle),
                autoHeight: true,
                compact: true,
                tone: KitTone.brand,
                gradient: ListingTone.indigo.gradient,
                onBack: () => Get.back(),
              ),
            );
          }),
          Expanded(child: Obx(_body)),
        ],
      ),
    );
  }

  Widget _body() {
    final data = _c.bookings.value;
    final month = _c.month.value;
    final loading = _c.isBusy(DriverBookingAction.load);
    final failed = !loading && _c.hasFailed(DriverBookingAction.load);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(22), DS.s(18), AppInsets.bottomViewPadding(context) + DS.s(24)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle(DriverBookingsStrings.calendar),
              _MonthCalendar(
                month: month,
                occupied: failed ? const [] : data?.occupied ?? const [],
                busy: loading,
                onMonth: _changeMonth,
              ),
              Gap.v(22),
              const _SectionTitle(DriverBookingsStrings.bookings),
              if (failed)
                Padding(
                  key: const ValueKey('driver_bookings_error'),
                  padding: EdgeInsets.symmetric(vertical: DS.gv(12)),
                  child: StateCard.error(
                    title: DriverBookingsStrings.loadFailedTitle,
                    message: DriverBookingsStrings.loadFailedMessage,
                    kit: KitTone.trip,
                    actionLabel: DriverBookingsStrings.retry,
                    onAction: _c.reload,
                  ),
                )
              else if (data == null)
                for (var i = 0; i < 2; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: DS.gv(14)),
                    child: SkeletonBox(height: DS.s(96), radius: DS.radius(20)),
                  )
              else if (data.items.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: DS.gv(12)),
                  child: const StateCard(
                    title: DriverBookingsStrings.emptyTitle,
                    message: DriverBookingsStrings.emptyMessage,
                    kit: KitTone.trip,
                    asset: ListingArt.taxi,
                  ),
                )
              else
                for (final b in data.items)
                  Padding(
                    padding: EdgeInsets.only(top: DS.gv(16)),
                    child: _BookingCard(
                      booking: b,
                      withdrawBusy: _c.isBusy(DriverBookingAction.withdraw, b.bookingId),
                      endBusy: _c.isBusy(DriverBookingAction.end, b.bookingId),
                      onWithdraw: () => _withdraw(b),
                      onEnd: () => _end(b),
                      onCall: _call,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: Ink3D.text(19, FontWeight.w600, Ink3D.body, letterSpacing: 0));
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.month, required this.occupied, required this.busy, required this.onMonth});

  final DateTime month;
  final List<DriverOccupiedRange> occupied;
  final bool busy;
  final void Function(DateTime month) onMonth;

  bool _taken(DateTime d) {
    for (final r in occupied) {
      final from = r.fromDay;
      final to = r.toDay;
      if (from == null || to == null) continue;
      final f = DateTime(from.year, from.month, from.day);
      final t = DateTime(to.year, to.month, to.day);
      if (!d.isBefore(f) && !d.isAfter(t)) return true;
    }
    return false;
  }

  Widget _nav(IconData icon, String tip, VoidCallback onTap) => Tap3D(
        onTap: busy ? null : onTap,
        label: tip,
        child: SizedBox(
          width: DS.s(44),
          height: DS.s(44),
          child: Center(child: Icon(icon, size: DS.s(26), color: ListingTone.indigo.text)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final lead = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    return Column(
      children: [
        Gap.v(12),
        Row(
          children: [
            _nav(Icons.chevron_left_rounded, DriverBookingsStrings.previousMonth, () => onMonth(DateTime(month.year, month.month - 1))),
            Expanded(
              child: Text(
                DriverBookingsStrings.monthYear(month),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(16, FontWeight.w700, Ink3D.title),
              ),
            ),
            _nav(Icons.chevron_right_rounded, DriverBookingsStrings.nextMonth, () => onMonth(DateTime(month.year, month.month + 1))),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: DS.s(6)),
          child: Row(
            children: [
              for (final d in DriverBookingsStrings.weekdays)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(d, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, Ink3D.hint, letterSpacing: 0)),
                  ),
                ),
            ],
          ),
        ),
        for (var r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(bottom: DS.s(6)),
            child: Row(
              children: [
                for (var k = 0; k < 7; k++)
                  Expanded(
                    child: () {
                      final n = r * 7 + k - lead + 1;
                      if (n < 1 || n > days) return SizedBox(height: DS.s(44));
                      return _DayCell(day: n, taken: _taken(DateTime(month.year, month.month, n)), tone: tone);
                    }(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.taken, required this.tone});

  final int day;
  final bool taken;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
        label: taken ? '$day, ${DriverBookingsStrings.occupiedDay}' : '$day',
        excludeSemantics: true,
        child: Container(
          key: ValueKey(taken ? 'cal_taken_$day' : 'cal_free_$day'),
          height: DS.s(44),
          margin: EdgeInsets.symmetric(horizontal: DS.gh(3)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: taken ? tone.gradient : null,
            color: taken ? null : Colors.white,
            borderRadius: DS.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$day',
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: Ink3D.text(13, FontWeight.w600, taken ? Colors.white : Ink3D.title, letterSpacing: 0),
            ),
          ),
        ),
      );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.withdrawBusy,
    required this.endBusy,
    required this.onWithdraw,
    required this.onEnd,
    required this.onCall,
  });

  final DriverBooking booking;
  final bool withdrawBusy;
  final bool endBusy;
  final VoidCallback onWithdraw;
  final VoidCallback onEnd;
  final void Function(String phone) onCall;

  String get _chip => switch (booking.state) {
        BookingState.completed => DriverBookingsStrings.stateCompleted,
        BookingState.cancelled => DriverBookingsStrings.stateCancelled,
        _ => DriverBookingsStrings.stateOccupied,
      };

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final live = b.state == BookingState.booked || b.state == BookingState.inProgress;
    final phone = b.travellerPhone;
    final canWithdraw = b.state == BookingState.booked && b.canWithdraw;
    final canEnd = b.state == BookingState.inProgress && b.canEnd;
    final canCall = live && phone != null && phone.isNotEmpty;
    final busy = withdrawBusy || endBusy;
    return Container(
      padding: DS.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DS.br(TripCustomizeLook.addDayRadius),
        border: live ? Border.all(color: TaxiStatusLook.goodLine, width: DS.s(2)) : null,
        boxShadow: DS.shadows(TripLook.cardShadowSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Art3D(asset: ListingArt.taxi, size: 44, shadowAlpha: 0),
              Gap.h(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverBookingsStrings.range(b.fromDay, b.toDay),
                      style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0),
                    ),
                    Text(
                      DriverBookingsStrings.detail(
                        b.pickupName,
                        b.state == BookingState.completed ? DriverBookingsStrings.stateCompleted : b.travellerName,
                      ),
                      style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
                    ),
                  ],
                ),
              ),
              Gap.h(8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: DS.s(112)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TaxiStateChip(key: ValueKey('booking_chip_${b.bookingId}'), label: _chip),
                ),
              ),
            ],
          ),
          if (canWithdraw || canEnd || canCall)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(12)),
              child: Wrap(
                spacing: DS.gh(10),
                runSpacing: DS.gv(8),
                children: [
                  if (canWithdraw)
                    PillAction(
                      key: ValueKey('booking_withdraw_${b.bookingId}'),
                      label: DriverBookingsStrings.withdraw,
                      tone: KitTone.taxi,
                      onTap: busy ? null : onWithdraw,
                    ),
                  if (canEnd)
                    PillAction(
                      key: ValueKey('booking_end_${b.bookingId}'),
                      label: DriverBookingsStrings.endTrip,
                      tone: KitTone.trip,
                      filled: true,
                      onTap: busy ? null : onEnd,
                    ),
                  if (canCall)
                    PillAction(
                      key: ValueKey('booking_call_${b.bookingId}'),
                      label: DriverBookingsStrings.call,
                      tone: KitTone.trip,
                      icon: Icon(Icons.call_rounded, size: DS.s(16), color: KitTone.trip.accentDark),
                      onTap: () => onCall(phone),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
