import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_shadows.dart';
import '../models/listing_report_model.dart';
import '../utils/app_date_format.dart';

class ReportRow extends StatelessWidget {
  final ListingReportModel report;
  final bool showKind;
  final VoidCallback onTap;

  const ReportRow({super.key, required this.report, required this.onTap, this.showKind = true});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final isPlot = r.listingType == 'Plot';
    final accent = AppColors.accentFor(isPlot);
    final isPending = r.status == 'Pending';
    final statusColor = isPending ? AppColors.reportAlert : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
        boxShadow: AppShadows.premium(accent, alpha: 0.06, blur: 8, offset: const Offset(0, 2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: showKind
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(isPlot ? 'PLOT' : 'ROOM',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: accent)),
              )
            : null,
        title: Text(r.reasonName,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        subtitle: Text('Filed ${AppDateFormat.date(r.createdAt)}',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(r.status,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
        ),
        onTap: onTap,
      ),
    );
  }
}
