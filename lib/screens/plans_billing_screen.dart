import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/plan_controller.dart';
import '../models/browse_item.dart';
import '../models/my_plan_model.dart';
import '../models/plan_model.dart';
import '../models/plan_purchase_result.dart';
import '../models/store_product.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';
import '../widgets/plan_compare_table.dart';
import '../widgets/plan_cycle_option.dart';
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
  final _showCoupon = false.obs;
  int _quoteSeq = 0;
  bool _sheetOpen = false;
  Worker? _purchaseWorker;
  Worker? _catalogWorker;

  @override
  void initState() {
    super.initState();
    _load().then((_) => _autoSelect());
    _catalogWorker = ever<PlanCatalogModel?>(_plans.catalog, (_) => _autoSelect());
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
    _catalogWorker?.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) => Future.wait([
        _plans.refreshPlan(force: force),
        _plans.loadCatalog(force: force),
        _plans.loadHistory(),
      ]);

  void _autoSelect() {
    if (!mounted || _selectedPlanId.value != null) return;
    final me = _plans.myPlan.value;
    final paid = _plans.plans.where((p) => !p.isDefault && p.prices.isNotEmpty).toList();
    if (!me.paymentEnabled || paid.isEmpty) return;
    final plan = paid.firstWhereOrNull((p) => p.playProductId != null && p.playProductId == me.play?.productId) ??
        paid.first;
    final cycle = plan.prices
            .firstWhereOrNull((x) => x.playBasePlanId != null && x.playBasePlanId == me.play?.basePlanId)
            ?.cycleMonths ??
        plan.prices.first.cycleMonths;
    _cycles[plan.id] = cycle;
    _selectPlan(plan);
  }

  Color get _accent => PlanAccent.of(_plans.myPlan.value.featureKey);

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
    _showCoupon.value = false;
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

  static String _subtitleFor(String? featureKey) => switch (featureKey) {
        'Plot' => 'Plots plan',
        'Stay' => 'Stay plan',
        'Taxi' => 'Taxi plan',
        _ => 'Rooms plan',
      };

  static String _comingLine(String? featureKey) => switch (featureKey) {
        'Plot' => 'Shown first and more plots. Not open yet.',
        'Stay' => 'Featured, shown first and more job posts. Not open yet.',
        'Taxi' => 'Featured and shown first. Not open yet.',
        _ => 'Shown first and more rooms. Not open yet.',
      };

  static String _cycleTitle(int m) => m == 1 ? '1 month' : '$m months';

  static String _billedText(int m, String formatted) => switch (m) {
        1 => 'Billed monthly',
        3 => 'Billed $formatted every 3 months',
        12 => 'Billed $formatted a year',
        _ => 'Billed $formatted every $m months',
      };

  String _perMonth(StorePrice sp, int m) => '${_symbol(sp)}${(sp.raw / m).round()}';

  static String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  List<String> _includedLines(PlanLimitsModel l, String? featureKey, bool paymentEnabled) {
    final prefix = paymentEnabled ? '' : 'Up to ';
    return [
      if (featureKey == 'Room') '$prefix${_plural(l.listingLimit, 'live room')}',
      if (featureKey == 'Plot') '$prefix${_plural(l.listingLimit, 'live plot')}',
      if (l.priority > 0) 'Shown first in search',
      if (l.featured) 'Featured badge',
      if (featureKey == 'Stay') _plural(l.jobsPosts, 'job post'),
    ];
  }

  List<CompareRow> _featureRows(List<PlanModel> plans, List<PlanModel> paidPlans, MyPlanModel me) {
    final featureKey = me.featureKey;
    final free = plans.firstWhereOrNull((p) => p.isDefault);
    final l = me.limits;
    int freeValue(String key) {
      if (free != null) return free.feature(key);
      return switch (key) {
        PlanFeatureKeys.listingLimit => l.listingLimit,
        PlanFeatureKeys.priority => l.priority,
        PlanFeatureKeys.featured => l.featured ? 1 : 0,
        PlanFeatureKeys.jobsPosts => l.jobsPosts,
        _ => 0,
      };
    }

    List<int> values(String key) => [freeValue(key), for (final p in paidPlans) p.feature(key)];

    CompareRow? row(String key, String label, {required bool number}) {
      final v = values(key);
      if (!v.any((x) => x > 0)) return null;
      return CompareRow(label, [for (final x in v) number ? CompareCell.number(x) : CompareCell.flag(x > 0)]);
    }

    return [
      if (featureKey == 'Room' || featureKey == 'Plot')
        row(PlanFeatureKeys.listingLimit, featureKey == 'Room' ? 'Live rooms' : 'Live plots', number: true),
      row(PlanFeatureKeys.priority, 'Shown first', number: false),
      row(PlanFeatureKeys.featured, 'Featured badge', number: false),
      if (featureKey == 'Stay') row(PlanFeatureKeys.jobsPosts, 'Job posts', number: true),
    ].whereType<CompareRow>().toList();
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
            onRefresh: () => _load(force: true).then((_) => _autoSelect()),
            child: Obx(() {
              final me = _plans.myPlan.value;
              final loading = _plans.isLoadingPlan.value;
              final catalogLoading = _plans.isLoadingCatalog.value;
              final paidPlans = _plans.plans.where((p) => !p.isDefault && p.prices.isNotEmpty).toList();
              final accent = PlanAccent.of(me.featureKey);
              final barVisible = me.featureKey != null && me.paymentEnabled && paidPlans.isNotEmpty;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + (barVisible ? 0 : AppInsets.bottomViewPadding(context))),
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
                    if (!me.paymentEnabled) ...[
                      const SizedBox(height: 12),
                      _comingSoon(me.featureKey),
                    ] else ...[
                      const SizedBox(height: 20),
                      if (paidPlans.isEmpty)
                        _plansPlaceholder(catalogLoading)
                      else
                        ..._purchaseSection(me, paidPlans, accent),
                      if (_plans.isPlay) _restoreButton(accent),
                    ],
                  ],
                ],
              );
            }),
          ),
        ),
        Obx(() => _stickyBar()),
      ]),
    );
  }

  List<Widget> _purchaseSection(MyPlanModel me, List<PlanModel> paidPlans, Color accent) {
    final isPlay = _plans.isPlay;
    final owns = me.play?.ownsActivePlan == true;
    final selectedId = _selectedPlanId.value;
    final selected = paidPlans.firstWhereOrNull((p) => p.id == selectedId);
    final otherAccounts = _plans.otherAccountProducts.toSet();
    final otherAccount =
        isPlay && selected?.playProductId != null && otherAccounts.contains(selected!.playProductId);
    var showCoupon = false;
    if (selected != null) {
      final cycle = _cycles[selected.id] ?? selected.prices.first.cycleMonths;
      final price = selected.priceFor(cycle) ?? selected.prices.first;
      final notConfigured = isPlay && (selected.playProductId == null || price.playBasePlanId == null);
      final ownedCycle = isPlay && _isOwnedCycle(selected, cycle);
      showCoupon = !notConfigured && !ownedCycle;
    }
    return [
      _sectionTitle('What you get', 'Free vs ${paidPlans.map((p) => p.name).join(' vs ')}'),
      const SizedBox(height: 12),
      PlanCompareTable(
        rows: _featureRows(_plans.plans, paidPlans, me),
        paidNames: [for (final p in paidPlans) p.name],
        accent: accent,
      ),
      const SizedBox(height: 20),
      owns
          ? _sectionTitle('Change duration', 'Takes effect at your next renewal')
          : _sectionTitle('Pick how long', isPlay ? 'Auto-renews. Cancel anytime in Google Play.' : 'Prepaid. Pick how long.'),
      const SizedBox(height: 12),
      for (final plan in paidPlans) ...[
        if (paidPlans.length > 1) _planChipRow(plan, accent),
        ..._cycleRows(plan, accent),
        const SizedBox(height: 10),
      ],
      if (otherAccount)
        const Text('Subscribed on another Bakhli account',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
      const SizedBox(height: 8),
      if (showCoupon) _couponLink(accent),
    ];
  }

  Widget _planChipRow(PlanModel plan, Color accent) {
    final active = _selectedPlanId.value == plan.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(children: [
        GestureDetector(
          onTap: () => _selectPlan(plan),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: active ? accent : accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(plan.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : accent)),
          ),
        ),
      ]),
    );
  }

  List<Widget> _cycleRows(PlanModel plan, Color accent) {
    final isPlay = _plans.isPlay;
    final storeState = _plans.storeState.value;
    final selectedCycle = _cycles[plan.id] ?? plan.prices.first.cycleMonths;
    final isSelectedPlan = _selectedPlanId.value == plan.id;
    final saves = [for (final p in plan.prices) _savePercent(plan, p)];
    final maxSave = saves.isEmpty ? 0 : saves.reduce((a, b) => a > b ? a : b);
    final bestIndex = maxSave > 0 ? saves.indexOf(maxSave) : -1;
    return [
      for (var i = 0; i < plan.prices.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: Builder(builder: (_) {
            final price = plan.prices[i];
            final cycle = price.cycleMonths;
            final save = saves[i];
            final saveText = save > 0 ? ' · Save $save%' : '';
            final selected = isSelectedPlan && selectedCycle == cycle;
            if (!isPlay) {
              return PlanCycleOption(
                title: _cycleTitle(cycle),
                subtitle: _billedText(cycle, BrowseItem.inr(price.priceInr)),
                price: BrowseItem.inr(cycle == 1 ? price.priceInr : price.perMonthInr),
                perMonth: cycle == 1 ? '${BrowseItem.inr(price.priceInr)} / mo' : '/ mo$saveText',
                best: i == bestIndex,
                selected: selected,
                onTap: () => _selectCycle(plan, cycle),
                accent: accent,
              );
            }
            final sp = _plans.storePriceFor(plan, cycle);
            final notConfigured = plan.playProductId == null || price.playBasePlanId == null;
            final storeLoading =
                !notConfigured && (storeState == StoreState.loading || storeState == StoreState.idle);
            final priceUnavailable = !notConfigured && !storeLoading && sp == null;
            final subtitle = _isOwnedCycle(plan, cycle)
                ? 'Your current cycle'
                : (sp != null ? _billedText(cycle, sp.formatted) : (cycle == 1 ? 'Billed monthly' : ''));
            return PlanCycleOption(
              title: _cycleTitle(cycle),
              subtitle: subtitle,
              price: sp == null ? null : (cycle == 1 ? sp.formatted : _perMonth(sp, cycle)),
              perMonth: sp == null ? null : (cycle == 1 ? '${sp.formatted} / mo' : '/ mo$saveText'),
              best: i == bestIndex,
              selected: selected,
              onTap: () => _selectCycle(plan, cycle),
              accent: accent,
              unavailableText: notConfigured ? 'Not available yet' : (priceUnavailable ? 'Price unavailable' : null),
              onRetry: priceUnavailable ? () => _plans.loadStore(force: true) : null,
            );
          }),
        ),
    ];
  }

  Widget _couponLink(Color accent) {
    if (!_showCoupon.value && _appliedCoupon.value == null) {
      return Center(
        child: TextButton(
          onPressed: () => _showCoupon.value = true,
          child: Text('Have a coupon?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
        ),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: _couponRow(accent));
  }

  Widget _comingSoon(String? featureKey) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Paid plans are coming',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(_comingLine(featureKey),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        ]),
      );

  Widget _stickyBar() {
    final me = _plans.myPlan.value;
    final paidPlans = _plans.plans.where((p) => !p.isDefault && p.prices.isNotEmpty).toList();
    final selectedId = _selectedPlanId.value;
    final appliedCoupon = _appliedCoupon.value;
    if (me.featureKey == null || !me.paymentEnabled || paidPlans.isEmpty) return const SizedBox.shrink();
    final plan = paidPlans.firstWhereOrNull((p) => p.id == selectedId) ?? paidPlans.first;
    final selected = selectedId == plan.id;
    final accent = PlanAccent.of(me.featureKey);
    final cycle = _cycles[plan.id] ?? plan.prices.first.cycleMonths;
    final price = plan.priceFor(cycle) ?? plan.prices.first;
    final quote = selected ? _quote.value : null;
    final quoteLoading = selected && _quoteLoading.value;
    final quoteError = selected ? _quoteError.value : null;
    final purchasing = _plans.isPurchasing.value;
    final isPlay = _plans.isPlay;
    final storeState = _plans.storeState.value;
    final storeCount = _plans.storeProducts.length;
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
    final ctaDisabled =
        purchasing || quoteLoading || notConfigured || storeLoading || priceUnavailable || holdBlocked || ownedCycle;

    final quoteSp = quote != null && quote.storePriceRequired ? _plans.storePriceFor(plan, quote.cycleMonths) : null;
    final fallbackPrice = isPlay ? (storePrice != null ? '${storePrice.formatted} today' : null) : '${BrowseItem.inr(price.priceInr)} today';

    Widget right;
    if (ownedCycle || notConfigured || quoteError != null) {
      right = const SizedBox.shrink();
    } else if (storeLoading || (quoteLoading && quote == null)) {
      right = _shimmerBox(80, 18);
    } else if (priceUnavailable) {
      right = _barText('Price unavailable', AppColors.textLight, bold: false);
    } else if (quote != null && quote.isTrial) {
      right = _barText('Free for ${trialOffer?.trialDays ?? plan.trialDays} days', AppColors.successDark);
    } else if (quote != null && !quote.requiresPayment) {
      right = _barText('₹0 today', AppColors.textDark);
    } else if (quote != null && quote.storePriceRequired) {
      right = quoteSp != null ? _barText('${quoteSp.formatted} today', AppColors.textDark) : const SizedBox.shrink();
    } else if (quote != null) {
      right = _barText('${BrowseItem.inr(quote.payableInr)} today', AppColors.textDark);
    } else {
      right = fallbackPrice != null ? _barText(fallbackPrice, AppColors.textDark) : const SizedBox.shrink();
    }

    String? note;
    var noteColor = AppColors.textLight;
    if (quoteError != null) {
      note = quoteError;
      noteColor = AppColors.error;
    } else if (holdBlocked) {
      note = 'Fix the payment in Google Play first.';
      noteColor = AppColors.warningText;
    } else if (quote != null && quote.storePriceRequired) {
      if (quote.isTrial && quoteSp != null) {
        note = 'Then ${quoteSp.formatted}/month.';
      } else if (quote.intent == 'Switch') {
        note = quote.playReplacementMode == 'deferred'
            ? 'Changes when your current period ends.'
            : 'Google adjusts the charge.';
      }
    } else if (quote != null) {
      final parts = [
        if (quote.discountInr > 0)
          '${quote.couponCode != null ? 'Coupon ${quote.couponCode}' : (appliedCoupon != null ? 'Coupon $appliedCoupon' : 'Discount')} − ₹${quote.discountInr}',
        if (quote.creditInr > 0) 'Unused plan credit − ₹${quote.creditInr}',
      ];
      if (parts.isNotEmpty) {
        note = parts.join(' · ');
        noteColor = AppColors.successDark;
      }
    }

    final label = quoteLoading && quote == null && !ownedCycle && !notConfigured
        ? 'Continue with ${plan.name}'
        : _ctaLabel(plan, me, selected, quote, ownedCycle: ownedCycle, notConfigured: notConfigured);

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, -4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Text('${plan.name} · ${_cycleTitle(cycle)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ),
          const SizedBox(width: 8),
          Flexible(child: Align(alignment: Alignment.centerRight, child: right)),
        ]),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(note, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: noteColor)),
          ),
        const SizedBox(height: 7),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: ctaDisabled ? null : () => _onCta(plan, selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: purchasing && selected
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        maxLines: 1,
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
          ),
        ),
        if (canTrial) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: purchasing ? null : () => _startTrial(plan),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                    isPlay ? 'Try free for ${trialOffer?.trialDays ?? plan.trialDays} days' : 'Try free for ${plan.trialDays} days',
                    maxLines: 1,
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
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
    );
  }

  Widget _barText(String text, Color color, {bool bold = true}) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontFamily: 'Poppins', fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color));

  Widget _shimmerBox(double width, double height) => Shimmer.fromColors(
        baseColor: AppColors.divider,
        highlightColor: Colors.white,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        ),
      );

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
    if (plan == null) return;
    if (_selectedPlanId.value == plan.id) {
      _onCta(plan, true);
    } else {
      _selectPlan(plan);
    }
  }

  Widget _header(String? featureKey) {
    return Container(
      decoration: BoxDecoration(gradient: PlanAccent.gradientOf(featureKey)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 20),
          child: Row(children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Plans & Billing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                if (featureKey != null)
                  Text(_subtitleFor(featureKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
              ]),
            ),
            if (featureKey != null) ...[
              const SizedBox(width: 8),
              _historyButton(),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _historyButton() => GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.planHistory),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.history_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text('History',
                maxLines: 1,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      );

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
    final lines = _includedLines(l, me.featureKey, me.paymentEnabled);
    final usageLabel = switch (me.featureKey) {
      'Room' => 'Live rooms',
      'Plot' => 'Live plots',
      _ => null,
    };
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
          if (me.isTrial || (me.play?.inTrial ?? false)) ...[
            _pill('Trial', accent),
            const SizedBox(width: 6),
          ],
          _pill(me.hasPaidPlan ? 'Active' : 'Your plan', me.hasPaidPlan ? AppColors.successDark : accent),
        ]),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        if (usageLabel != null) ...[
          const SizedBox(height: 12),
          _usageBar(usageLabel, l.live, l.listingLimit, accent),
        ],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.check_rounded, size: 15, color: AppColors.successDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(line,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
                ),
              ]),
            ),
        ],
        if (me.pausedByPlanCount > 0) ...[
          const SizedBox(height: 8),
          _pill('${me.pausedByPlanCount} paused by plan', AppColors.warning),
        ],
      ]),
    );
  }

  Widget _usageBar(String label, int live, int limit, Color accent) {
    const style = TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMedium);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        const SizedBox(width: 8),
        Text('$live of $limit used', style: style),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          minHeight: 7,
          value: limit <= 0 ? 0 : (live / limit).clamp(0.0, 1.0),
          backgroundColor: AppColors.divider,
          color: accent,
        ),
      ),
    ]);
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
    return switch (quote.intent) {
      'Renew' => 'Renew',
      'Switch' => 'Switch',
      _ => resub ? 'Resubscribe' : 'Continue with ${plan.name}',
    };
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
}
