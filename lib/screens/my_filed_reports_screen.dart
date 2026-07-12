import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/report_controller.dart';
import '../models/listing_report_model.dart';

class MyFiledReportsScreen extends StatefulWidget {
  const MyFiledReportsScreen({super.key});
  @override
  State<MyFiledReportsScreen> createState() => _MyFiledReportsScreenState();
}

class _MyFiledReportsScreenState extends State<MyFiledReportsScreen> {
  final _reportCtrl = Get.find<ReportController>();
  List<ListingReportModel> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reportCtrl.fetchMyFiledReports().then((r) {
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
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('My Reports',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Text('Listings you have reported',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70)),
                ]),
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
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
          child: Text(r.listingType,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
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
        child: Text("You haven't reported any listings", style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
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
