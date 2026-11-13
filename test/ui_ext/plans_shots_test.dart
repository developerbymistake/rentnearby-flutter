import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/plan_model.dart';
import 'package:bakhli/models/plan_purchase_result.dart';
import 'package:bakhli/models/store_product.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';
import 'package:bakhli/screens/plan_history_screen.dart';
import 'package:bakhli/screens/plans_billing_screen.dart';
import 'package:bakhli/screens/privacy_policy_screen.dart';
import 'package:bakhli/screens/terms_of_service_screen.dart';
import 'package:bakhli/widgets/plan_compare_table.dart';
import 'package:bakhli/widgets/plan_subscription_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

typedef QuoteFn = Future<QuoteResult> Function(String planId, int cycle, String? coupon);

class _Plans extends PlanController {
  _Plans({required this.play, required this.quoteFn, this.prices = const {}, this.trial});

  final bool play;
  final QuoteFn quoteFn;
  final Map<String, StorePrice> prices;
  final StoreOffer? trial;
  int restoreCalls = 0;

  @override
  Future<void> refreshPlan({bool force = false}) async {}
  @override
  Future<void> loadCatalog({bool force = false}) async {}
  @override
  Future<void> loadHistory() async {}
  @override
  Future<void> loadStore({bool force = false}) async {}
  @override
  Future<void> restorePurchases({bool force = false, bool userInitiated = false}) async => restoreCalls++;
  @override
  bool get isPlay => play;
  @override
  Future<QuoteResult> quote(String planId, int cycleMonths, String? couponCode, {bool useTrial = false}) =>
      quoteFn(planId, cycleMonths, couponCode);
  @override
  StorePrice? storePriceFor(PlanModel plan, int cycleMonths) => prices['${plan.id}:$cycleMonths'];
  @override
  StoreOffer? trialOfferFor(PlanModel plan) => trial;
}

StorePrice _sp(String f, double raw) => StorePrice(formatted: f, raw: raw, currencyCode: 'INR', billingPeriod: 'P1M');

PlanModel _free(String key) => PlanModel(
      id: '${key}_free',
      featureKey: key,
      code: 'FREE',
      name: 'Free',
      tagline: null,
      isDefault: true,
      trialDays: 0,
      features: key == 'Stay' ? const {PlanFeatureKeys.jobsPosts: 1} : const {},
      prices: const [],
    );

PlanModel _paid(String key, String id, String name, List<int> rupees, {Map<String, int>? f, Set<int> noBase = const {}}) => PlanModel(
      id: id,
      featureKey: key,
      code: id,
      name: name,
      tagline: null,
      isDefault: false,
      trialDays: 7,
      features: f ??
          (key == 'Stay'
              ? const {PlanFeatureKeys.priority: 1, PlanFeatureKeys.featured: 1, PlanFeatureKeys.jobsPosts: 5}
              : const {PlanFeatureKeys.priority: 1, PlanFeatureKeys.featured: 1}),
      prices: [
        for (final (i, m) in [1, 3, 12].indexed)
          PlanPriceModel(
            cycleMonths: m,
            priceInr: rupees[i],
            perMonthInr: (rupees[i] / m).round(),
            savePercent: [0, 11, 16][i],
            playBasePlanId: noBase.contains(m) ? null : 'p$m',
            playTrialOfferId: m == 1 ? 'trial' : null,
          ),
      ],
      playProductId: 'prod_$id',
    );

final _stayPlus = _paid('Stay', 'sp', 'Stay Plus', [299, 799, 2999]);
final _stayPro = _paid('Stay', 'spro', 'Stay Pro', [499, 1349, 4999],
    f: const {PlanFeatureKeys.priority: 1, PlanFeatureKeys.featured: 1, PlanFeatureKeys.jobsPosts: 10});
final _taxiPlus = _paid('Taxi', 'tp', 'Taxi Plus', [199, 549, 1999]);

Map<String, StorePrice> _store(PlanModel p, List<int> r) => {
      '${p.id}:1': _sp('₹${r[0]}', r[0].toDouble()),
      '${p.id}:3': _sp('₹${r[1]}', r[1].toDouble()),
      '${p.id}:12': _sp(r[2] >= 1000 ? '₹${r[2] ~/ 1000},${(r[2] % 1000).toString().padLeft(3, '0')}' : '₹${r[2]}', r[2].toDouble()),
    };

PlanQuote _q(PlanModel p, int cycle,
        {String intent = 'New', int list = 0, int discount = 0, int credit = 0, int? pay, bool requires = true, String? coupon, bool trial = false, bool store = true, String? mode}) =>
    PlanQuote(
      planId: p.id,
      planName: p.name,
      cycleMonths: cycle,
      intent: intent,
      listPriceInr: list,
      discountInr: discount,
      creditInr: credit,
      payableInr: pay ?? list,
      grantedDays: 30 * cycle,
      requiresPayment: requires,
      couponCode: coupon,
      autoCoupon: false,
      provider: store ? 'Play' : 'Razorpay',
      isTrial: trial,
      playReplacementMode: mode,
      storePriceRequired: store,
    );

PlaySubInfo _playSub({
  String state = 'SUBSCRIPTION_STATE_ACTIVE',
  bool auto = true,
  bool owns = true,
  String product = 'prod_sp',
  String base = 'p1',
  DateTime? trialEnds,
  String? scheduled,
  bool test = false,
  DateTime? resume,
}) =>
    PlaySubInfo(
      state: state,
      autoRenewEnabled: auto,
      expiryAt: DateTime(2026, 12, 12),
      trialEndsAt: trialEnds,
      productId: product,
      basePlanId: base,
      offerId: null,
      scheduledPlanName: scheduled,
      scheduledAt: scheduled == null ? null : DateTime(2026, 12, 12),
      isTest: test,
      acknowledged: true,
      pausedAutoResumeAt: resume,
      cancelReason: null,
      ownsActivePlan: owns,
    );

const _stayLimits = PlanLimitsModel(jobsPosts: 1);

_Plans _install({
  required MyPlanModel me,
  List<PlanModel> plans = const [],
  bool play = true,
  QuoteFn? quote,
  Map<String, StorePrice> prices = const {},
  StoreOffer? trial,
  StoreState store = StoreState.ready,
  bool catalog = true,
}) {
  Get.reset();
  final c = _Plans(
    play: play,
    quoteFn: quote ?? (id, cycle, _) async => QuoteSuccess(_q(plans.firstWhere((p) => p.id == id), cycle, list: 0)),
    prices: prices,
    trial: trial,
  );
  Get.put<PlanController>(c);
  c.myPlan.value = me;
  if (catalog) {
    final key = me.featureKey ?? 'Stay';
    c.catalog.value = PlanCatalogModel({key: [_free(key), ...plans]}, paymentProvider: play ? 'Play' : 'Razorpay');
  }
  c.storeState.value = store;
  return c;
}

final _trialOffer = StoreOffer(productId: 'prod_sp', basePlanId: 'p1', offerId: 'trial', offerToken: 't', price: _sp('₹0', 0), isTrial: true, trialDays: 7);

MyPlanModel _stayFree({bool payment = true, bool trial = true, int paused = 0, PlaySubInfo? play}) => MyPlanModel(
      paymentEnabled: payment,
      featureKey: 'Stay',
      planName: 'Free',
      limits: _stayLimits,
      trialAvailable: trial,
      pausedByPlanCount: paused,
      play: play,
    );

final _configs = <(String, double, double)>[('360_10', 360, 1.0), ('360_13', 360, 1.3), ('300_10', 300, 1.0)];

Future<void> _pump(WidgetTester t, Widget page, {double w = 360, double s = 1.0, double h = 800}) async {
  shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\plans';
  debugDisableShadows = false;
  await pumpPhone(t, page, size: Size(w, h), devicePixelRatio: 1.5, textScale: s);
  await settlePhone(t);
  await t.pump(const Duration(milliseconds: 600));
  await settlePhone(t);
}

Future<void> _snap(WidgetTester t, String name) async {
  await settlePhone(t);
  await shot(t, name);
  final e = t.takeException();
  debugDisableShadows = true;
  expect(e, isNull);
}

Future<void> _scrollTo(WidgetTester t, double y) async {
  final st = t.state<ScrollableState>(find.byType(Scrollable).first);
  st.position.jumpTo(y.clamp(st.position.minScrollExtent, st.position.maxScrollExtent));
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> _tapText(WidgetTester t, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await t.scrollUntilVisible(find.text(text), 200, scrollable: find.byType(Scrollable).first, maxScrolls: 60);
  }
  final f = find.text(text).first;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f, warnIfMissed: false);
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  tearDown(Get.reset);

  final stayPrices = _store(_stayPlus, [299, 799, 2999]);
  QuoteFn stayQuote({bool trialPick = false}) => (id, cycle, coupon) async {
        if (trialPick && cycle == 1) return QuoteSuccess(_q(_stayPlus, 1, trial: true, requires: false));
        return QuoteSuccess(_q(_stayPlus, cycle, list: [0, 299, 0, 799][cycle == 12 ? 0 : cycle]));
      };

  Future<void> mainState(WidgetTester t, {double w = 360, double s = 1.0}) async {
    _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: stayQuote());
    await _pump(t, const PlansBillingScreen(), w: w, s: s);
    await _tapText(t, '3 months');
    await _scrollTo(t, 0);
  }

  for (final (tag, w, s) in _configs) {
    testWidgets('p_main $tag', (t) async {
      await mainState(t, w: w, s: s);
      await _snap(t, 'p_main_$tag');
      debugDisableShadows = false;
      await _scrollTo(t, 700);
      await _snap(t, 'p_main_s_$tag');
      debugDisableShadows = false;
      await _scrollTo(t, 99999);
      await _snap(t, 'p_main_end_$tag');
    });
  }

  testWidgets('p_main at mock size 390x844', (t) async {
    _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: stayQuote());
    await _pump(t, const PlansBillingScreen(), w: 390, h: 816);
    await _tapText(t, '3 months');
    await _scrollTo(t, 0);
    await _snap(t, 'p_main_390');
  });

  testWidgets('p_main taps reach callbacks', (t) async {
    final c = _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: stayQuote());
    await _pump(t, const PlansBillingScreen());
    await _tapText(t, '12 months');
    expect(find.text('Stay Plus · 12 months'), findsOneWidget);
    await _tapText(t, 'Restore purchases');
    expect(c.restoreCalls, 1);
    await _tapText(t, 'Have a coupon?');
    expect(find.text('Coupon code'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    debugDisableShadows = true;
  });

  testWidgets('p_trialq', (t) async {
    _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: stayQuote(trialPick: true));
    await _pump(t, const PlansBillingScreen());
    await _scrollTo(t, 700);
    await _snap(t, 'p_trialq');
  });

  testWidgets('p_quote_load', (t) async {
    final never = Completer<QuoteResult>();
    _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: (_, _, _) => never.future);
    await _pump(t, const PlansBillingScreen());
    await _scrollTo(t, 700);
    await _snap(t, 'p_quote_load');
  });

  testWidgets('p_quote_err', (t) async {
    _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: (_, _, _) async => QuoteFailure('Could not get price. Try again.'));
    await _pump(t, const PlansBillingScreen());
    await _scrollTo(t, 700);
    await _snap(t, 'p_quote_err');
  });

  testWidgets('p_coupon', (t) async {
    _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: stayQuote());
    await _pump(t, const PlansBillingScreen());
    await _tapText(t, 'Have a coupon?');
    await _scrollTo(t, 99999);
    await _snap(t, 'p_coupon');
  });

  testWidgets('p_coupon_ok (prepaid)', (t) async {
    _install(
      me: _stayFree(trial: false).copyWithProvider('Razorpay'),
      plans: [_stayPlus],
      play: false,
      quote: (id, cycle, coupon) async => QuoteSuccess(coupon == null
          ? _q(_stayPlus, cycle, list: 799, store: false)
          : _q(_stayPlus, cycle, list: 799, discount: 50, pay: 749, coupon: coupon, store: false)),
    );
    await _pump(t, const PlansBillingScreen());
    await _tapText(t, '3 months');
    await _tapText(t, 'Have a coupon?');
    await t.enterText(find.byType(TextField), 'welcome50');
    await _tapText(t, 'Apply');
    await settlePhone(t);
    await _scrollTo(t, 99999);
    await _snap(t, 'p_coupon_ok');
  });

  final taxiPrices = _store(_taxiPlus, [199, 549, 1999]);
  MyPlanModel taxiActive({String base = 'p1'}) => MyPlanModel(
        paymentEnabled: true,
        featureKey: 'Taxi',
        planName: 'Taxi Plus',
        isDefault: false,
        isPaid: true,
        limits: const PlanLimitsModel(priority: 1, featured: true),
        play: _playSub(product: 'prod_tp', base: base, scheduled: 'Taxi Plus'),
      );

  for (final (tag, w, s) in _configs) {
    testWidgets('p_active $tag', (t) async {
      _install(
        me: taxiActive(),
        plans: [_taxiPlus],
        prices: taxiPrices,
        quote: (id, cycle, _) async => QuoteSuccess(_q(_taxiPlus, cycle, intent: 'Switch', mode: cycle == 12 ? 'withoutProration' : 'deferred')),
      );
      await _pump(t, const PlansBillingScreen(), w: w, s: s);
      await _snap(t, 'p_owned_top_$tag');
      debugDisableShadows = false;
      await _tapText(t, '3 months');
      await _scrollTo(t, 0);
      await _snap(t, 'p_active_$tag');
      debugDisableShadows = false;
      await _scrollTo(t, 870);
      await _snap(t, 'p_active_s_$tag');
    });
  }

  testWidgets('p_owned + p_gadjust', (t) async {
    _install(
      me: taxiActive(),
      plans: [_taxiPlus],
      prices: taxiPrices,
      quote: (id, cycle, _) async => QuoteSuccess(_q(_taxiPlus, cycle, intent: 'Switch', mode: 'withoutProration')),
    );
    await _pump(t, const PlansBillingScreen());
    await _scrollTo(t, 930);
    await _snap(t, 'p_owned');
    debugDisableShadows = false;
    await _tapText(t, '12 months');
    await _scrollTo(t, 870);
    await _snap(t, 'p_gadjust');
  });

  testWidgets('p_store_load', (t) async {
    _install(me: _stayFree(), plans: [_stayPlus], quote: stayQuote(), store: StoreState.loading);
    await _pump(t, const PlansBillingScreen());
    await _scrollTo(t, 700);
    await _snap(t, 'p_store_load');
  });

  testWidgets('p_unavail', (t) async {
    final plan = _paid('Stay', 'sp', 'Stay Plus', [299, 799, 2999], noBase: {3, 12});
    final c = _install(me: _stayFree(), plans: [plan], quote: stayQuote());
    c.otherAccountProducts.add('prod_sp');
    await _pump(t, const PlansBillingScreen());
    await _scrollTo(t, 700);
    await _snap(t, 'p_unavail');
  });

  testWidgets('p_notcfg', (t) async {
    final plan = _paid('Stay', 'sp', 'Stay Plus', [299, 799, 2999], noBase: {3});
    _install(me: _stayFree(), plans: [plan], prices: stayPrices, quote: stayQuote());
    await _pump(t, const PlansBillingScreen());
    await _tapText(t, '3 months');
    await _scrollTo(t, 700);
    await _snap(t, 'p_notcfg');
  });

  testWidgets('p_hold', (t) async {
    _install(
      me: _stayFree(trial: false, play: _playSub(state: 'SUBSCRIPTION_STATE_ON_HOLD', owns: false)),
      plans: [_stayPlus],
      prices: stayPrices,
      quote: stayQuote(),
    );
    await _pump(t, const PlansBillingScreen());
    await _tapText(t, '3 months');
    await _scrollTo(t, 250);
    await _snap(t, 'p_hold');
  });

  testWidgets('p_renew (prepaid)', (t) async {
    _install(
      me: const MyPlanModel(
        paymentEnabled: true,
        featureKey: 'Stay',
        planName: 'Stay Plus',
        isDefault: false,
        isPaid: true,
        paymentProvider: 'Razorpay',
        daysLeft: 92,
        limits: PlanLimitsModel(priority: 1, featured: true, jobsPosts: 5),
      ).withEnds(DateTime(2027, 2, 12)),
      plans: [_stayPlus],
      play: false,
      quote: (id, cycle, _) async => QuoteSuccess(_q(_stayPlus, cycle, intent: 'Renew', list: 799, discount: 100, pay: 699, store: false)),
    );
    await _pump(t, const PlansBillingScreen());
    await _snap(t, 'p_renew_top');
    debugDisableShadows = false;
    await _tapText(t, '3 months');
    await _scrollTo(t, 700);
    await _snap(t, 'p_renew');
  });

  testWidgets('p_activate (free coupon)', (t) async {
    _install(
      me: _stayFree(trial: false),
      plans: [_stayPlus],
      play: false,
      quote: (id, cycle, coupon) async => QuoteSuccess(coupon == null
          ? _q(_stayPlus, cycle, list: 799, store: false)
          : _q(_stayPlus, cycle, list: 799, discount: 799, pay: 0, requires: false, coupon: 'FREE100', store: false)),
    );
    await _pump(t, const PlansBillingScreen());
    await _tapText(t, '3 months');
    await _tapText(t, 'Have a coupon?');
    await t.enterText(find.byType(TextField), 'free100');
    await _tapText(t, 'Apply');
    await settlePhone(t);
    await _scrollTo(t, 99999);
    await _snap(t, 'p_activate');
  });

  testWidgets('p_resub', (t) async {
    _install(
      me: _stayFree(trial: false, paused: 2, play: _playSub(state: 'SUBSCRIPTION_STATE_EXPIRED', owns: false)),
      plans: [_stayPlus],
      prices: stayPrices,
      quote: stayQuote(),
    );
    await _pump(t, const PlansBillingScreen());
    await _snap(t, 'p_resub_top');
    debugDisableShadows = false;
    await _scrollTo(t, 150);
    await _snap(t, 'p_resub');
  });

  testWidgets('p_multi', (t) async {
    _install(me: _stayFree(trial: false), plans: [_stayPlus, _stayPro], prices: {...stayPrices, ..._store(_stayPro, [499, 1349, 4999])}, quote: stayQuote());
    await _pump(t, const PlansBillingScreen());
    await _scrollTo(t, 500);
    await _snap(t, 'p_multi');
    debugDisableShadows = false;
    await _scrollTo(t, 99999);
    await _snap(t, 'p_multi_end');
  });

  testWidgets('p_switch_pre', (t) async {
    _install(
      me: const MyPlanModel(
        paymentEnabled: true,
        featureKey: 'Stay',
        planName: 'Stay Plus',
        isDefault: false,
        isPaid: true,
        paymentProvider: 'Razorpay',
        daysLeft: 92,
        limits: PlanLimitsModel(priority: 1, featured: true, jobsPosts: 5),
      ).withEnds(DateTime(2027, 2, 12)),
      plans: [_stayPlus, _stayPro],
      play: false,
      quote: (id, cycle, _) async => QuoteSuccess(id == 'spro'
          ? _q(_stayPro, cycle, intent: 'Switch', list: 1349, credit: 120, pay: 1229, store: false)
          : _q(_stayPlus, cycle, intent: 'Renew', list: 799, store: false)),
    );
    await _pump(t, const PlansBillingScreen());
    await _tapText(t, 'Stay Pro');
    await _scrollTo(t, 1240);
    await _snap(t, 'p_switch_pre');
  });

  for (final (name, me) in [
    ('p_off', _stayFree(payment: false)),
    ('p_off_taxi', const MyPlanModel(featureKey: 'Taxi', planName: 'Free')),
  ]) {
    testWidgets(name, (t) async {
      _install(me: me, plans: me.featureKey == 'Taxi' ? [_taxiPlus] : [_stayPlus], quote: stayQuote());
      await _pump(t, const PlansBillingScreen());
      await _snap(t, name);
    });
  }

  for (final (tag, w, s) in _configs) {
    testWidgets('p_nopaid $tag', (t) async {
      _install(me: _stayFree(), plans: const [], quote: stayQuote());
      await _pump(t, const PlansBillingScreen(), w: w, s: s);
      await _snap(t, 'p_nopaid_$tag');
    });
  }

  testWidgets('p_loading', (t) async {
    final c = _install(me: const MyPlanModel(), catalog: false);
    Get.put<AuthController>(_Auth()).canListStays.value = true;
    c.isLoadingPlan.value = true;
    await _pump(t, const PlansBillingScreen());
    await _snap(t, 'p_loading');
  });

  for (final (tag, w, s) in _configs) {
    testWidgets('p_error $tag', (t) async {
      final c = _install(me: const MyPlanModel(), catalog: false);
      Get.put<AuthController>(_Auth()).canListStays.value = true;
      c.planLoadFailed.value = true;
      await _pump(t, const PlansBillingScreen(), w: w, s: s);
      await _snap(t, 'p_error_$tag');
    });
  }

  testWidgets('p_empty', (t) async {
    _install(me: const MyPlanModel(), catalog: false);
    await _pump(t, const PlansBillingScreen());
    await _snap(t, 'p_empty');
  });

  Widget cards(List<MyPlanModel> list) => Scaffold(
        backgroundColor: ListingPalette.forest.page,
        body: ListView(padding: const EdgeInsets.only(top: 20, bottom: 40), children: [
          for (final me in list) PlanSubscriptionCard(me: me, accent: PlanAccent.of('Stay'), onResubscribe: () {}),
        ]),
      );
  MyPlanModel paidStay(PlaySubInfo p, {int carry = 0}) =>
      MyPlanModel(paymentEnabled: true, featureKey: 'Stay', planName: 'Stay Plus', isDefault: false, isPaid: true, carryOverDays: carry, play: p);

  final subCases = <String, List<MyPlanModel>>{
    'sc_a': [paidStay(_playSub(scheduled: 'Stay Plus')), paidStay(_playSub(auto: false), carry: 12)],
    'sc_b': [
      paidStay(_playSub(trialEnds: DateTime.now().add(const Duration(days: 6)))),
      _stayFree(play: _playSub(state: 'SUBSCRIPTION_STATE_EXPIRED', owns: false)),
    ],
    'sc_c': [
      paidStay(_playSub(state: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD')),
      _stayFree(play: _playSub(state: 'SUBSCRIPTION_STATE_ON_HOLD', owns: false)),
    ],
    'sc_d': [
      _stayFree(play: _playSub(state: 'SUBSCRIPTION_STATE_PAUSED', owns: false, test: true, resume: DateTime(2027, 1, 2))),
      _stayFree(play: _playSub(state: 'SUBSCRIPTION_STATE_PAUSED', owns: false)),
    ],
    'sc_e': [
      paidStay(_playSub(auto: false)).withoutExpiry(),
      paidStay(_playSub()).withoutExpiry(),
    ],
  };
  for (final e in subCases.entries) {
    for (final (tag, w, s) in e.key == 'sc_a' || e.key == 'sc_c' ? _configs : [_configs.first]) {
      testWidgets('${e.key} $tag', (t) async {
        _install(me: _stayFree(), plans: [_stayPlus]);
        await _pump(t, cards(e.value), w: w, s: s);
        await _snap(t, '${e.key}_$tag');
      });
    }
  }

  testWidgets('subscription card taps', (t) async {
    var resub = 0;
    _install(me: _stayFree(), plans: [_stayPlus]);
    await _pump(
        t,
        Scaffold(
            body: ListView(children: [
          PlanSubscriptionCard(
              me: _stayFree(play: _playSub(state: 'SUBSCRIPTION_STATE_EXPIRED', owns: false)),
              accent: PlanAccent.of('Stay'),
              onResubscribe: () => resub++),
        ])));
    await _tapText(t, 'Resubscribe');
    expect(resub, 1);
    expect(find.text('Manage in Google Play'), findsOneWidget);
    expect(find.text('Use the Google account you subscribed with.'), findsOneWidget);
    debugDisableShadows = true;
  });

  final sheets = <String, (PurchaseStatus, bool)>{
    's_checking': (_ps('Created'), false),
    's_confirming': (_ps('Pending'), false),
    's_play': (_ps('PlayPending'), false),
    's_restoring': (_ps('Restoring'), false),
    's_activating': (_ps('Paid'), false),
    's_active': (_ps('Granted', ends: DateTime(2027, 2, 12)), false),
    's_active2': (_ps('Granted'), false),
    's_verify': (_ps('VerifyFailed'), false),
    's_failed': (_ps('Failed'), false),
    's_expired': (_ps('Expired'), false),
    's_refunded': (_ps('Refunded'), false),
    's_store': (_ps('StoreUnavailable'), false),
    's_other': (_ps('OtherAccount'), false),
    's_detached': (_ps('Detached', ends: DateTime(2026, 12, 12)), false),
    's_detached2': (_ps('Detached'), false),
    's_nopay': (_ps('Created'), true),
    's_almost': (_ps('Pending'), true),
    's_blocked': (_ps('Paid', blocked: 'AmountMismatch'), false),
    's_blocked2': (_ps('Paid', blocked: 'Other'), false),
  };
  for (final e in sheets.entries) {
    final cfgs = e.key == 's_checking' || e.key == 's_active' || e.key == 's_other' ? _configs : [_configs.first];
    for (final (tag, w, s) in cfgs) {
      testWidgets('${e.key} $tag', (t) async {
        final c = _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: stayQuote());
        c.activePurchase.value = e.value.$1;
        c.pollTimedOut.value = e.value.$2;
        await _pump(t, const PlansBillingScreen(), w: w, s: s);
        await _snap(t, '${e.key}_$tag');
      });
    }
  }

  testWidgets('s_close', (t) async {
    _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: stayQuote());
    final tone = PlanLook.toneOf('Stay');
    await _pump(
      t,
      Scaffold(
        backgroundColor: PlanLook.pageOf('Stay'),
        body: Align(alignment: Alignment.bottomCenter, child: PlanCloseSheet3D(tone: tone, onClose: () {})),
      ),
    );
    await _snap(t, 's_close');
  });

  testWidgets('sheet Done pops and dismisses', (t) async {
    final c = _install(me: _stayFree(), plans: [_stayPlus], prices: stayPrices, trial: _trialOffer, quote: stayQuote());
    c.activePurchase.value = _ps('Failed');
    await _pump(t, const PlansBillingScreen());
    expect(find.text('Payment failed'), findsOneWidget);
    await t.tap(find.text('Done'));
    await settlePhone(t);
    expect(find.text('Payment failed'), findsNothing);
    expect(c.activePurchase.value, isNull);
    debugDisableShadows = true;
  });

  PurchaseHistoryItem h(String s, int m, int pay, DateTime d) =>
      PurchaseHistoryItem(id: s, planName: 'Stay Plus', cycleMonths: m, payableInr: pay, status: s, createdAt: d, grantedAt: null);
  for (final (tag, w, s) in _configs) {
    testWidgets('h_list $tag', (t) async {
      final c = _install(me: _stayFree(), plans: [_stayPlus]);
      c.history.assignAll([
        h('Granted', 3, 799, DateTime(2026, 11, 12)),
        h('Paid', 12, 2999, DateTime(2026, 11, 10)),
        h('Created', 1, 299, DateTime(2026, 11, 9)),
        h('Refunded', 1, 299, DateTime(2026, 10, 2)),
        h('Failed', 3, 799, DateTime(2026, 9, 28)),
        h('Expired', 1, 299, DateTime(2026, 9, 20)),
      ]);
      await _pump(t, const PlanHistoryScreen(), w: w, s: s);
      await _snap(t, 'h_list_$tag');
      debugDisableShadows = false;
      await _scrollTo(t, 99999);
      await _snap(t, 'h_list_end_$tag');
    });
  }
  for (final name in ['h_empty', 'h_error', 'h_loading']) {
    testWidgets(name, (t) async {
      final c = _install(me: _stayFree(), plans: [_stayPlus]);
      if (name == 'h_error') c.historyLoadFailed.value = true;
      if (name == 'h_loading') c.isLoadingHistory.value = true;
      await _pump(t, const PlanHistoryScreen());
      await _snap(t, name);
    });
  }

  for (final (tag, w, s) in _configs) {
    testWidgets('legal $tag', (t) async {
      await _pump(t, const PrivacyPolicyScreen(), w: w, s: s);
      await _snap(t, 'lp_top_$tag');
      debugDisableShadows = false;
      await _scrollTo(t, 520);
      await _snap(t, 'lp_mid_$tag');
      debugDisableShadows = false;
      await _scrollTo(t, 99999);
      await _snap(t, 'lp_end_$tag');
      await _pump(t, const TermsOfServiceScreen(), w: w, s: s);
      await _snap(t, 'tos_top_$tag');
      debugDisableShadows = false;
      final f = find.text('Plans and Subscriptions');
      await t.ensureVisible(f);
      await t.pump(const Duration(milliseconds: 200));
      await _snap(t, 'tos_plans_$tag');
      debugDisableShadows = false;
      await _scrollTo(t, 99999);
      await _snap(t, 'tos_end_$tag');
    });
  }
}

PurchaseStatus _ps(String status, {DateTime? ends, String? blocked}) => PurchaseStatus(
      purchaseId: 'x',
      status: status,
      planName: 'Stay Plus',
      grantedDays: 90,
      endsAt: ends,
      failureReason: null,
      grantBlockedReason: blocked,
      provider: 'Play',
    );

extension on MyPlanModel {
  MyPlanModel copyWithProvider(String p) => MyPlanModel(
        paymentEnabled: paymentEnabled,
        featureKey: featureKey,
        planName: planName,
        isDefault: isDefault,
        isPaid: isPaid,
        limits: limits,
        trialAvailable: trialAvailable,
        pausedByPlanCount: pausedByPlanCount,
        paymentProvider: p,
        play: play,
      );
  MyPlanModel withEnds(DateTime d) => MyPlanModel(
        paymentEnabled: paymentEnabled,
        featureKey: featureKey,
        planName: planName,
        isDefault: isDefault,
        isPaid: isPaid,
        limits: limits,
        daysLeft: daysLeft,
        endsAt: d,
        paymentProvider: paymentProvider,
        play: play,
      );
  MyPlanModel withoutExpiry() {
    final p = play!;
    return MyPlanModel(
      paymentEnabled: paymentEnabled,
      featureKey: featureKey,
      planName: planName,
      isDefault: isDefault,
      isPaid: isPaid,
      play: PlaySubInfo(
        state: p.state,
        autoRenewEnabled: p.autoRenewEnabled,
        expiryAt: null,
        trialEndsAt: null,
        productId: p.productId,
        basePlanId: p.basePlanId,
        offerId: null,
        scheduledPlanName: null,
        scheduledAt: null,
        isTest: false,
        acknowledged: true,
        pausedAutoResumeAt: null,
        cancelReason: null,
        ownsActivePlan: p.ownsActivePlan,
      ),
    );
  }
}
