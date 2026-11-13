import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings_mcc_a2.dart';
import 'trip_status.dart';

enum TripLegImpactChoice { cancelAndApply, keepBookings, back }

class TripLegImpactDialog {
  static const int _maxRows = 4;

  static Future<TripLegImpactChoice?> show(
    BuildContext context, {
    required String title,
    required String body,
    required LegImpact impact,
    required String applyLabel,
    String? keepLabel,
    required String backLabel,
    required bool offline,
  }) {
    return Dialog3D.show<TripLegImpactChoice>(
      context,
      builder: (ctx) => _ImpactDialog(
        title: title,
        body: body,
        impact: impact,
        applyLabel: applyLabel,
        keepLabel: keepLabel,
        backLabel: backLabel,
        offline: offline,
      ),
    );
  }

  static List<TripEnquiryModel> rowsOf(LegImpact impact) {
    final seen = <String>{};
    return [
      for (final e in [...impact.booked, ...impact.open, ...impact.cars])
        if (seen.add(e.id)) e,
    ];
  }
}

class _ImpactDialog extends StatelessWidget {
  const _ImpactDialog({
    required this.title,
    required this.body,
    required this.impact,
    required this.applyLabel,
    required this.keepLabel,
    required this.backLabel,
    required this.offline,
  });

  final String title;
  final String body;
  final LegImpact impact;
  final String applyLabel;
  final String? keepLabel;
  final String backLabel;
  final bool offline;

  DialogLine _row(TripEnquiryModel e) {
    final taxi = e.isTaxi;
    final name = e.listingName;
    final status = TripStatusVisuals.label(e.display, taxi: taxi);
    return DialogLine(name.isEmpty ? status : '$name · $status', art: taxi ? ListingArt.taxi : ListingArt.hotel);
  }

  @override
  Widget build(BuildContext context) {
    final rows = TripLegImpactDialog.rowsOf(impact);
    final shown = rows.take(TripLegImpactDialog._maxRows).toList();
    final more = rows.length - shown.length;
    final told = TripStringsMccA2.ownersTold(impact.hosts, impact.drivers);
    return Dialog3D(
      tone: ListingTone.indigo,
      art: ListingArt.calendar,
      title: title,
      body: told.isEmpty ? body : '$body\n$told',
      lines: [for (final e in shown) _row(e), if (more > 0) DialogLine(TripStringsMccA2.moreRows(more))],
      note: offline ? TripStringsMccA2.connectToCancel : null,
      stacked: true,
      primaryLabel: applyLabel,
      primaryDanger: true,
      primaryEnabled: !offline,
      onPrimary: offline ? null : () => Navigator.pop(context, TripLegImpactChoice.cancelAndApply),
      secondaryLabel: keepLabel,
      onSecondary: keepLabel == null ? null : () => Navigator.pop(context, TripLegImpactChoice.keepBookings),
      tertiaryLabel: backLabel,
      onTertiary: () => Navigator.pop(context, TripLegImpactChoice.back),
    );
  }
}
