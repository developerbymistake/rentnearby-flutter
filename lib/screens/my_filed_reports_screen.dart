import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import '../config/app_insets.dart';
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
      backgroundColor: DesignColors.scaffold,
      body: Column(children: [
        ModuleHeader(
          title: 'My Reports',
          subtitle: 'Listings you have reported',
          tone: KitTone.stay,
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
                    child: StateCard(asset: TravelIcon.note, title: "You haven't reported any listings"),
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
