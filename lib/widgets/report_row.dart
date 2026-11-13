import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/ext_reports.dart';
import '../models/listing_report_model.dart';
import '../utils/app_date_format.dart';
import '../utils/listing_kind_visuals.dart';

class ReportRow extends StatelessWidget {
  final ListingReportModel report;
  final bool showKind;
  final VoidCallback onTap;

  const ReportRow({super.key, required this.report, required this.onTap, this.showKind = true});

  static KitTone toneOf(String listingType) {
    final kind = ChatKindStyle.of(listingType);
    return KitTone(
      accent: kind.accent,
      accentDark: kind.dark,
      tint: kind.tint,
      gradient: kind.gradient,
      glow: kind.dark,
    );
  }

  static String iconOf(String listingType) => Report3D.art(listingType);

  @override
  Widget build(BuildContext context) {
    final r = report;
    return ReportCard3D(
      tone: Report3D.tone(r.listingType),
      art: iconOf(r.listingType),
      eyebrow: showKind ? '${ListingKindVisuals.labelOf(r.listingType)} REPORT' : null,
      title: r.reasonName,
      subtitle: 'Filed ${AppDateFormat.date(r.createdAt)}',
      status: r.status,
      onTap: onTap,
    );
  }
}
