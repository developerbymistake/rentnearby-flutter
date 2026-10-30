import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/plan_controller.dart';
import '../models/my_plan_model.dart';
import '../models/plan_model.dart';
import '../models/plan_purchase_result.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';

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
      builder: (_) => _PurchaseStatusSheet(accent: _accent),
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
          AppToast.error(result.message);
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
    await _plans.startTrial(plan.id);
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
                    const SizedBox(height: 20),
                    if (!me.paymentEnabled)
                      _freeModeNote()
                    else ...[
                      _sectionTitle('Choose a plan', 'Prepaid. Pick how long.'),
                      const SizedBox(height: 12),
                      if (paidPlans.isEmpty)
                        _plansPlaceholder(catalogLoading)
                      else
                        for (final p in paidPlans) ...[
                          _planCard(p, me, accent),
                          const SizedBox(height: 14),
                        ],
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

  static String _date(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Widget _currentPlanCard(MyPlanModel me, Color accent) {
    final l = me.limits;
    final subtitle = me.hasPaidPlan && me.endsAt != null
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
          if (me.isTrial) _pill('Trial', accent),
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
    final canTrial = me.trialAvailable && plan.trialDays > 0;
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
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${price.priceInr}',
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(width: 6),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('₹${price.perMonthInr}/mo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              ),
            ),
          ]),
          if (selected) ...[
            const SizedBox(height: 12),
            _couponRow(accent),
            const SizedBox(height: 12),
            _quoteBreakdown(quote, quoteLoading, quoteError, accent),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: purchasing || (selected && quoteLoading) ? null : () => _onCta(plan, selected),
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
                  : Text(_ctaLabel(selected, quote),
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
                child: Text('Try free for ${plan.trialDays} days',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
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

  String _ctaLabel(bool selected, PlanQuote? quote) {
    if (!selected) return 'Select';
    if (quote == null) return 'Retry';
    if (!quote.requiresPayment) return 'Activate';
    final verb = switch (quote.intent) {
      'Renew' => 'Renew',
      'Switch' => 'Switch',
      _ => 'Buy',
    };
    return '$verb · ₹${quote.payableInr}';
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
          if (p.savePercent > 0) ...[
            const SizedBox(width: 6),
            Text('Save ${p.savePercent}%',
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

  Widget _quoteBreakdown(PlanQuote? q, bool loading, String? error, Color accent) {
    if (loading && q == null) {
      return Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent)));
    }
    if (error != null) {
      return Text(error, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.error));
    }
    if (q == null) return const SizedBox.shrink();
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

class _PurchaseStatusSheet extends StatelessWidget {
  final Color accent;
  const _PurchaseStatusSheet({required this.accent});

  @override
  Widget build(BuildContext context) {
    final plans = Get.find<PlanController>();
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Obx(() {
            final s = plans.activePurchase.value;
            final timedOut = plans.pollTimedOut.value;
            if (s == null) {
              return SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              );
            }
            final waiting = s.isOpen && !timedOut;
            final IconData icon;
            final Color color;
            final String title;
            final String body;
            if (s.isGranted) {
              icon = Icons.check_circle_rounded;
              color = AppColors.success;
              title = 'Plan active';
              body = s.endsAt != null ? '${s.planName} is active till ${_PlansBillingScreenState._date(s.endsAt!)}.' : '${s.planName} is active.';
            } else if (s.status == 'VerifyFailed') {
              icon = Icons.error_outline_rounded;
              color = AppColors.error;
              title = 'Could not verify';
              body = 'If money was taken, your plan activates soon.';
            } else if (s.status == 'Failed') {
              icon = Icons.error_rounded;
              color = AppColors.error;
              title = 'Payment failed';
              body = s.failureReason ?? 'No money was taken. Try again.';
            } else if (s.status == 'Expired') {
              icon = Icons.timer_off_rounded;
              color = AppColors.textLight;
              title = 'Order expired';
              body = 'Please start again.';
            } else if (s.status == 'Refunded') {
              icon = Icons.undo_rounded;
              color = AppColors.textLight;
              title = 'Payment refunded';
              body = 'Your money is on its way back.';
            } else if (s.status == 'Created' && timedOut) {
              icon = Icons.hourglass_bottom_rounded;
              color = AppColors.warning;
              title = 'No payment found';
              body = 'If money was taken, your plan activates soon.';
            } else if (s.isOpen && timedOut) {
              icon = Icons.hourglass_bottom_rounded;
              color = AppColors.warning;
              title = 'Almost there';
              body = 'Plan will activate automatically.';
            } else if (s.isBlocked) {
              icon = Icons.error_outline_rounded;
              color = AppColors.warning;
              title = 'Payment on hold';
              body = s.grantBlockedReason == 'AmountMismatch'
                  ? 'Amount did not match. You will be refunded.'
                  : 'Plan could not start. Refund is on its way.';
            } else if (s.isPaid) {
              icon = Icons.autorenew_rounded;
              color = accent;
              title = 'Activating plan';
              body = 'Payment received.';
            } else {
              icon = Icons.hourglass_top_rounded;
              color = accent;
              title = s.status == 'Created' ? 'Checking payment' : 'Confirming payment';
              body = 'Please wait.';
            }
            return Column(mainAxisSize: MainAxisSize.min, children: [
              waiting
                  ? SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, color: accent))
                  : Icon(icon, size: 56, color: color),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
              const SizedBox(height: 20),
              if (!waiting)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (s.isGranted) AppToast.success('Plan updated.');
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                  ),
                ),
            ]);
          }),
        ),
      ),
    );
  }
}
