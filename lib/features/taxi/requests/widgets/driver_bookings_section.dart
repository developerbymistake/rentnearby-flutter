import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../utils/app_toast.dart';
import '../../../../utils/contact_launcher.dart';
import '../../../owner_core/sheets/owner_confirm.dart';
import '../../../taxi_driver/strings/taxi_work_strings.dart';
import '../../../trip/utils/taxi_result.dart';
import '../controllers/driver_app_bookings_controller.dart';
import '../models/driver_request_models.dart';
import 'driver_withdraw_sheet.dart';

/// Chip, tone and sub line of a booking card (o_tx_39); unknown state = no chip.
class DriverBookingLook {
  const DriverBookingLook({required this.chip, required this.positive, required this.muted, required this.note});

  final String? chip;
  final bool positive;
  final bool muted;
  final String? note;

  static String _first(String name) => name.trim().split(' ').first;

  static DriverBookingLook of(DriverBooking b) {
    final name = _first(b.travellerName);
    switch (b.state) {
      case BookingState.booked:
        return const DriverBookingLook(chip: TaxiWorkStrings.chipOccupied, positive: true, muted: false, note: null);
      case BookingState.inProgress:
        return const DriverBookingLook(chip: TaxiWorkStrings.chipOnTrip, positive: true, muted: false, note: null);
      case BookingState.completed:
        final stars = b.ratingStars;
        return DriverBookingLook(chip: TaxiWorkStrings.chipCompleted, positive: true, muted: false, note: stars == null ? null : TaxiWorkStrings.rated(name, stars));
      case BookingState.cancelled:
        final by = (b.cancelledBy ?? '').toLowerCase();
        final note = switch (by) {
          'traveller' => TaxiWorkStrings.travellerCancelled(name),
          'admin' || 'system' => TaxiWorkStrings.bakhliCancelled,
          'driver' => TaxiWorkStrings.youCancelled,
          _ => null,
        };
        return DriverBookingLook(chip: TaxiWorkStrings.chipCancelled, positive: false, muted: true, note: note);
      case BookingState.unknown:
        return const DriverBookingLook(chip: null, positive: false, muted: true, note: null);
    }
  }
}

class DriverBookingsSection extends StatefulWidget {
  const DriverBookingsSection({super.key, this.controller, this.onCall, this.showHeader = true});

  final DriverAppBookingsController? controller;
  final void Function(String phone)? onCall;
  final bool showHeader;

  @override
  State<DriverBookingsSection> createState() => _DriverBookingsSectionState();
}

class _DriverBookingsSectionState extends State<DriverBookingsSection> {
  late final DriverAppBookingsController _c = widget.controller ?? DriverAppBookingsController.ensure();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.reload();
    });
  }

  void _call(String phone) => (widget.onCall ?? ContactLauncher.call)(phone);

  void _report<T>(TaxiResult<T> r, String ok) {
    switch (r) {
      case TaxiOk<T>():
        AppToast.success(ok);
      case TaxiStateInvalid<T>():
        AppToast.info(TaxiWorkStrings.alreadyChanged);
      case TaxiOffline<T>():
        AppToast.error(TaxiWorkStrings.noConnection);
      case TaxiRefused<T>(:final statusCode) when statusCode == 429:
        AppToast.error(TaxiWorkStrings.tooManyTries);
      default:
        AppToast.error(TaxiWorkStrings.somethingWrong);
    }
  }

  Future<void> _end(DriverBooking b) async {
    final ok = await OwnerConfirm.ask(
      context,
      title: TaxiWorkStrings.endTripTitle,
      body: TaxiWorkStrings.endTripBody(DriverBookingLook._first(b.travellerName)),
      confirm: TaxiWorkStrings.endTrip,
      cancel: TaxiWorkStrings.notYet,
      tone: ListingTone.coral,
      art: ListingArt.flag,
    );
    if (!ok || !mounted) return;
    final r = await _c.end(b);
    if (mounted) _report(r, TaxiWorkStrings.tripEnded);
  }

  Future<void> _withdraw(DriverBooking b) async {
    final chip = await DriverWithdrawSheet.show(
      context,
      kind: DriverWithdrawKind.booking,
      travellerName: DriverBookingLook._first(b.travellerName),
      range: TaxiWorkStrings.shortRange(b.fromDay, b.toDay),
    );
    if (chip == null || !mounted) return;
    final r = await _c.withdraw(b, chip);
    if (mounted) _report(r, TaxiWorkStrings.withdrewBooking);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = _c.items.toList();
      final loading = _c.isBusy(DriverAppBookingAction.load);
      final failed = !loading && _c.hasFailed(DriverAppBookingAction.load);
      final loaded = _c.loaded.value;
      final cells = <Widget>[
        if (widget.showHeader)
          Row(
            key: const ValueKey('app_bookings_header'),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(TaxiWorkStrings.fromTheApp, style: Ink3D.text(17, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
              Gap.h(8),
              Text(TaxiWorkStrings.last90Days, style: Ink3D.text(11, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
            ],
          ),
        if (failed && loaded)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(12)),
            child: Text(TaxiWorkStrings.showingLast, key: const ValueKey('app_bookings_stale'), style: Ink3D.text(12.5, FontWeight.w600, ListingPalette.coral.text)),
          ),
      ];
      final Widget list;
      if (!loaded && failed) {
        list = Padding(
          key: const ValueKey('app_bookings_error'),
          padding: EdgeInsets.only(top: DS.gv(12)),
          child: StateCard.error(
            title: TaxiWorkStrings.couldNotLoadBookings,
            message: TaxiWorkStrings.checkConnection,
            kit: KitTone.taxiDriver,
            actionLabel: TaxiWorkStrings.tryAgain,
            onAction: _c.reload,
          ),
        );
      } else if (!loaded) {
        list = Column(children: [
          for (var i = 0; i < 2; i++)
            Padding(padding: EdgeInsets.only(top: DS.gv(14)), child: SkeletonBox(height: DS.s(86), radius: DS.radius(18))),
        ]);
      } else if (items.isEmpty) {
        list = Padding(
          key: const ValueKey('app_bookings_empty'),
          padding: EdgeInsets.only(top: DS.gv(12)),
          child: const StateCard(title: TaxiWorkStrings.noBookings, message: TaxiWorkStrings.noBookingsLine, kit: KitTone.taxiDriver, asset: ListingArt.taxi),
        );
      } else {
        list = ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (_, i) {
            final b = items[i];
            return Padding(
              padding: EdgeInsets.only(top: DS.gv(14)),
              child: DriverBookingCard(
                booking: b,
                busy: _c.isBusy(DriverAppBookingAction.end, b.bookingId) || _c.isBusy(DriverAppBookingAction.withdraw, b.bookingId),
                onCall: _call,
                onEnd: () => _end(b),
                onWithdraw: () => _withdraw(b),
              ),
            );
          },
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [...cells, list]);
    });
  }
}

class DriverBookingCard extends StatelessWidget {
  static const double _pillFont = 12;

  const DriverBookingCard({super.key, required this.booking, required this.busy, required this.onCall, required this.onEnd, required this.onWithdraw});

  final DriverBooking booking;
  final bool busy;
  final void Function(String phone) onCall;
  final VoidCallback onEnd;
  final VoidCallback onWithdraw;

  static const ColorFilter _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final look = DriverBookingLook.of(b);
    final phone = b.travellerPhone;
    final live = b.state == BookingState.booked || b.state == BookingState.inProgress;
    final canCall = live && phone != null && phone.trim().isNotEmpty;
    final canEnd = b.state == BookingState.inProgress && b.canEnd;
    final canWithdraw = b.state == BookingState.booked && b.canWithdraw;
    const art = Art3D(asset: ListingArt.taxi, size: 36, shadowAlpha: 0);
    final chip = look.chip;
    final note = look.note;
    return Container(
      key: ValueKey('app_booking_${b.bookingId}'),
      padding: DS.insets(l: 14, t: 12, r: 12, b: 12),
      decoration: BoxDecoration(
        color: look.muted ? TaxiStatusLook.dimCard : DesignColors.surface,
        borderRadius: DS.circular(16),
        boxShadow: look.muted ? null : DS.shadows(TripLook.cardShadowSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              look.muted ? const ColorFiltered(colorFilter: _grey, child: art) : art,
              Gap.h(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(TaxiWorkStrings.rangeOf(b.fromDay, b.toDay), style: Ink3D.text(13, FontWeight.w700, look.muted ? TripLook.mutedText : Ink3D.title, letterSpacing: 0)),
                    Text(
                      TaxiWorkStrings.bookingLine(b.pickupName.isEmpty ? '' : TaxiWorkStrings.pickupAt(b.pickupName), b.travellerName),
                      style: Ink3D.text(11, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
                    ),
                  ],
                ),
              ),
              if (chip != null) ...[
                Gap.h(8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: DS.s(112)),
                  child: FittedBox(fit: BoxFit.scaleDown, child: _Chip(key: ValueKey('booking_chip_${b.bookingId}'), label: chip, positive: look.positive)),
                ),
              ],
            ],
          ),
          if (note != null) ...[
            Gap.v(8),
            Text(note, key: ValueKey('booking_note_${b.bookingId}'), style: Ink3D.text(11, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
          ],
          if (canCall || canEnd || canWithdraw) ...[
            Gap.v(12),
            Row(children: [
              if (canCall)
                Expanded(
                  child: WhitePillButton(
                    key: ValueKey('booking_call_${b.bookingId}'),
                    tone: ListingTone.coral,
                    label: TaxiWorkStrings.callTraveller,
                    height: 38,
                    fontSize: _pillFont,
                    onTap: () => onCall(phone),
                  ),
                ),
              if (canCall && (canEnd || canWithdraw)) Gap.h(10),
              if (canEnd)
                Expanded(
                  child: GradientPillButton(
                    key: ValueKey('booking_end_${b.bookingId}'),
                    tone: ListingTone.coral,
                    label: TaxiWorkStrings.endTrip,
                    height: 38,
                    fontSize: _pillFont,
                    enabled: !busy,
                    onTap: onEnd,
                  ),
                )
              else if (canWithdraw)
                Expanded(
                  child: WhitePillButton(
                    key: ValueKey('booking_withdraw_${b.bookingId}'),
                    tone: ListingTone.coral,
                    label: TaxiWorkStrings.withdraw,
                    height: 38,
                    fontSize: _pillFont,
                    enabled: !busy,
                    onTap: onWithdraw,
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 9, v: 3),
        decoration: BoxDecoration(color: positive ? TaxiStatusLook.goodSoft : DesignColors.surfaceMuted, borderRadius: DS.circular(8)),
        child: Text(label, style: Ink3D.text(10.5, FontWeight.w700, positive ? ListingPalette.forest.text : Ink3D.sub, letterSpacing: 0)),
      );
}
