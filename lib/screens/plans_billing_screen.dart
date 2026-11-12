import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
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
      backgroundColor: DesignColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: CardRadius.sheet),
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
        'Stay' => 'Stay plan',
        'Taxi' => 'Taxi plan',
        _ => '',
      };

  static String _comingLine(String? featureKey) => switch (featureKey) {
        'Stay' => 'Featured, shown first and more job posts. Not open yet.',
        'Taxi' => 'Featured and shown first. Not open yet.',
        _ => '',
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

  List<String> _includedLines(PlanLimitsModel l, String? featureKey) {
    return [
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
      row(PlanFeatureKeys.priority, 'Shown first', number: false),
      row(PlanFeatureKeys.featured, 'Featured badge', number: false),
      if (featureKey == 'Stay') row(PlanFeatureKeys.jobsPosts, 'Job posts', number: true),
    ].whereType<CompareRow>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(children: [
        Obx(() {
          final key = _plans.myPlan.value.featureKey;
          return ModuleHeader(
            title: 'Plans & Billing',
            subtitle: key == null ? null : _subtitleFor(key),
            gradient: PlanAccent.gradientOf(key),
            onBack: () => Get.back(),
            trailing: key == null ? const [] : [_historyButton()],
          );
        }),
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
              final List<Widget> children;
              var settled = true;
              if (me.featureKey == null && !loading && _plans.planLoadFailed.value) {
                children = [_loadFailedState()];
              } else if (me.featureKey == null) {
                settled = !loading;
                children = loading ? _loadingBlocks() : [_emptyState()];
              } else {
                children = [
                  _currentPlanCard(me, accent),
                  if (me.play != null) ...[
                    const SizedBox(height: KitMetrics.cardGap),
                    PlanSubscriptionCard(me: me, accent: accent, onResubscribe: () => _resubscribe(me, paidPlans)),
                  ],
                  if (!me.paymentEnabled) ...[
                    const SizedBox(height: KitMetrics.cardGap),
                    _comingSoon(me.featureKey),
                  ] else ...[
                    const SizedBox(height: KitMetrics.sectionGap),
                    if (paidPlans.isEmpty)
                      _plansPlaceholder(catalogLoading)
                    else
                      ..._purchaseSection(me, paidPlans, accent),
                    if (_plans.isPlay) _restoreButton(accent),
                  ],
                ];
              }
              var i = 0;
              return StaggerHost(
                key: ValueKey(settled),
                count: 8,
                child: ListView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(KitMetrics.gutter, KitMetrics.sectionGap, KitMetrics.gutter,
                      KitMetrics.sectionGap + (barVisible ? 0 : AppInsets.bottomViewPadding(context))),
                  children: [
                    for (final w in children)
                      if (w is SizedBox || !settled) w else StaggerItem(index: math.min(i++, 7), child: w),
                  ],
                ),
              );
            }),
          ),
        ),
        Obx(() => _stickyBar()),
      ]),
    );
  }

  List<Widget> _loadingBlocks() => [
        HeroBanner.skeleton(height: 140),
        const SizedBox(height: KitMetrics.sectionGap),
        for (var k = 0; k < 3; k++) ListRow.skeleton(margin: const EdgeInsets.only(bottom: KitMetrics.cardGap)),
      ];

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
      const SizedBox(height: KitMetrics.cardGap),
      PlanCompareTable(
        rows: _featureRows(_plans.plans, paidPlans, me),
        paidNames: [for (final p in paidPlans) p.name],
        accent: accent,
      ),
      const SizedBox(height: KitMetrics.sectionGap),
      owns
          ? _sectionTitle('Change duration', 'Takes effect at your next renewal')
          : _sectionTitle('Pick how long', isPlay ? 'Auto-renews. Cancel anytime in Google Play.' : 'Prepaid. Pick how long.'),
      const SizedBox(height: KitMetrics.cardGap),
      for (final plan in paidPlans) ...[
        if (paidPlans.length > 1) _planChipRow(plan, accent),
        ..._cycleRows(plan, accent),
        const SizedBox(height: 10),
      ],
      if (otherAccount)
        Text('Subscribed on another Bakhli account',
            style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary)),
      const SizedBox(height: 8),
      if (showCoupon) _couponLink(accent),
    ];
  }

  Widget _planChipRow(PlanModel plan, Color accent) {
    final active = _selectedPlanId.value == plan.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(children: [
        PressScale(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: active ? accent : DesignColors.tint(accent, Alpha.tint),
              borderRadius: CardRadius.pill,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: CardRadius.pill,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _selectPlan(plan),
                splashColor: DesignColors.whiteSoft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(12, FontWeight.w600,
                          color: active ? DesignColors.textInverse : accent)),
                ),
              ),
            ),
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
          padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
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
        child: TextLink(label: 'Have a coupon?', onTap: () => _showCoupon.value = true),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: _couponRow(accent));
  }

  Widget _comingSoon(String? featureKey) => SectionTile(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RepliesTone.gradient),
            child: Image.asset(TravelIcon.money),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Paid plans are coming',
                  style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2)),
              const SizedBox(height: 2),
              Text(_comingLine(featureKey),
                  style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary)),
            ]),
          ),
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
      right = const TemplatePlaceholder(width: 80, height: 18, radius: 6);
    } else if (priceUnavailable) {
      right = _barText('Price unavailable', DesignColors.textSecondary, bold: false);
    } else if (quote != null && quote.isTrial) {
      right = _barText('Free for ${trialOffer?.trialDays ?? plan.trialDays} days', DesignColors.goodDeep);
    } else if (quote != null && !quote.requiresPayment) {
      right = _barText('₹0 today', DesignColors.textStrong);
    } else if (quote != null && quote.storePriceRequired) {
      right = quoteSp != null ? _barText('${quoteSp.formatted} today', DesignColors.textStrong) : const SizedBox.shrink();
    } else if (quote != null) {
      right = _barText('${BrowseItem.inr(quote.payableInr)} today', DesignColors.textStrong);
    } else {
      right = fallbackPrice != null ? _barText(fallbackPrice, DesignColors.textStrong) : const SizedBox.shrink();
    }

    String? note;
    var noteColor = DesignColors.textSecondary;
    if (quoteError != null) {
      note = quoteError;
      noteColor = RepliesTone.bad;
    } else if (holdBlocked) {
      note = 'Fix the payment in Google Play first.';
      noteColor = DesignColors.warnDeep;
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
        noteColor = DesignColors.goodDeep;
      }
    }

    final label = quoteLoading && quote == null && !ownedCycle && !notConfigured
        ? 'Continue with ${plan.name}'
        : _ctaLabel(plan, me, selected, quote, ownedCycle: ownedCycle, notConfigured: notConfigured);

    final planTone = PlanAccent.toneOf(me.featureKey);
    final trialDays = isPlay ? (trialOffer?.trialDays ?? plan.trialDays) : plan.trialDays;
    return Container(
      padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 14, KitMetrics.gutter, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: CardRadius.sheet,
        boxShadow: ShadowTokens.elev3Up,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Text('${plan.name} · ${_cycleTitle(cycle)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(11, FontWeight.w500, color: TypeTokens.secondary)),
          ),
          const SizedBox(width: 8),
          Flexible(child: Align(alignment: Alignment.centerRight, child: right)),
        ]),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(note, style: TypeTokens.style(12, FontWeight.w500, color: noteColor)),
          ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: label,
          tone: planTone,
          loading: purchasing && selected,
          onPressed: ctaDisabled ? null : () => _onCta(plan, selected),
        ),
        if (canTrial) ...[
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Try free for $trialDays days',
            tone: planTone,
            onPressed: purchasing ? null : () => _startTrial(plan),
          ),
          if (isPlay && _plans.storePriceFor(plan, 1) != null) ...[
            const SizedBox(height: 4),
            Text('Then ${_plans.storePriceFor(plan, 1)!.formatted}/month. Cancel anytime in Google Play.',
                textAlign: TextAlign.center,
                style: TypeTokens.style(11, FontWeight.w500, color: TypeTokens.secondary)),
          ],
        ],
      ]),
    );
  }

  Widget _barText(String text, Color color, {bool bold = true}) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TypeTokens.style(12, bold ? FontWeight.w700 : FontWeight.w500, color: color));

  Widget _restoreButton(Color accent) {
    final busy = _plans.isRestoring.value || _plans.isPurchasing.value;
    return Center(
      child: TextLink(
        label: _plans.isRestoring.value ? 'Restoring...' : 'Restore purchases',
        onTap: busy ? null : () => _plans.restorePurchases(force: true, userInitiated: true),
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

  Widget _historyButton() => PillAction(
        label: 'History',
        icon: const TravelIcon(TravelIcon.calendar, size: 16),
        onTap: () => Get.toNamed(AppRoutes.planHistory),
      );

  Widget _emptyState() => const StateCard(
        asset: TravelIcon.checkout,
        title: 'No plans for you',
        message: 'Plans are for owners.',
      );

  Widget _loadFailedState() => StateCard.error(
        title: 'Could not load plan',
        message: 'Check your connection.',
        actionLabel: 'Retry',
        onAction: () => _load(force: true),
      );

  Widget _plansPlaceholder(bool loading) => Padding(
        padding: const EdgeInsets.symmetric(vertical: KitMetrics.sectionGap),
        child: Center(
          child: loading
              ? Column(children: [
                  HeroBanner.skeleton(height: 140),
                  const SizedBox(height: KitMetrics.sectionGap),
                  ListRow.skeleton(margin: const EdgeInsets.only(bottom: KitMetrics.cardGap)),
                  ListRow.skeleton(margin: EdgeInsets.zero),
                ])
              : Text('No paid plans yet.',
                  style: TypeTokens.style(14, FontWeight.w500, color: TypeTokens.secondary)),
        ),
      );

  Widget _sectionTitle(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2)),
          const SizedBox(height: 2),
          Text(sub, style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary)),
        ],
      );

  static String _date(DateTime d) => PlanStateCopy.date(d);

  Widget _currentPlanCard(MyPlanModel me, Color accent) {
    final l = me.limits;
    final key = me.featureKey;
    final end = PlanAccent.endOf(key);
    final subtitle = me.play?.ownsActivePlan == true
        ? 'Billed by Google Play'
        : me.hasPaidPlan && me.endsAt != null
            ? 'Ends ${_date(me.endsAt!)}${me.daysLeft != null ? ' · ${me.daysLeft} days left' : ''}'
            : (me.paymentEnabled ? 'No end date' : 'Free for now');
    final lines = _includedLines(l, key);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: PlanAccent.gradientOf(key),
        borderRadius: CardRadius.hero,
        boxShadow: ShadowTokens.glow(end),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: DesignColors.whiteSoft, shape: BoxShape.circle),
            child: Image.asset(PlanAccent.iconAsset(key)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(me.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(20, FontWeight.w700, color: DesignColors.surface, letterSpacing: 0.2)),
                ),
                if (me.isTrial || (me.play?.inTrial ?? false)) ...[
                  _pill('Trial', DesignColors.surface),
                  const SizedBox(width: 6),
                ],
                me.hasPaidPlan ? _pill('Active', end, filled: true) : _pill('Your plan', DesignColors.surface),
              ]),
              const SizedBox(height: 2),
              Text(subtitle, style: TypeTokens.onGradientBody),
            ]),
          ),
        ]),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.check_rounded, size: 16, color: DesignColors.surface),
                const SizedBox(width: 8),
                Expanded(child: Text(line, style: TypeTokens.onGradientBody)),
              ]),
            ),
        ],
        if (me.pausedByPlanCount > 0) ...[
          const SizedBox(height: 8),
          _pill('${me.pausedByPlanCount} paused by plan', DesignColors.surface),
        ],
      ]),
    );
  }

  Widget _pill(String text, Color color, {bool filled = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? DesignColors.surfaceAlt : DesignColors.whiteSoft,
          borderRadius: CardRadius.pill,
        ),
        child: Text(text, style: TypeTokens.style(11, FontWeight.w600, color: color)),
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
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(38)),
            boxShadow: ShadowTokens.elev1,
          ),
          child: TextField(
            controller: _couponCtrl,
            enabled: applied == null,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: noEmojiInputFormatters,
            style: TypeTokens.style(14, FontWeight.w400, color: DesignColors.textStrong),
            decoration: InputDecoration(
              hintText: 'Coupon code',
              hintStyle: TypeTokens.style(14, FontWeight.w400, color: DesignColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              border: InputBorder.none,
            ),
            onSubmitted: (_) => _applyCoupon(),
          ),
        ),
      ),
      const SizedBox(width: 8),
      TextLink(label: applied == null ? 'Apply' : 'Remove', onTap: applied == null ? _applyCoupon : _clearCoupon),
    ]);
  }
}
