import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
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
    final tone = ReportRow.toneOf(_listingType);
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(children: [
        ModuleHeader(
          title: 'Reports on $_title',
          subtitle: 'Reason, status and filed date only',
          tone: tone,
          leadingAsset: TravelIcon.note,
          onBack: () => Get.back(),
        ),
        Expanded(
          child: SkeletonSwitcher(
            loading: _loading,
            skeleton: _buildShimmer(),
            child: _reports.isEmpty
                ? const Align(
                    alignment: Alignment.topCenter,
                    child: StateCard(asset: TravelIcon.note, title: 'No reports found'),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                        top: KitMetrics.cardGap, bottom: KitMetrics.gutter + AppInsets.bottomViewPadding(context)),
                    itemCount: _reports.length,
                    itemBuilder: (_, i) => EntranceOnce(
                      key: ValueKey(_reports[i].id),
                      index: i,
                      child: ReportRow(
                        report: _reports[i],
                        showKind: false,
                        onTap: () => Get.toNamed(AppRoutes.reportDetail, arguments: _reports[i]),
                      ),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _buildShimmer() => Column(
        children: [
          const SizedBox(height: KitMetrics.cardGap),
          for (var i = 0; i < 4; i++) ListRow.skeleton(compact: true),
        ],
      );
}
