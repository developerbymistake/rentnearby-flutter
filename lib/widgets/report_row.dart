import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
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

  static String iconOf(String listingType) => switch (listingType) {
        'Stay' => TravelIcon.stay,
        'Taxi' => TravelIcon.taxi,
        'Job' => TravelIcon.luggage,
        _ => TravelIcon.note,
      };

  @override
  Widget build(BuildContext context) {
    final r = report;
    final isPending = r.status == 'Pending';
    return ListRow(
      title: r.reasonName,
      subtitle: 'Filed ${AppDateFormat.date(r.createdAt)}',
      tag: showKind ? ListingKindVisuals.labelOf(r.listingType) : null,
      tone: toneOf(r.listingType),
      iconAsset: iconOf(r.listingType),
      showChevron: false,
      onTap: onTap,
      trailing: ChatPill(
        label: r.status,
        fill: isPending ? RepliesTone.warnSurface : RepliesTone.goodSurface,
        color: isPending ? DesignColors.warnDeep : DesignColors.goodDeep,
        size: 11,
      ),
    );
  }
}
