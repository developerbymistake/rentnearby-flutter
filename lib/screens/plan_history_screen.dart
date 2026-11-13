import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';
import '../config/app_insets.dart';
import '../controllers/plan_controller.dart';
import '../models/plan_purchase_result.dart';
import '../utils/money_format.dart';
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
    return Obx(() {
      final key = _plans.myPlan.value.featureKey;
      final tone = PlanLook.toneOf(key);
      return KitStatusBar(
        lightIcons: false,
        child: Scaffold(
          backgroundColor: PlanLook.pageOf(key),
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              PageHeader3D(
                tone: tone,
                title: 'History',
                subtitle: 'Your plan payments',
                art: ListingArt.calendar,
                artSize: 128,
                onBack: () => Get.back(),
              ),
              Expanded(child: _body(tone)),
            ]),
          ),
        ),
      );
    });
  }

  Widget _body(ListingTone tone) {
    final items = _plans.history.toList();
    final loading = _plans.isLoadingHistory.value;
    final failed = _plans.historyLoadFailed.value;
    final bottom = KitMetrics.sectionGap + AppInsets.bottomViewPadding(context);
    final Widget content;
    if (items.isEmpty && loading) {
      content = const PlanSkeleton3D(hero: false, rows: 4);
    } else if (items.isEmpty && failed) {
      content = PlanStateCard3D(
        tone: tone,
        art: ListingArt.worldMap,
        title: 'Could not load',
        message: 'Check your connection.',
        actionLabel: 'Retry',
        onAction: _plans.loadHistory,
      );
    } else if (items.isEmpty) {
      content = PlanStateCard3D(
        tone: tone,
        art: TravelIcon.note,
        title: 'No payments yet',
        message: 'Your plan payments show here.',
      );
    } else {
      content = _historyList(items);
    }
    return RefreshIndicator(
      color: tone.g2,
      onRefresh: _plans.loadHistory,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
        children: [KitSwitcher(child: KeyedSubtree(key: ValueKey(content.runtimeType), child: content))],
      ),
    );
  }

  static String _date(DateTime d) => PlanStateCopy.date(d);

  Widget _historyList(List<PurchaseHistoryItem> items) {
    return Column(children: [
      for (var i = 0; i < items.length; i++) EntranceOnce(index: i < 6 ? i : 6, child: _historyRow(items[i])),
    ]);
  }

  Widget _historyRow(PurchaseHistoryItem h) {
    final (label, color, tone, asset) = switch (h.status) {
      'Granted' => ('Paid', PlanInk.good, ListingTone.cB, TravelIcon.money),
      'Paid' => ('Activating', PlanInk.warn, ListingTone.cA, TravelIcon.calendar),
      'Created' || 'Pending' => ('Waiting', PlanInk.warn, ListingTone.cA, TravelIcon.calendar),
      'Refunded' => ('Refunded', PlanInk.copy, ListingTone.cE, TravelIcon.note),
      'Failed' => ('Failed', PlanInk.bad, ListingTone.cC, TravelIcon.money),
      'Expired' => ('Expired', PlanInk.copy, ListingTone.cE, TravelIcon.note),
      _ => (h.status, PlanInk.copy, ListingTone.cE, TravelIcon.note),
    };
    final cycle = h.cycleMonths != null ? ' · ${h.cycleMonths} mo' : '';
    return PlanHistoryCard3D(
      tone: tone,
      art: asset,
      title: '${h.planName}$cycle',
      date: _date(h.createdAt),
      amount: Money.exact(h.payableInr),
      status: label,
      statusColor: color,
    );
  }
}
