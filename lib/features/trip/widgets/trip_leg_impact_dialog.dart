import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../taxi/taxi_option_sets.dart';
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
    return showDialog<TripLegImpactChoice>(
      context: context,
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

  Widget _row(TripEnquiryModel e) {
    final taxi = e.isTaxi;
    final name = e.listingName;
    final status = TripStatusVisuals.label(e.display, taxi: taxi);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(taxi ? Iconsax.car : Iconsax.building_4, size: 15, color: taxi ? TaxiColors.accent : StayColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name.isEmpty ? status : '$name · $status',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(BuildContext context, String label, Color color, TripLegImpactChoice? choice, {bool strong = false}) {
    return TextButton(
      onPressed: choice == null ? null : () => Navigator.pop(context, choice),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
          color: choice == null ? AppColors.textHint : color,
        ),
      ),
    );
  }

  Widget _details(List<TripEnquiryModel> shown, int more, String told) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(body, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
        if (told.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(told, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight)),
        ],
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final e in shown) _row(e),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(TripStringsMccA2.moreRows(more),
                  maxLines: 1,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ),
        ],
        if (offline) ...[
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Iconsax.wifi_square, size: 14, color: AppColors.warningText),
              SizedBox(width: 6),
              Expanded(
                child: Text(TripStringsMccA2.connectToCancel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warningText)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = TripLegImpactDialog.rowsOf(impact);
    final shown = rows.take(TripLegImpactDialog._maxRows).toList();
    final more = rows.length - shown.length;
    final told = TripStringsMccA2.ownersTold(impact.hosts, impact.drivers);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.45;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17)),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 12),
                  child: _details(shown, more, told),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _button(context, applyLabel, AppColors.error, offline ? null : TripLegImpactChoice.cancelAndApply,
                strong: true),
            if (keepLabel != null) _button(context, keepLabel!, AppColors.textDark, TripLegImpactChoice.keepBookings),
            _button(context, backLabel, AppColors.textLight, TripLegImpactChoice.back),
          ],
        ),
      ),
    );
  }
}
