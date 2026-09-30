import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
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
    return Scaffold(
      body: Column(children: [
        Container(
          decoration: BoxDecoration(gradient: AppColors.gradientFor(_listingType == 'Plot')),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 24),
              child: Row(children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Reports on $_title',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    const Text('Reason, status and filed date only',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? _buildShimmer()
              : _reports.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (_, i) => ReportRow(
                        report: _reports[i],
                        showKind: false,
                        onTap: () => Get.toNamed(AppRoutes.reportDetail, arguments: _reports[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildEmpty() => const Center(
        child: Text('No reports found', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
      );

  Widget _buildShimmer() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, idx) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 70,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}
