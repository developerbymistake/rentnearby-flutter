import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/plan_controller.dart';
import '../models/my_plan_model.dart';
import '../models/plan_model.dart';
import '../models/plan_purchase_result.dart';
import '../models/store_product.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';
import '../widgets/plan_subscription_card.dart';
import '../widgets/purchase_status_sheet.dart';

class PlansBillingScreen extends StatefulWidget {
  const PlansBillingScreen({super.key});
  @override
  State<PlansBillingScreen> createState() => _PlansBillingScreenState();
}

class _PlansBillingScreenState extends State<PlansBillingScreen> {
  final _plans = Get.find<PlanController>();
  final _couponCtrl = TextEditingController();
  final _selectedPlanId = Rxn<String>();
  final _cycles = <String, int>{}.obs;
  final _quote = Rxn<PlanQuote>();
  final _quoteLoading = false.obs;
  final _quoteError = Rxn<String>();
  final _appliedCoupon = Rxn<String>();
  int _quoteSeq = 0;
  bool _sheetOpen = false;
  Worker? _purchaseWorker;

  @override
  void initState() {
    super.initState();
    _load();
    _purchaseWorker = ever<PurchaseStatus?>(_plans.activePurchase, (v) {
      if (v == null) {
        if (_sheetOpen && mounted) Navigator.of(context).pop();
        return;
      }
      _maybeShowStatusSheet();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowStatusSheet());
  }

  @override
  void dispose() {
    _purchaseWorker?.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) => Future.wait([
        _plans.refreshPlan(force: force),
        _plans.loadCatalog(force: force),
        _plans.loadHistory(),
      ]);

  Color get _accent => _accentOf(_plans.myPlan.value.featureKey);

  static Color _accentOf(String? featureKey) => switch (featureKey) {
        'Plot' => AppColors.plot,
        'Stay' => AppColors.stay,
        'Taxi' => AppColors.taxi,
        _ => AppColors.primary,
      };

  static LinearGradient _gradientOf(String? featureKey) => switch (featureKey) {
        'Plot' => AppColors.plotGradient,
        'Stay' => AppColors.stayGradient,
        'Taxi' => AppColors.taxiGradient,
        _ => AppColors.primaryGradient,
      };

  void _maybeShowStatusSheet() {
    if (!mounted || _sheetOpen || _plans.activePurchase.value == null) return;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => PurchaseStatusSheet(accent: _accent),
    ).whenComplete(() {
      _sheetOpen = false;
      final wasOpen = (_plans.activePurchase.value?.isOpen ?? false) && !_plans.pollTimedOut.value;
      _plans.dismissPurchase();
      _plans.loadHistory();
      if (wasOpen) _plans.refreshPlan(force: true);
      if (_selectedPlanId.value != null) _requestQuote();
    });
  }

  Future<void> _requestQuote() async {
    final planId = _selectedPlanId.value;
    if (planId == null) return;
    final cycle = _cycles[planId] ?? 1;
    final seq = ++_quoteSeq;
    final plan = _plans.plans.firstWhereOrNull((p) => p.id == planId);
    if (plan != null && _isOwnedCycle(plan, cycle)) {
      _quote.value = null;
      _quoteError.value = null;
      _quoteLoading.value = false;
      return;
    }
    _quoteLoading.value = true;
    _quoteError.value = null;
    final result = await _plans.quote(planId, cycle, _appliedCoupon.value);
    if (seq != _quoteSeq) return;
    _quoteLoading.value = false;
    switch (result) {
      case QuoteSuccess():
        _quote.value = result.quote;
      case QuoteFailure():
        _quote.value = null;
        if (result.errorType == 'CouponInvalid') {
          _appliedCoupon.value = null;
          _couponCtrl.clear();
          AppToast.error(_plans.isPlay ? 'Coupon not valid with Google Play' : result.message);
          _requestQuote();
          return;
        }
        _quoteError.value = result.message;
    }
  }

  void _selectPlan(PlanModel plan) {
    if (_selectedPlanId.value == plan.id) return;
    _selectedPlanId.value = plan.id;
    _cycles.putIfAbsent(plan.id, () => plan.prices.isEmpty ? 1 : plan.prices.first.cycleMonths);
    _quote.value = null;
    _requestQuote();
  }

  void _selectCycle(PlanModel plan, int cycle) {
    _cycles[plan.id] = cycle;
    _selectedPlanId.value = plan.id;
    _quote.value = null;
    _requestQuote();
  }

  void _applyCoupon() {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    _appliedCoupon.value = code.toUpperCase();
    _requestQuote();
  }

  void _clearCoupon() {
    _appliedCoupon.value = null;
    _couponCtrl.clear();
    _requestQuote();
  }

  Future<void> _buy(PlanModel plan) async {
    final cycle = _cycles[plan.id] ?? 1;
    await _plans.purchase(plan, cycle, _appliedCoupon.value);
  }

  Future<void> _startTrial(PlanModel plan) async {
    if (_plans.isPlay) {
      await _plans.purchase(plan, 1, null, useTrial: true);
    } else {
      await _plans.startTrial(plan.id);
    }
  }

  bool _isOwnedCycle(PlanModel plan, int cycle) {
    final p = _plans.myPlan.value.play;
    final price = plan.priceFor(cycle);
    return p != null &&
        p.ownsActivePlan &&
        plan.playProductId != null &&
        p.productId == plan.playProductId &&
        price?.playBasePlanId != null &&
        p.basePlanId == price!.playBasePlanId;
  }

  String _symbol(StorePrice p) => p.currencyCode == 'INR' ? '₹' : '${p.currencyCode} ';

  int _savePercent(PlanModel plan, PlanPriceModel price) {
    if (!_plans.isPlay) return price.savePercent;
    final one = _plans.storePriceFor(plan, 1);
    final cur = _plans.storePriceFor(plan, price.cycleMonths);
    if (one == null || cur == null || price.cycleMonths <= 1 || one.raw <= 0) return 0;
    final pct = ((1 - cur.raw / (one.raw * price.cycleMonths)) * 100).round();
    return pct > 0 ? pct : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        Obx(() => _header(_plans.myPlan.value.featureKey)),
        Expanded(
          child: RefreshIndicator(
            color: _accent,
            onRefresh: () => _load(force: true),
            child: Obx(() {
              final me = _plans.myPlan.value;
              final loading = _plans.isLoadingPlan.value;
              final catalogLoading = _plans.isLoadingCatalog.value;
              final history = _plans.history.toList();
              final paidPlans = _plans.plans.where((p) => !p.isDefault && p.prices.isNotEmpty).toList();
              final accent = _accentOf(me.featureKey);
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + AppInsets.bottomViewPadding(context)),
                children: [
                  if (me.featureKey == null && !loading && _plans.planLoadFailed.value)
                    _loadFailedState()
                  else if (me.featureKey == null)
                    _emptyState(loading)
                  else ...[
                    _currentPlanCard(me, accent),
                    if (me.play != null) ...[
                      const SizedBox(height: 12),
                      PlanSubscriptionCard(me: me, accent: accent, onResubscribe: () => _resubscribe(me, paidPlans)),
                    ],
                    const SizedBox(height: 20),
                    if (!me.paymentEnabled)
                      _freeModeNote()
                    else ...[
                      _sectionTitle('Choose a plan',
                          _plans.isPlay ? 'Auto-renews. Cancel anytime in Google Play.' : 'Prepaid. Pick how long.'),
                      const SizedBox(height: 12),
                      if (paidPlans.isEmpty)
                        _plansPlaceholder(catalogLoading)
                      else
                        for (final p in paidPlans) ...[
                          _planCard(p, me, accent),
                          const SizedBox(height: 14),
                        ],
                      if (_plans.isPlay) _restoreButton(accent),
                      if (history.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _sectionTitle('History', 'Your plan payments.'),
                        const SizedBox(height: 12),
                        _historyList(history),
                      ],
                    ],
                  ],
                ],
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _restoreButton(Color accent) {
    final busy = _plans.isRestoring.value || _plans.isPurchasing.value;
    return Center(
      child: TextButton(
        onPressed: busy ? null : () => _plans.restorePurchases(force: true, userInitiated: true),
        child: Text(_plans.isRestoring.value ? 'Restoring...' : 'Restore purchases',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: busy ? AppColors.textLight : accent)),
      ),
    );
  }

  void _resubscribe(MyPlanModel me, List<PlanModel> paidPlans) {
    final id = me.play?.productId;
    final plan = paidPlans.firstWhereOrNull((p) => p.playProductId == id) ?? (paidPlans.isNotEmpty ? paidPlans.first : null);
    if (plan != null) _selectPlan(plan);
  }

  Widget _header(String? featureKey) {
    return Container(
      decoration: BoxDecoration(gradient: _gradientOf(featureKey)),
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
                Text('Plans & Billing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Your plan and payments',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _emptyState(bool loading) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: loading
              ? CircularProgressIndicator(strokeWidth: 2, color: _accent)
              : const Column(children: [
                  Text('No plans for you',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  SizedBox(height: 6),
                  Text('Plans are for owners.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
                ]),
        ),
      );

  Widget _loadFailedState() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(children: [
            const Text('Could not load plan',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text('Check your connection.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _load(force: true),
              child: Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: _accent)),
            ),
          ]),
        ),
      );

  Widget _freeModeNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Free for now',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          SizedBox(height: 2),
          Text('Paid plans are not open yet.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        ]),
      );

  Widget _plansPlaceholder(bool loading) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: loading
              ? CircularProgressIndicator(strokeWidth: 2, color: _accent)
              : const Text('No paid plans yet.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        ),
      );

  Widget _sectionTitle(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text(sub, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        ],
      );

  static String _date(DateTime d) => PlanStateCopy.date(d);

  Widget _currentPlanCard(MyPlanModel me, Color accent) {
    final l = me.limits;
    final subtitle = me.play?.ownsActivePlan == true
        ? 'Billed by Google Play'
        : me.hasPaidPlan && me.endsAt != null
            ? 'Ends ${_date(me.endsAt!)}${me.daysLeft != null ? ' · ${me.daysLeft} days left' : ''}'
            : (me.paymentEnabled ? 'No end date' : 'Free for now');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(me.planName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ),
          if (me.isTrial || (me.play?.inTrial ?? false)) _pill('Trial', accent),
        ]),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (me.featureKey == 'Room' || me.featureKey == 'Plot')
            _pill('${l.used} / ${l.listingLimit} ${me.featureKey == 'Room' ? 'rooms' : 'plots'}', accent),
          if (l.priority > 0) _pill('Priority', accent),
          if (l.featured) _pill('Featured', accent),
          if (me.featureKey == 'Stay') _pill('${l.jobsPosts} job post${l.jobsPosts == 1 ? '' : 's'}', AppColors.job),
          if (me.pausedByPlanCount > 0) _pill('${me.pausedByPlanCount} paused by plan', AppColors.warning),
        ]),
      ]),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _bullet(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
          ),
        ]),
      );

  Widget _planCard(PlanModel plan, MyPlanModel me, Color accent) {
    final selected = _selectedPlanId.value == plan.id;
    final cycle = _cycles[plan.id] ?? (plan.prices.isEmpty ? 1 : plan.prices.first.cycleMonths);
    final price = plan.priceFor(cycle) ?? plan.prices.first;
    final isCurrent = me.planId == plan.id && me.hasPaidPlan;
    final quote = selected ? _quote.value : null;
    final quoteLoading = selected && _quoteLoading.value;
    final quoteError = selected ? _quoteError.value : null;
    final purchasing = _plans.isPurchasing.value;
    final isPlay = _plans.isPlay;
    final storeState = _plans.storeState.value;
    final storeCount = _plans.storeProducts.length;
    final otherAccounts = _plans.otherAccountProducts.toSet();
    final storePrice = isPlay && storeCount >= 0 ? _plans.storePriceFor(plan, cycle) : null;
    final notConfigured = isPlay && (plan.playProductId == null || price.playBasePlanId == null);
    final storeLoading = isPlay && !notConfigured && (storeState == StoreState.loading || storeState == StoreState.idle);
    final priceUnavailable = isPlay && !notConfigured && !storeLoading && storePrice == null;
    final ownedCycle = isPlay && _isOwnedCycle(plan, cycle);
    final holdBlocked = isPlay && PlanStateCopy.blocksPurchase(me);
    final trialOffer = isPlay ? _plans.trialOfferFor(plan) : null;
    final canTrial = isPlay
        ? me.trialAvailable && trialOffer != null && !me.hasPaidPlan && !holdBlocked && !notConfigured
        : me.trialAvailable && plan.trialDays > 0;
    final otherAccount = isPlay && plan.playProductId != null && otherAccounts.contains(plan.playProductId);
    final ctaDisabled = purchasing ||
        (selected && quoteLoading) ||
        notConfigured ||
        storeLoading ||
        priceUnavailable ||
        holdBlocked ||
        ownedCycle;
    return GestureDetector(
      onTap: () => _selectPlan(plan),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? accent : AppColors.divider, width: selected ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ),
            if (isCurrent) _pill('Current', accent),
          ]),
          if (plan.tagline != null && plan.tagline!.isNotEmpty)
            Text(plan.tagline!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 12),
          if (plan.listingLimit > 0 && (plan.featureKey == 'Room' || plan.featureKey == 'Plot'))
            _bullet(Icons.home_work_rounded,
                '${plan.listingLimit} live ${plan.featureKey == 'Room' ? 'rooms' : 'plots'}', accent),
          if (plan.hasPriority) _bullet(Icons.trending_up_rounded, 'Priority placement', accent),
          if (plan.isFeatured) _bullet(Icons.star_rounded, 'Featured badge', accent),
          if (plan.featureKey == 'Stay' && plan.jobsPosts > 0)
            _bullet(Icons.work_rounded, '${plan.jobsPosts} job posts', AppColors.job),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in plan.prices) _cycleChip(plan, p, cycle == p.cycleMonths, accent),
          ]),
          const SizedBox(height: 12),
          _priceRow(price, cycle, storePrice,
              notConfigured: notConfigured, loading: storeLoading, unavailable: priceUnavailable, accent: accent),
          if (otherAccount) ...[
            const SizedBox(height: 8),
            const Text('Subscribed on another Bakhli account',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ],
          if (holdBlocked) ...[
            const SizedBox(height: 8),
            const Text('Fix the payment in Google Play first.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warningText)),
          ],
          if (selected && !notConfigured && !ownedCycle) ...[
            const SizedBox(height: 12),
            _couponRow(accent),
            const SizedBox(height: 12),
            _quoteBreakdown(plan, quote, quoteLoading, quoteError, accent),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: ctaDisabled ? null : () => _onCta(plan, selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: purchasing && selected
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_ctaLabel(plan, me, selected, quote, ownedCycle: ownedCycle, notConfigured: notConfigured),
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          if (canTrial) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: purchasing ? null : () => _startTrial(plan),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                    isPlay ? 'Start ${trialOffer?.trialDays ?? plan.trialDays}-day free trial' : 'Try free for ${plan.trialDays} days',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            if (isPlay && _plans.storePriceFor(plan, 1) != null) ...[
              const SizedBox(height: 4),
              Text('Then ${_plans.storePriceFor(plan, 1)!.formatted}/month. Cancel anytime in Google Play.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
            ],
          ],
        ]),
      ),
    );
  }

  void _onCta(PlanModel plan, bool selected) {
    if (!selected) {
      _selectPlan(plan);
      return;
    }
    if (_quote.value == null) {
      _requestQuote();
      return;
    }
    _buy(plan);
  }

  String _ctaLabel(PlanModel plan, MyPlanModel me, bool selected, PlanQuote? quote,
      {required bool ownedCycle, required bool notConfigured}) {
    if (notConfigured) return 'Not available';
    if (ownedCycle) return 'Current plan';
    if (!selected) return 'Select';
    if (quote == null) return 'Retry';
    if (!quote.requiresPayment) return 'Activate';
    final resub = me.play != null && !me.play!.ownsActivePlan && me.play!.ended;
    final verb = switch (quote.intent) {
      'Renew' => 'Renew',
      'Switch' => 'Switch',
      _ => resub ? 'Resubscribe' : (_plans.isPlay ? 'Subscribe' : 'Buy'),
    };
    if (quote.storePriceRequired) {
      final sp = _plans.storePriceFor(plan, quote.cycleMonths);
      return sp != null ? '$verb · ${sp.formatted}' : verb;
    }
    return '$verb · ₹${quote.payableInr}';
  }

  Widget _priceRow(PlanPriceModel price, int cycle, StorePrice? sp,
      {required bool notConfigured, required bool loading, required bool unavailable, required Color accent}) {
    if (notConfigured) {
      return const Text('Not available yet',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textLight));
    }
    if (loading) {
      return Shimmer.fromColors(
        baseColor: AppColors.divider,
        highlightColor: Colors.white,
        child: Container(
          width: 120,
          height: 30,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    if (unavailable) {
      return Row(children: [
        const Text('Price unavailable',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textLight)),
        TextButton(
          onPressed: () => _plans.loadStore(force: true),
          child: Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: accent)),
        ),
      ]);
    }
    final main = sp != null ? sp.formatted : '₹${price.priceInr}';
    final perMonth = sp != null ? '${_symbol(sp)}${(sp.raw / cycle).round()}/mo' : '₹${price.perMonthInr}/mo';
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(main,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      const SizedBox(width: 6),
      Flexible(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(perMonth,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        ),
      ),
    ]);
  }

  Widget _cycleChip(PlanModel plan, PlanPriceModel p, bool active, Color accent) {
    final label = p.cycleMonths == 12 ? '12 mo' : '${p.cycleMonths} mo';
    return GestureDetector(
      onTap: () => _selectCycle(plan, p.cycleMonths),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? accent : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? accent : AppColors.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textMedium)),
          if (_savePercent(plan, p) > 0) ...[
            const SizedBox(width: 6),
            Text('Save ${_savePercent(plan, p)}%',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.successDark)),
          ],
        ]),
      ),
    );
  }

  Widget _couponRow(Color accent) {
    final applied = _appliedCoupon.value;
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 42,
          child: TextField(
            controller: _couponCtrl,
            enabled: applied == null,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: noEmojiInputFormatters,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Coupon code',
              hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textHint),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _applyCoupon(),
          ),
        ),
      ),
      const SizedBox(width: 8),
      TextButton(
        onPressed: applied == null ? _applyCoupon : _clearCoupon,
        child: Text(applied == null ? 'Apply' : 'Remove',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: accent)),
      ),
    ]);
  }

  Widget _quoteBreakdown(PlanModel plan, PlanQuote? q, bool loading, String? error, Color accent) {
    if (loading && q == null) {
      return Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent)));
    }
    if (error != null) {
      return Text(error, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.error));
    }
    if (q == null) return const SizedBox.shrink();
    final sp = q.storePriceRequired && q.requiresPayment ? _plans.storePriceFor(plan, q.cycleMonths) : null;
    if (q.storePriceRequired && q.requiresPayment && sp == null) return const SizedBox.shrink();
    if (sp != null) {
      final replaceNote = q.intent == 'Switch'
          ? (q.playReplacementMode == 'deferred' ? 'Changes when your current period ends.' : 'Google adjusts the charge.')
          : null;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (q.isTrial) ...[
            _line('Today', 'Free for ${_plans.trialOfferFor(plan)?.trialDays ?? plan.trialDays} days', good: true),
            _line('Then', '${sp.formatted}/month'),
          ] else
            _line('You pay', sp.formatted, bold: true),
          if (replaceNote != null) ...[
            const SizedBox(height: 4),
            Text(replaceNote, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ],
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        _line('Plan price', '₹${q.listPriceInr}'),
        if (q.discountInr > 0) _line(q.couponCode != null ? 'Coupon ${q.couponCode}' : 'Discount', '- ₹${q.discountInr}', good: true),
        if (q.creditInr > 0) _line('Unused plan credit', '- ₹${q.creditInr}', good: true),
        const Divider(height: 14),
        _line('You pay', '₹${q.payableInr}', bold: true),
      ]),
    );
  }

  Widget _line(String label, String value, {bool bold = false, bool good = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textMedium)),
          ),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: bold ? 14 : 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: good ? AppColors.successDark : AppColors.textDark)),
        ]),
      );

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
