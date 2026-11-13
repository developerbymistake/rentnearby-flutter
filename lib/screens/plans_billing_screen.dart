import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
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
    showDockSheet<void>(
      context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.none,
      barrierColor: PlanInk.scrim,
      builder: (_) => PurchaseStatusSheet(accent: _accent, tone: PlanLook.toneOf(_plans.myPlan.value.featureKey)),
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
    return Obx(() {
      final key = _lookKey();
      final tone = PlanLook.toneOf(key);
      return KitStatusBar(
        lightIcons: false,
        child: Scaffold(
          backgroundColor: PlanLook.pageOf(key),
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              Expanded(
                child: RefreshIndicator(
                  color: tone.g2,
                  onRefresh: () => _load(force: true).then((_) => _autoSelect()),
                  child: _list(tone),
                ),
              ),
              _stickyBar(),
            ]),
          ),
        ),
      );
    });
  }

  String? _lookKey() {
    final key = _plans.myPlan.value.featureKey;
    if (key != null || !Get.isRegistered<AuthController>()) return key;
    final auth = Get.find<AuthController>();
    if (auth.canListStays.value) return 'Stay';
    if (auth.canListTaxis.value) return 'Taxi';
    return null;
  }

  Widget _header(ListingTone tone, String? key) => PageHeader3D(
        tone: tone,
        title: 'Plans & Billing',
        subtitle: key == null ? null : _subtitleFor(key),
        art: ListingArt.moneyBag,
        artSize: MediaQuery.sizeOf(context).width < 380 ? 108 : 128,
        onBack: () => Get.back(),
        bottom: key == null ? null : _historyButton(tone),
      );

  Widget _list(ListingTone tone) {
    final me = _plans.myPlan.value;
    final loading = _plans.isLoadingPlan.value;
    final catalogLoading = _plans.isLoadingCatalog.value;
    final paidPlans = _plans.plans.where((p) => !p.isDefault && p.prices.isNotEmpty).toList();
    final accent = PlanAccent.of(me.featureKey);
    final barVisible = me.featureKey != null && me.paymentEnabled && paidPlans.isNotEmpty;
    final List<Widget> children;
    var settled = true;
    if (me.featureKey == null && !loading && _plans.planLoadFailed.value) {
      children = [_loadFailedState(tone)];
    } else if (me.featureKey == null) {
      settled = !loading;
      children = loading ? _loadingBlocks() : [_emptyState(tone)];
    } else {
      children = [
        _currentPlanCard(me, tone),
        if (me.play != null)
          PlanSubscriptionCard(me: me, accent: accent, onResubscribe: () => _resubscribe(me, paidPlans)),
        if (!me.paymentEnabled)
          _comingSoon(me.featureKey, tone)
        else ...[
          if (paidPlans.isEmpty)
            _plansPlaceholder(catalogLoading, tone)
          else
            ..._purchaseSection(me, paidPlans, accent, tone),
          if (_plans.isPlay) _restoreButton(tone),
        ],
      ];
    }
    var i = 0;
    return StaggerHost(
      key: ValueKey(settled),
      count: 8,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.only(bottom: KitMetrics.sectionGap + (barVisible ? 0 : AppInsets.bottomViewPadding(context))),
        children: [
          _header(tone, me.featureKey),
          for (final w in children)
            if (!settled) w else StaggerItem(index: math.min(i++, 7), child: w),
        ],
      ),
    );
  }

  List<Widget> _loadingBlocks() => const [PlanSkeleton3D()];

  List<Widget> _purchaseSection(MyPlanModel me, List<PlanModel> paidPlans, Color accent, ListingTone tone) {
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
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PlanSectionTitle(title: 'What you get', subtitle: 'Free vs ${paidPlans.map((p) => p.name).join(' vs ')}'),
        PlanCompareTable(
          rows: _featureRows(_plans.plans, paidPlans, me),
          paidNames: [for (final p in paidPlans) p.name],
          accent: accent,
          featureKey: me.featureKey,
        ),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        owns
            ? const PlanSectionTitle(title: 'Change duration', subtitle: 'Takes effect at your next renewal')
            : PlanSectionTitle(title: 'Pick how long', subtitle: isPlay ? 'Auto-renews. Cancel anytime in Google Play.' : 'Prepaid. Pick how long.'),
        for (final plan in paidPlans) ...[
          if (paidPlans.length > 1) _planChipRow(plan, tone),
          ..._cycleRows(plan, accent, me.featureKey),
        ],
        if (otherAccount)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Text('Subscribed on another Bakhli account',
                style: TypeTokens.style(12.5, FontWeight.w500, color: TypeTokens.secondary)),
          ),
        if (showCoupon) _couponLink(tone),
      ]),
    ];
  }

  Widget _planChipRow(PlanModel plan, ListingTone tone) => PlanChoiceChip3D(
        tone: tone,
        label: plan.name,
        selected: _selectedPlanId.value == plan.id,
        onTap: () => _selectPlan(plan),
      );

  List<Widget> _cycleRows(PlanModel plan, Color accent, String? featureKey) {
    final isPlay = _plans.isPlay;
    final storeState = _plans.storeState.value;
    final selectedCycle = _cycles[plan.id] ?? plan.prices.first.cycleMonths;
    final isSelectedPlan = _selectedPlanId.value == plan.id;
    final saves = [for (final p in plan.prices) _savePercent(plan, p)];
    final maxSave = saves.isEmpty ? 0 : saves.reduce((a, b) => a > b ? a : b);
    final bestIndex = maxSave > 0 ? saves.indexOf(maxSave) : -1;
    return [
      for (var i = 0; i < plan.prices.length; i++)
        Builder(builder: (_) {
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
              index: i,
              featureKey: featureKey,
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
            index: i,
            featureKey: featureKey,
          );
        }),
    ];
  }

  Widget _couponLink(ListingTone tone) {
    if (!_showCoupon.value && _appliedCoupon.value == null) {
      return PlanLinkText(tone: tone, label: 'Have a coupon?', onTap: () => _showCoupon.value = true);
    }
    return _couponRow(tone);
  }

  Widget _comingSoon(String? featureKey, ListingTone tone) => PlanStateCard3D(
        tone: tone,
        art: ListingArt.star,
        title: 'Paid plans are coming',
        message: _comingLine(featureKey),
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
      right = PlanBar3D.placeholder;
    } else if (priceUnavailable) {
      right = PlanBar3D.price('Price unavailable', muted: true);
    } else if (quote != null && quote.isTrial) {
      right = PlanBar3D.price('Free for ${trialOffer?.trialDays ?? plan.trialDays} days', good: true);
    } else if (quote != null && !quote.requiresPayment) {
      right = PlanBar3D.price('₹0 today');
    } else if (quote != null && quote.storePriceRequired) {
      right = quoteSp != null ? PlanBar3D.price('${quoteSp.formatted} today') : const SizedBox.shrink();
    } else if (quote != null) {
      right = PlanBar3D.price('${BrowseItem.inr(quote.payableInr)} today');
    } else {
      right = fallbackPrice != null ? PlanBar3D.price(fallbackPrice) : const SizedBox.shrink();
    }

    String? note;
    var noteKind = PlanNoteKind.plain;
    if (quoteError != null) {
      note = quoteError;
      noteKind = PlanNoteKind.bad;
    } else if (holdBlocked) {
      note = 'Fix the payment in Google Play first.';
      noteKind = PlanNoteKind.warn;
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
        noteKind = PlanNoteKind.good;
      }
    }

    final label = quoteLoading && quote == null && !ownedCycle && !notConfigured
        ? 'Continue with ${plan.name}'
        : _ctaLabel(plan, me, selected, quote, ownedCycle: ownedCycle, notConfigured: notConfigured);

    final tone = PlanLook.toneOf(me.featureKey);
    final trialDays = isPlay ? (trialOffer?.trialDays ?? plan.trialDays) : plan.trialDays;
    final monthly = isPlay ? _plans.storePriceFor(plan, 1) : null;
    return PlanBar3D(
      tone: tone,
      left: '${plan.name} · ${_cycleTitle(cycle)}',
      right: right,
      note: note,
      noteKind: noteKind,
      ctaLabel: label,
      ctaLoading: purchasing && selected,
      onCta: ctaDisabled ? null : () => _onCta(plan, selected),
      trialLabel: canTrial ? 'Try free for $trialDays days' : null,
      onTrial: purchasing ? null : () => _startTrial(plan),
      trialNote: canTrial && monthly != null ? 'Then ${monthly.formatted}/month. Cancel anytime in Google Play.' : null,
    );
  }

  Widget _restoreButton(ListingTone tone) {
    final busy = _plans.isRestoring.value || _plans.isPurchasing.value;
    return PlanLinkText(
      tone: tone,
      secondary: true,
      label: _plans.isRestoring.value ? 'Restoring...' : 'Restore purchases',
      onTap: busy ? null : () => _plans.restorePurchases(force: true, userInitiated: true),
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

  Widget _historyButton(ListingTone tone) => PlanHistoryPill(
        tone: tone,
        art: TravelIcon.calendar,
        onTap: () => Get.toNamed(AppRoutes.planHistory),
      );

  Widget _emptyState(ListingTone tone) => PlanStateCard3D(
        tone: tone,
        art: ListingArt.luggage,
        title: 'No plans for you',
        message: 'Plans are for owners.',
      );

  Widget _loadFailedState(ListingTone tone) => PlanStateCard3D(
        tone: tone,
        art: ListingArt.worldMap,
        title: 'Could not load plan',
        message: 'Check your connection.',
        actionLabel: 'Retry',
        onAction: () => _load(force: true),
      );

  Widget _plansPlaceholder(bool loading, ListingTone tone) => loading
      ? const PlanSkeleton3D(hero: false, rows: 2)
      : PlanStateCard3D(tone: tone, art: ListingArt.star, title: 'No paid plans yet.');

  static String _date(DateTime d) => PlanStateCopy.date(d);

  Widget _currentPlanCard(MyPlanModel me, ListingTone tone) {
    final l = me.limits;
    final key = me.featureKey;
    final subtitle = me.play?.ownsActivePlan == true
        ? 'Billed by Google Play'
        : me.hasPaidPlan && me.endsAt != null
            ? 'Ends ${_date(me.endsAt!)}${me.daysLeft != null ? ' · ${me.daysLeft} days left' : ''}'
            : (me.paymentEnabled ? 'No end date' : 'Free for now');
    return PlanHeroCard3D(
      tone: tone,
      art: PlanAccent.iconAsset(key),
      pills: [
        if (me.isTrial || (me.play?.inTrial ?? false)) const PlanHeroPill('Trial'),
        me.hasPaidPlan ? const PlanHeroPill('Active', filled: true) : const PlanHeroPill('Your plan'),
      ],
      name: me.planName,
      subtitle: subtitle,
      lines: _includedLines(l, key),
      pausedLabel: me.pausedByPlanCount > 0 ? '${me.pausedByPlanCount} paused by plan' : null,
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
    return switch (quote.intent) {
      'Renew' => 'Renew',
      'Switch' => 'Switch',
      _ => resub ? 'Resubscribe' : 'Continue with ${plan.name}',
    };
  }

  Widget _couponRow(ListingTone tone) {
    final applied = _appliedCoupon.value;
    return PlanCouponRow3D(
      tone: tone,
      art: ListingArt.moneyBag,
      applied: applied != null,
      onTap: applied == null ? _applyCoupon : _clearCoupon,
      field: TextField(
        controller: _couponCtrl,
        enabled: applied == null,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: noEmojiInputFormatters,
        style: PlanCouponRow3D.fieldStyle(applied != null),
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          contentPadding: EdgeInsets.zero,
          hintText: 'Coupon code',
          hintStyle: PlanCouponRow3D.hintStyle(),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        onSubmitted: (_) => _applyCoupon(),
      ),
    );
  }
}
