import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
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
      backgroundColor: DesignColors.scaffold,
      body: Column(children: [
        Obx(() => ModuleHeader(
              title: 'History',
              subtitle: 'Your plan payments',
              gradient: PlanAccent.gradientOf(_plans.myPlan.value.featureKey),
              onBack: () => Get.back(),
            )),
        Expanded(
          child: Obx(() {
            final items = _plans.history.toList();
            final loading = _plans.isLoadingHistory.value;
            final failed = _plans.historyLoadFailed.value;
            final accent = PlanAccent.of(_plans.myPlan.value.featureKey);
            final bottom = KitMetrics.sectionGap + AppInsets.bottomViewPadding(context);
            final Widget content;
            if (items.isEmpty && loading) {
              content = _loadingState();
            } else if (items.isEmpty && failed) {
              content = StateCard.error(
                title: 'Could not load',
                message: 'Check your connection.',
                actionLabel: 'Retry',
                onAction: _plans.loadHistory,
              );
            } else if (items.isEmpty) {
              content = const StateCard(
                asset: TravelIcon.note,
                title: 'No payments yet',
                message: 'Your plan payments show here.',
              );
            } else {
              content = _historyList(items);
            }
            return RefreshIndicator(
              color: accent,
              onRefresh: _plans.loadHistory,
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.fromLTRB(0, KitMetrics.cardGap, 0, bottom),
                children: [KitSwitcher(child: KeyedSubtree(key: ValueKey(content.runtimeType), child: content))],
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _loadingState() => Column(children: [for (var i = 0; i < 4; i++) ListRow.skeleton()]);

  static String _date(DateTime d) => PlanStateCopy.date(d);

  Widget _historyList(List<PurchaseHistoryItem> items) {
    return Column(children: [
      for (var i = 0; i < items.length; i++) EntranceOnce(index: i < 6 ? i : 6, child: _historyRow(items[i])),
    ]);
  }

  Widget _historyRow(PurchaseHistoryItem h) {
    final (label, color, tone, asset) = switch (h.status) {
      'Granted' => ('Paid', DesignColors.goodDeep, KitTone.brand, TravelIcon.money),
      'Paid' => ('Activating', DesignColors.warnDeep, KitTone.taxi, TravelIcon.calendar),
      'Created' || 'Pending' => ('Waiting', DesignColors.warnDeep, KitTone.taxi, TravelIcon.calendar),
      'Refunded' => ('Refunded', DesignColors.textSecondary, KitTone.stay, TravelIcon.note),
      'Failed' => ('Failed', RepliesTone.bad, KitTone.rose, 'assets/images/design/fitness_app/burned.png'),
      'Expired' => ('Expired', DesignColors.textSecondary, KitTone.stay, TravelIcon.note),
      _ => (h.status, DesignColors.textSecondary, KitTone.stay, TravelIcon.note),
    };
    final cycle = h.cycleMonths != null ? ' · ${h.cycleMonths} mo' : '';
    return ListRow(
      title: '${h.planName}$cycle',
      subtitle: _date(h.createdAt),
      tone: tone,
      iconAsset: asset,
      compact: true,
      showChevron: false,
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('₹${h.payableInr}', style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2)),
        Text(label, style: TypeTokens.style(11, FontWeight.w600, color: color)),
      ]),
    );
  }
}
