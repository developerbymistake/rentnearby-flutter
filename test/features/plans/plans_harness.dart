import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/plan/stay_plan_copy.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_copy.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/plan_model.dart';
import 'package:bakhli/models/plan_purchase_result.dart';
import 'package:bakhli/models/store_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_render.dart';
import '../../support/real_phone.dart';

class FakePlans extends PlanController {
  FakePlans({this.prices = const {}, this.trial});

  final Map<String, StorePrice> prices;
  final StoreOffer? trial;
  int manageCalls = 0;
  final List<(String, int, bool)> purchases = [];

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> refreshPlan({bool force = false}) async {}
  @override
  Future<void> loadCatalog({bool force = false}) async {}
  @override
  Future<void> loadHistory() async {}
  @override
  Future<void> loadStore({bool force = false}) async {}
  @override
  Future<void> restorePurchases({bool force = false, bool userInitiated = false}) async {}
  @override
  bool get isPlay => true;
  @override
  Future<void> openManageSubscription() async => manageCalls++;
  @override
  Future<QuoteResult> quote(String planId, int cycleMonths, String? couponCode, {bool useTrial = false}) async => QuoteSuccess(PlanQuote(
        planId: planId,
        planName: 'Plus',
        cycleMonths: cycleMonths,
        intent: 'New',
        listPriceInr: 0,
        discountInr: 0,
        creditInr: 0,
        payableInr: 0,
        grantedDays: 30 * cycleMonths,
        requiresPayment: true,
        couponCode: null,
        autoCoupon: false,
        provider: 'Play',
        isTrial: false,
        playReplacementMode: null,
        storePriceRequired: true,
      ));
  @override
  StorePrice? storePriceFor(PlanModel plan, int cycleMonths) => prices['${plan.id}:$cycleMonths'];
  @override
  StoreOffer? trialOfferFor(PlanModel plan) => trial;
}

StorePrice sp(String f, double raw) => StorePrice(formatted: f, raw: raw, currencyCode: 'INR', billingPeriod: 'P1M');

const taxiFreeFeatures = {
  'ListingLimit': 1,
  'Routes': 1,
  'RingWeight': 1,
  'UpcomingDays': 15,
  'MonthsAhead': 0,
  'CalendarEntries': 4,
  'Reminders': 0,
  'MonthSummary': 0,
  'Featured': 0,
  'Priority': 0,
};
const taxiPlusFeatures = {
  'ListingLimit': 1,
  'Routes': 5,
  'RingWeight': 2,
  'UpcomingDays': 183,
  'MonthsAhead': 6,
  'CalendarEntries': 50,
  'Reminders': 1,
  'MonthSummary': 1,
  'Featured': 1,
  'Priority': 1,
};
const stayFreeFeatures = {
  'ListingLimit': 1,
  'Photos': 2,
  'RoomTypes': 2,
  'JobsPosts': 1,
  'UpcomingDays': 15,
  'MonthsAhead': 0,
  'CalendarEntries': 4,
  'BlockedRanges': 1,
  'Reminders': 0,
  'MonthSummary': 0,
  'SpecialPrices': 1,
  'Featured': 0,
  'Priority': 0,
};
const stayPlusFeatures = {
  'ListingLimit': 1,
  'Photos': 8,
  'RoomTypes': 6,
  'JobsPosts': 4,
  'UpcomingDays': 183,
  'MonthsAhead': 6,
  'CalendarEntries': 50,
  'BlockedRanges': 10,
  'Reminders': 1,
  'MonthSummary': 1,
  'SpecialPrices': 5,
  'Featured': 1,
  'Priority': 1,
};

PlanModel freePlan(String key) => PlanModel(
      id: '${key}_free',
      featureKey: key,
      code: 'FREE',
      name: 'Free',
      tagline: null,
      isDefault: true,
      trialDays: 0,
      features: key == 'Taxi' ? taxiFreeFeatures : stayFreeFeatures,
      prices: const [],
    );

PlanModel plusPlan(String key, {Map<String, int>? features, int trialDays = 7}) {
  final rupees = key == 'Taxi' ? [150, 400, 1400] : [400, 1100, 3800];
  return PlanModel(
    id: '${key}_plus',
    featureKey: key,
    code: 'PLUS',
    name: 'Plus',
    tagline: null,
    isDefault: false,
    trialDays: trialDays,
    features: features ?? (key == 'Taxi' ? taxiPlusFeatures : stayPlusFeatures),
    prices: [
      for (final (i, m) in [1, 3, 12].indexed)
        PlanPriceModel(cycleMonths: m, priceInr: rupees[i], perMonthInr: (rupees[i] / m).round(), savePercent: 0, playBasePlanId: 'p$m', playTrialOfferId: m == 1 ? 'trial' : null),
    ],
    playProductId: 'prod_${key.toLowerCase()}',
  );
}

Map<String, StorePrice> storeOf(String key) {
  final id = '${key}_plus';
  return key == 'Taxi'
      ? {'$id:1': sp('₹150', 150), '$id:3': sp('₹400', 400), '$id:12': sp('₹1,400', 1400)}
      : {'$id:1': sp('₹400', 400), '$id:3': sp('₹1,100', 1100), '$id:12': sp('₹3,800', 3800)};
}

StoreOffer trialOffer(String key) =>
    StoreOffer(productId: 'prod_${key.toLowerCase()}', basePlanId: 'p1', offerId: 'trial', offerToken: 't', price: sp('₹0', 0), isTrial: true, trialDays: 7);

final trialEnd = DateTime(2026, 11, 28);
final renewDate = DateTime(2026, 12, 21);

PlaySubInfo play(
  String key, {
  String state = 'SUBSCRIPTION_STATE_ACTIVE',
  bool auto = true,
  bool owns = true,
  DateTime? trialEnds,
  DateTime? expiry,
}) =>
    PlaySubInfo(
      state: state,
      autoRenewEnabled: auto,
      expiryAt: expiry ?? renewDate,
      trialEndsAt: trialEnds,
      productId: 'prod_${key.toLowerCase()}',
      basePlanId: 'p1',
      offerId: null,
      scheduledPlanName: null,
      scheduledAt: null,
      isTest: false,
      acknowledged: true,
      pausedAutoResumeAt: null,
      cancelReason: null,
      ownsActivePlan: owns,
    );

const taxiFreeLimits = PlanLimitsModel(routes: 1, ringWeight: 1);
const taxiPlusLimits = PlanLimitsModel(routes: 5, ringWeight: 2, featured: true, priority: 1, calendarEntries: 50, upcomingDays: 183, monthsAhead: 6, monthSummary: true, reminders: true);
const stayFreeLimits = PlanLimitsModel(photos: 2, roomTypes: 2, jobsPosts: 1);
const stayPlusLimits = PlanLimitsModel(photos: 8, roomTypes: 6, jobsPosts: 4, featured: true, priority: 1, calendarEntries: 50, upcomingDays: 183, monthsAhead: 6, monthSummary: true, reminders: true, specialPrices: 5, blockedRanges: 10);

/// The plan states of the frames, per role.
abstract final class Fx {
  static MyPlanModel free(String key, {bool trial = true, int? used}) => MyPlanModel(
        paymentEnabled: true,
        featureKey: key,
        limits: key == 'Taxi' ? taxiFreeLimits : stayFreeLimits,
        trialAvailable: trial,
        usage: key == 'Taxi' ? PlanUsageModel(routes: used ?? 1) : PlanUsageModel(photos: used ?? 2, roomTypes: 2),
      );

  static MyPlanModel trial(String key) => MyPlanModel(
        paymentEnabled: true,
        featureKey: key,
        planName: 'Plus',
        isDefault: false,
        isPaid: true,
        source: 'Trial',
        endsAt: trialEnd,
        limits: key == 'Taxi' ? taxiPlusLimits : stayPlusLimits,
        usage: key == 'Taxi' ? const PlanUsageModel(routes: 5) : const PlanUsageModel(photos: 8, roomTypes: 6),
        play: play(key, trialEnds: trialEnd, expiry: trialEnd),
      );

  static MyPlanModel plus(String key) => MyPlanModel(
        paymentEnabled: true,
        featureKey: key,
        planName: 'Plus',
        isDefault: false,
        isPaid: true,
        source: 'Subscription',
        endsAt: renewDate,
        limits: key == 'Taxi' ? taxiPlusLimits : stayPlusLimits,
        play: play(key),
      );

  static MyPlanModel cancelled(String key) => MyPlanModel(
        paymentEnabled: true,
        featureKey: key,
        planName: 'Plus',
        isDefault: false,
        isPaid: true,
        source: 'Subscription',
        endsAt: renewDate,
        limits: key == 'Taxi' ? taxiPlusLimits : stayPlusLimits,
        play: play(key, auto: false, state: 'SUBSCRIPTION_STATE_CANCELED'),
      );

  static MyPlanModel grace(String key) => MyPlanModel(
        paymentEnabled: true,
        featureKey: key,
        planName: 'Plus',
        isDefault: false,
        isPaid: true,
        source: 'Subscription',
        endsAt: renewDate,
        limits: key == 'Taxi' ? taxiPlusLimits : stayPlusLimits,
        play: play(key, state: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'),
      );

  static MyPlanModel onHold(String key, {int carry = 0}) => MyPlanModel(
        paymentEnabled: true,
        featureKey: key,
        isPaid: carry > 0,
        isDefault: carry == 0,
        planName: carry > 0 ? 'Plus' : 'Free',
        endsAt: carry > 0 ? DateTime(2026, 12, 5) : null,
        carryOverDays: carry,
        limits: key == 'Taxi' ? taxiFreeLimits : stayFreeLimits,
        play: play(key, state: 'SUBSCRIPTION_STATE_ON_HOLD', owns: false),
      );

  static MyPlanModel ended(String key, {bool hidden = true}) => MyPlanModel(
        paymentEnabled: true,
        featureKey: key,
        limits: key == 'Taxi' ? taxiFreeLimits : stayFreeLimits,
        usage: key == 'Taxi' ? const PlanUsageModel(routes: 1) : const PlanUsageModel(photos: 2, roomTypes: 2),
        hidden: hidden ? (key == 'Taxi' ? const PlanHiddenModel(routes: 3) : const PlanHiddenModel(photos: 6, roomTypes: 4)) : const PlanHiddenModel(),
        pausedByPlanCount: hidden ? (key == 'Taxi' ? 3 : 10) : 0,
        play: play(key, state: 'SUBSCRIPTION_STATE_EXPIRED', owns: false, auto: false),
      );

  static MyPlanModel off(String key) => MyPlanModel(
        paymentEnabled: false,
        featureKey: key,
        limits: key == 'Taxi' ? taxiPlusLimits : stayPlusLimits,
      );

  static MyPlanModel grant(String key) => MyPlanModel(
        paymentEnabled: true,
        featureKey: key,
        planName: 'Plus',
        isDefault: false,
        isPaid: true,
        source: 'AdminGrant',
        endsAt: renewDate,
        daysLeft: 29,
        limits: key == 'Taxi' ? taxiPlusLimits : stayPlusLimits,
      );
}

FakePlans installPlans(MyPlanModel me, {bool trialOffer_ = true, Map<String, int>? plusFeatures, int plusTrialDays = 7}) {
  final key = me.featureKey ?? 'Taxi';
  final c = FakePlans(prices: storeOf(key), trial: trialOffer_ ? trialOffer(key) : null);
  Get.put<PlanController>(c);
  c.myPlan.value = me;
  c.catalog.value = PlanCatalogModel({key: [freePlan(key), plusPlan(key, features: plusFeatures, trialDays: plusTrialDays)]}, paymentProvider: 'Play');
  c.storeState.value = StoreState.ready;
  PlanCopies.taxi = const TaxiPlanCopy();
  PlanCopies.stay = const StayPlanCopy();
  return c;
}

void resetPlans() {
  PlanGate.debugPlan = null;
  PlanGate.debugTrialDays = null;
  PlanCopies.reset();
  Get.reset();
}

const Map<String, double> planFrameHeights = {
  'o_pl_1': 1746,
  'o_pl_2': 1971,
  'o_pl_3': 1282,
  'o_pl_4': 1395,
  'o_pl_5': 701,
  'o_pl_6': 1256,
  'o_pl_7': 1011,
  'o_pl_8': 1086,
  'o_pl_9': 681,
};

/// Like renderOwnerFrame, at a given phone height (the plan frames use classes the shared helper does not read).
Future<File> renderPlanFrame(WidgetTester tester, String name, Widget screen, {required double height, double width = ownerFrameWidth}) async {
  const key = ValueKey('plan_frame_root');
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPhone(tester, RepaintBoundary(key: key, child: screen), size: Size(width, height), devicePixelRatio: ownerFrameDpr, toastHost: true);
  await settlePhone(tester);
  await settlePhone(tester);
  final file = File('$ownerRenderDir/$name.png');
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer;
    final ui.Image image = layer is OffsetLayer
        ? await layer.toImage(Offset.zero & (view.size * tester.view.devicePixelRatio), pixelRatio: 1)
        : await tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage(pixelRatio: ownerFrameDpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
  return file;
}
