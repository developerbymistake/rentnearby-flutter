import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_reports.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/report_controller.dart';
import '../models/listing_report_model.dart';
import '../widgets/report_row.dart';

class ListingReportsScreen extends StatefulWidget {
  const ListingReportsScreen({super.key});
  @override
  State<ListingReportsScreen> createState() => _ListingReportsScreenState();
}

class _ListingReportsScreenState extends State<ListingReportsScreen> {
  final _reportCtrl = Get.find<ReportController>();
  late final String _listingId;
  late final String _listingType;
  late final String _title;
  List<ListingReportModel> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map;
    _listingId = args['listingId'] as String;
    _listingType = args['listingType'] as String;
    _title = args['title'] as String;
    _reportCtrl.fetchListingReports(_listingId, _listingType).then((r) {
      if (mounted) setState(() { _reports = r; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tone = Report3D.tone(_listingType);
    return Scaffold(
      backgroundColor: Report3D.page(_listingType),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ReportHeader3D(tone: tone, title: 'Reports on $_title', subtitle: 'Reason, status and filed date only', onBack: () => Get.back()),
            const ToastSlot(margin: EdgeInsets.fromLTRB(16, 10, 16, 0)),
            Expanded(
              child: KitSwitcher(
                child: _loading
                    ? KeyedSubtree(key: const ValueKey('kit_skeleton'), child: _buildShimmer())
                    : KeyedSubtree(key: const ValueKey('kit_content'), child: _content(context, tone)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ListingTone tone) {
    return _reports.isEmpty
        ? LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: KitMetrics.gutter + AppInsets.bottomViewPadding(context)),
              child: StateCard3D(
                tone: tone,
                art: ListingArt.clipboard,
                title: 'No reports found',
                layout: StateLayout.tall,
                artInside: true,
                minHeight: (box.maxHeight - 200).clamp(300.0, 540.0),
              ),
            ),
          )
        : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: KitMetrics.gutter + AppInsets.bottomViewPadding(context)),
            itemCount: _reports.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return ReportCountLabel(_reports.length == 1 ? '1 REPORT' : '${_reports.length} REPORTS');
              final r = _reports[i - 1];
              return EntranceOnce(
                key: ValueKey(r.id),
                index: i - 1,
                child: ReportRow(
                  report: r,
                  showKind: false,
                  onTap: () => Get.toNamed(AppRoutes.reportDetail, arguments: r),
                ),
              );
            },
          );
  }

  Widget _buildShimmer() =>
      ListView(physics: const NeverScrollableScrollPhysics(), children: [const ReportCountLabel(' '), for (var i = 0; i < 4; i++) const ReportCardSkeleton()]);
}
