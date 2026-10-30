import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/plan_controller.dart';
import '../models/plan_purchase_result.dart';
import '../widgets/plan_compare_table.dart';
import '../widgets/plan_subscription_card.dart';

class PlanHistoryScreen extends StatefulWidget {
  const PlanHistoryScreen({super.key});
  @override
  State<PlanHistoryScreen> createState() => _PlanHistoryScreenState();
}

class _PlanHistoryScreenState extends State<PlanHistoryScreen> {
  final _plans = Get.find<PlanController>();

  @override
  void initState() {
    super.initState();
    _plans.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        Obx(() => _header(_plans.myPlan.value.featureKey)),
        Expanded(
          child: Obx(() {
            final items = _plans.history.toList();
            final loading = _plans.isLoadingHistory.value;
            final failed = _plans.historyLoadFailed.value;
            final accent = PlanAccent.of(_plans.myPlan.value.featureKey);
            return RefreshIndicator(
              color: accent,
              onRefresh: _plans.loadHistory,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + AppInsets.bottomViewPadding(context)),
                children: [
                  if (items.isEmpty && loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
                    )
                  else if (items.isEmpty && failed)
                    _failedState(accent)
                  else if (items.isEmpty)
                    _emptyState()
                  else
                    _historyList(items),
                ],
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _header(String? featureKey) {
    return Container(
      decoration: BoxDecoration(gradient: PlanAccent.gradientOf(featureKey)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
          child: Row(children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            ),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('History',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Your plan payments',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _failedState(Color accent) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(children: [
            const Text('Could not load',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text('Check your connection.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _plans.loadHistory,
              child: Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: accent)),
            ),
          ]),
        ),
      );

  Widget _emptyState() => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: Column(children: [
            Icon(Icons.receipt_long_rounded, size: 40, color: AppColors.textHint),
            SizedBox(height: 10),
            Text('No payments yet',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            SizedBox(height: 6),
            Text('Your plan payments show here.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
          ]),
        ),
      );

  static String _date(DateTime d) => PlanStateCopy.date(d);

  Widget _historyList(List<PurchaseHistoryItem> items) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.divider),
          _historyRow(items[i]),
        ],
      ]),
    );
  }

  Widget _historyRow(PurchaseHistoryItem h) {
    final (label, color) = switch (h.status) {
      'Granted' => ('Paid', AppColors.successDark),
      'Paid' => ('Activating', AppColors.warning),
      'Created' || 'Pending' => ('Waiting', AppColors.warning),
      'Refunded' => ('Refunded', AppColors.textLight),
      'Failed' => ('Failed', AppColors.error),
      'Expired' => ('Expired', AppColors.textLight),
      _ => (h.status, AppColors.textLight),
    };
    final cycle = h.cycleMonths != null ? ' · ${h.cycleMonths} mo' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${h.planName}$cycle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            Text(_date(h.createdAt),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${h.payableInr}',
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ]),
    );
  }
}
