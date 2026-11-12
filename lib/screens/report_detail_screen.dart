import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../config/app_insets.dart';
import '../models/listing_report_model.dart';
import '../utils/app_date_format.dart';
import '../utils/listing_kind_visuals.dart';
import '../widgets/report_row.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Get.arguments as ListingReportModel;
    final isPending = r.status == 'Pending';
    final kind = ChatKindStyle.of(r.listingType);
    final tone = isPending ? DesignColors.warnDeep : DesignColors.goodDeep;

    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(children: [
        ModuleHeader(
          title: 'Report Details',
          tone: ReportRow.toneOf(r.listingType),
          leadingAsset: TravelIcon.note,
          onBack: () => Get.back(),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(KitMetrics.gutter, KitMetrics.sectionGap, KitMetrics.gutter,
                KitMetrics.sectionGap + AppInsets.bottomViewPadding(context)),
            child: StaggerColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: KitMetrics.cardGap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ChatPill(label: ListingKindVisuals.labelOf(r.listingType), fill: kind.tint, color: kind.dark),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: KitMetrics.cardGap),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isPending ? RepliesTone.warnSurface : RepliesTone.goodSurface,
                      borderRadius: CardRadius.tile,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('REASON',
                            style: TypeTokens.style(11, FontWeight.w700, color: tone, letterSpacing: 0.4)),
                        const SizedBox(height: 4),
                        Text(r.reasonName, style: TypeTokens.title),
                      ]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: KitMetrics.cardGap),
                  child: SectionTile(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _field('Message from reporter', r.details.isNotEmpty ? r.details : 'No additional details provided.'),
                      _divider(),
                      _field('Status', r.status),
                      _divider(),
                      _field('Filed on', AppDateFormat.date(r.createdAt)),
                      if (r.resolvedAt != null) ...[
                        _divider(),
                        _field('Resolved on', AppDateFormat.date(r.resolvedAt!)),
                      ],
                    ]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kind.tint, borderRadius: CardRadius.tile),
                  child: Row(children: [
                    const TravelIcon(TravelIcon.checkout, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text("The reporter's identity is withheld to protect their privacy.",
                          style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(color: DesignColors.dividerSoft, height: 1),
      );

  Widget _field(String label, String value) {
    return SizedBox(
      width: double.infinity,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TypeTokens.style(11, FontWeight.w700, color: DesignColors.textMuted, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Text(value, style: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary, height: 1.5)),
      ]),
    );
  }
}
