import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/report_controller.dart';
import '../models/listing_report_model.dart';
import '../widgets/report_row.dart';

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
                      itemBuilder: (_, i) => ReportRow(
                        report: _reports[i],
                        onTap: () => Get.toNamed(AppRoutes.reportDetail, arguments: _reports[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("You haven't reported any listings",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ]),
        ),
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
