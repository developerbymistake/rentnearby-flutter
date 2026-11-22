import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../../taxi_driver/strings/taxi_work_strings.dart';
import '../../../trip/widgets/taxi_status/taxi_reason_sheet.dart';
import '../models/driver_request_models.dart';

enum DriverWithdrawKind { request, booking }

class DriverWithdrawSheet extends StatefulWidget {
  const DriverWithdrawSheet({super.key, this.kind = DriverWithdrawKind.booking, this.travellerName = '', this.range = ''});

  final DriverWithdrawKind kind;
  final String travellerName;
  final String range;

  // o_tx_37 B: before selection.
  static const List<ReasonChip> requestReasons = [ReasonChip.changedPlan, ReasonChip.vehicleIssue, ReasonChip.priceNotAgreed, ReasonChip.other];

  // o_tx_38 B: a booking.
  static const List<ReasonChip> bookingReasons = [
    ReasonChip.changedPlan,
    ReasonChip.notReachable,
    ReasonChip.priceNotAgreed,
    ReasonChip.vehicleIssue,
    ReasonChip.other,
  ];

  static String labelOf(ReasonChip c) => switch (c) {
        ReasonChip.changedPlan => TaxiWorkStrings.changedPlan,
        ReasonChip.notReachable => TaxiWorkStrings.notReachable,
        ReasonChip.priceNotAgreed => TaxiWorkStrings.priceNotAgreed,
        ReasonChip.vehicleIssue => TaxiWorkStrings.vehicleIssue,
        _ => TaxiWorkStrings.other,
      };

  static Future<ReasonChip?> show(
    BuildContext context, {
    DriverWithdrawKind kind = DriverWithdrawKind.booking,
    String travellerName = '',
    String range = '',
  }) =>
      TaxiReasonSheet.show<ReasonChip>(context, DriverWithdrawSheet(kind: kind, travellerName: travellerName, range: range));

  static const double maxWidth = 560;

  @override
  State<DriverWithdrawSheet> createState() => _DriverWithdrawSheetState();
}

class _DriverWithdrawSheetState extends State<DriverWithdrawSheet> {
  static const double _pillFont = 14;

  ReasonChip? _picked;

  bool get _booking => widget.kind == DriverWithdrawKind.booking;

  @override
  Widget build(BuildContext context) {
    final reasons = _booking ? DriverWithdrawSheet.bookingReasons : DriverWithdrawSheet.requestReasons;
    final picked = _picked;
    final small = Ink3D.text(12, FontWeight.w400, TripLook.mutedText, height: 1.5, letterSpacing: 0);
    final mq = MediaQuery.of(context);
    final maxHeight = (mq.size.height - mq.padding.top - mq.viewInsets.bottom - DS.s(60)).clamp(DS.s(200), double.infinity);
    final panel = Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(TaxiStatusLook.sheetRadius),
        boxShadow: DS.shadows(TaxiStatusLook.sheetShadow),
      ),
      child: SingleChildScrollView(
        key: const ValueKey('driver_withdraw_scroll'),
        padding: DS.insets(l: 16, t: 58, r: 16).copyWith(bottom: DS.s(18) + mq.padding.bottom),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _booking ? TaxiWorkStrings.withdrawBookingTitle : TaxiWorkStrings.withdrawRequestTitle,
            style: Ink3D.text(18, FontWeight.w700, Ink3D.title, height: 1.3, letterSpacing: 0),
          ),
          Gap.v(2),
          Text(
            _booking ? TaxiWorkStrings.withdrawBookingSub(widget.travellerName, widget.range) : TaxiWorkStrings.withdrawRequestSub,
            style: small,
          ),
          Gap.v(16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _booking ? TaxiWorkStrings.whyWithdrawing : TaxiWorkStrings.reason,
                  style: Ink3D.text(11.5, FontWeight.w700, Ink3D.title, letterSpacing: 0),
                ),
              ),
              Text(_booking ? TaxiWorkStrings.required : TaxiWorkStrings.askedByTraveller, style: Ink3D.text(11, FontWeight.w400, TripLook.mutedText, letterSpacing: 0)),
            ],
          ),
          Gap.v(8),
          Wrap(
            spacing: DS.gh(8),
            runSpacing: DS.gv(8),
            children: [
              for (final r in reasons)
                _ReasonChip(
                  key: ValueKey('driver_reason_${r.wire}'),
                  label: DriverWithdrawSheet.labelOf(r),
                  selected: r == picked,
                  onTap: () => setState(() => _picked = r),
                ),
            ],
          ),
          if (_booking) ...[
            Gap.v(12),
            Container(
              key: const ValueKey('driver_withdraw_note'),
              padding: DS.sym(h: 12, v: 10),
              decoration: BoxDecoration(color: TaxiStatusLook.warnFill, borderRadius: DS.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Art3D(asset: ListingArt.calendar, size: 24, shadowAlpha: 0),
                  Gap.h(10),
                  Expanded(
                    child: Text(TaxiWorkStrings.reopensNote(widget.travellerName),
                        style: Ink3D.text(11.5, FontWeight.w600, TaxiStatusLook.warnText, height: 1.45, letterSpacing: 0)),
                  ),
                ],
              ),
            ),
          ],
          Gap.v(14),
          GradientPillButton(
            key: const ValueKey('driver_withdraw_confirm'),
            tone: ListingTone.coral,
            label: TaxiWorkStrings.confirmWithdraw,
            shadows: TaxiStatusLook.redPill,
            height: 46,
            fontSize: _pillFont,
            enabled: picked != null,
            onTap: picked == null ? null : () => Navigator.pop(context, picked),
          ),
          Gap.v(10),
          WhitePillButton(
            key: const ValueKey('driver_withdraw_keep'),
            tone: ListingTone.coral,
            label: _booking ? TaxiWorkStrings.keepBooking : TaxiWorkStrings.keep,
            height: 46,
            fontSize: _pillFont,
            onTap: () => Navigator.pop(context),
          ),
        ],
      )),
    );
    final sheet = Stack(
      clipBehavior: Clip.none,
      children: [
        panel,
        Positioned(
          top: DS.s(-44),
          left: 0,
          right: 0,
          child: const Center(child: Art3D(asset: ListingArt.warning, size: 88, shadowBlur: 8, shadowOffset: Offset(6, 10), shadowAlpha: 0.22)),
        ),
        Positioned(right: DS.s(12), top: DS.s(12), child: const SheetCloseButton()),
      ],
    );
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: DriverWithdrawSheet.maxWidth), child: sheet),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: selected,
      child: Container(
        height: DS.s(32),
        padding: DS.sym(h: 12),
        decoration: BoxDecoration(
          color: selected ? null : DesignColors.surface,
          gradient: selected ? ListingTone.forest.gradient : null,
          borderRadius: DS.circular(16),
          border: selected ? null : Border.all(color: DesignColors.divider, width: DS.s(1)),
          boxShadow: selected ? DS.shadows(TaxiStatusLook.chipShadow) : null,
        ),
        child: Center(
          widthFactor: 1,
          child: Text(label, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, selected ? DesignColors.textInverse : Ink3D.sub, letterSpacing: 0)),
        ),
      ),
    );
  }
}
