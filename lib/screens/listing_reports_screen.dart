import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/report_controller.dart';
import '../models/listing_report_model.dart';

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
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
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
                      itemBuilder: (_, i) => _reportRow(_reports[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _reportRow(ListingReportModel r) {
    final isPending = r.status == 'Pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(r.reasonName,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        subtitle: Text(_formatDate(r.createdAt),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isPending ? AppColors.reportAlert.withValues(alpha: 0.12) : AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(r.status,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isPending ? AppColors.reportAlert : AppColors.success)),
        ),
        onTap: () => Get.toNamed(AppRoutes.reportDetail, arguments: r),
      ),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Filed ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
