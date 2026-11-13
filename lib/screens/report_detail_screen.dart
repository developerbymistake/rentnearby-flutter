import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_reports.dart';
import '../config/app_insets.dart';
import '../models/listing_report_model.dart';
import '../utils/app_date_format.dart';
import '../utils/listing_kind_visuals.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Get.arguments as ListingReportModel;
    final tone = Report3D.tone(r.listingType);
    final hasDetails = r.details.isNotEmpty;

    return Scaffold(
      backgroundColor: Report3D.page(r.listingType),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          ReportHeader3D(
            tone: tone,
            title: 'Report Details',
            onBack: () => Get.back(),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: KitMetrics.sectionGap + AppInsets.bottomViewPadding(context)),
              child: StaggerColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TagPill3D(label: ListingKindVisuals.labelOf(r.listingType), color: tone.text, art: Report3D.art(r.listingType)),
                    ),
                  ),
                  ReportReasonCard(tone: tone, label: 'Reason', reason: r.reasonName),
                  InfoFieldCard(
                    fields: [
                      InfoField(
                        label: 'Message from reporter',
                        child: Text(
                          hasDetails ? r.details : 'No additional details provided.',
                          style: Ink3D.text(14.5, FontWeight.w400, hasDetails ? Ink3D.sub : Ink3D.hint, letterSpacing: 0, height: 1.5)
                              .copyWith(fontStyle: hasDetails ? FontStyle.normal : FontStyle.italic),
                        ),
                      ),
                      InfoField(label: 'Status', child: ReportStatusPill(status: r.status, plain: true)),
                      InfoField(label: 'Filed on', value: AppDateFormat.date(r.createdAt)),
                      if (r.resolvedAt != null) InfoField(label: 'Resolved on', value: AppDateFormat.date(r.resolvedAt!)),
                    ],
                  ),
                  ReportNote3D.privacy(tone: tone, text: "The reporter's identity is withheld to protect their privacy."),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
