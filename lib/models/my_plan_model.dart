import '../features/buddy/shared/buddy_json.dart';

class PlanLimitsModel {
  final int listingLimit;
  final int used;
  final int live;
  final int priority;
  final bool featured;
  final int jobsPosts;
  final int photos;
  final int roomTypes;
  final int routes;
  final int ringWeight;
  final int calendarEntries;
  final int blockedRanges;
  final int upcomingDays;
  final int monthsAhead;
  final bool monthSummary;
  final bool reminders;
  final int specialPrices;
  final int quotationsPerMonth;
  final int quotationsUsed;
  final DateTime? quotationsResetsAt;

  const PlanLimitsModel({
    this.listingLimit = 1,
    this.used = 0,
    this.live = 0,
    this.priority = 0,
    this.featured = false,
    this.jobsPosts = 0,
    this.photos = 2,
    this.roomTypes = 2,
    this.routes = 1,
    this.ringWeight = 1,
    this.calendarEntries = 4,
    this.blockedRanges = 1,
    this.upcomingDays = 15,
    this.monthsAhead = 0,
    this.monthSummary = false,
    this.reminders = false,
    this.specialPrices = 1,
    this.quotationsPerMonth = 2,
    this.quotationsUsed = 0,
    this.quotationsResetsAt,
  });

  static bool _switch(Object? v) => v == true || (v is num && v > 0) || v == 'true';

  factory PlanLimitsModel.fromJson(Map<String, dynamic> j) => PlanLimitsModel(
        listingLimit: BuddyJson.integer(j['listingLimit'], 1),
        used: BuddyJson.integer(j['used']),
        live: BuddyJson.integer(j['live']),
        priority: BuddyJson.integer(j['priority']),
        featured: _switch(j['featured']),
        jobsPosts: BuddyJson.integer(j['jobsPosts']),
        photos: BuddyJson.integer(j['photos'], 2),
        roomTypes: BuddyJson.integer(j['roomTypes'], 2),
        routes: BuddyJson.integer(j['routes'], 1),
        ringWeight: BuddyJson.integer(j['ringWeight'], 1),
        calendarEntries: BuddyJson.integer(j['calendarEntries'], 4),
        blockedRanges: BuddyJson.integer(j['blockedRanges'], 1),
        upcomingDays: BuddyJson.integer(j['upcomingDays'], 15),
        monthsAhead: BuddyJson.integer(j['monthsAhead']),
        monthSummary: _switch(j['monthSummary']),
        reminders: _switch(j['reminders']),
        specialPrices: BuddyJson.integer(j['specialPrices'], 1),
        quotationsPerMonth: BuddyJson.integer(j['quotationsPerMonth'], 2),
        quotationsUsed: BuddyJson.integer(j['quotationsUsed']),
        quotationsResetsAt: BuddyJson.time(j['quotationsResetsAt']),
      );
}

class PlanHiddenModel {
  final int photos;
  final int roomTypes;
  final int routes;
  final int specialPrices;

  const PlanHiddenModel({this.photos = 0, this.roomTypes = 0, this.routes = 0, this.specialPrices = 0});

  int get total => photos + roomTypes + routes + specialPrices;

  factory PlanHiddenModel.fromJson(Map<String, dynamic> j) => PlanHiddenModel(
        photos: BuddyJson.integer(j['photos']),
        roomTypes: BuddyJson.integer(j['roomTypes']),
        routes: BuddyJson.integer(j['routes']),
        specialPrices: BuddyJson.integer(j['specialPrices']),
      );
}

class PlanUsageModel {
  final int? photos;
  final int? roomTypes;
  final int? routes;

  const PlanUsageModel({this.photos, this.roomTypes, this.routes});

  factory PlanUsageModel.fromJson(Map<String, dynamic> j) => PlanUsageModel(
        photos: BuddyJson.intOrNull(j['photos']),
        roomTypes: BuddyJson.intOrNull(j['roomTypes']),
        routes: BuddyJson.intOrNull(j['routes']),
      );
}

class PlaySubInfo {
  final String state;
  final bool autoRenewEnabled;
  final DateTime? expiryAt;
  final DateTime? trialEndsAt;
  final String productId;
  final String? basePlanId;
  final String? offerId;
  final String? scheduledPlanName;
  final DateTime? scheduledAt;
  final bool isTest;
  final bool acknowledged;
  final DateTime? pausedAutoResumeAt;
  final String? cancelReason;
  final bool ownsActivePlan;

  const PlaySubInfo({
    required this.state,
    required this.autoRenewEnabled,
    required this.expiryAt,
    required this.trialEndsAt,
    required this.productId,
    required this.basePlanId,
    required this.offerId,
    required this.scheduledPlanName,
    required this.scheduledAt,
    required this.isTest,
    required this.acknowledged,
    required this.pausedAutoResumeAt,
    required this.cancelReason,
    required this.ownsActivePlan,
  });

  bool get isActive => state == 'SUBSCRIPTION_STATE_ACTIVE';
  bool get inGrace => state == 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD';
  bool get onHold => state == 'SUBSCRIPTION_STATE_ON_HOLD';
  bool get paused => state == 'SUBSCRIPTION_STATE_PAUSED';
  bool get cancelled => state == 'SUBSCRIPTION_STATE_CANCELED';
  bool get expired => state == 'SUBSCRIPTION_STATE_EXPIRED';
  bool get inTrial => trialEndsAt != null && trialEndsAt!.isAfter(DateTime.now());
  bool get renewsAutomatically => isActive && autoRenewEnabled;
  bool get needsFix => inGrace || onHold || paused;
  bool get ended => (cancelled || expired) && !ownsActivePlan;

  static DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

  factory PlaySubInfo.fromJson(Map<String, dynamic> j) => PlaySubInfo(
        state: BuddyJson.str(j['state']),
        autoRenewEnabled: j['autoRenewEnabled'] == true,
        expiryAt: _date(j['expiryAt']),
        trialEndsAt: _date(j['trialEndsAt']),
        productId: BuddyJson.str(j['productId']),
        basePlanId: BuddyJson.strOrNull(j['basePlanId']),
        offerId: BuddyJson.strOrNull(j['offerId']),
        scheduledPlanName: BuddyJson.strOrNull(j['scheduledPlanName']),
        scheduledAt: _date(j['scheduledAt']),
        isTest: j['isTest'] == true,
        acknowledged: j['acknowledged'] == true,
        pausedAutoResumeAt: _date(j['pausedAutoResumeAt']),
        cancelReason: BuddyJson.strOrNull(j['cancelReason']),
        ownsActivePlan: j['ownsActivePlan'] == true,
      );
}

class MyPlanModel {
  final bool paymentEnabled;
  final int freeDays;
  final String? featureKey;
  final String? planId;
  final String planName;
  final bool isDefault;
  final bool isPaid;
  final String? source;
  final String? status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? daysLeft;
  final PlanLimitsModel limits;
  final bool trialAvailable;
  final String? openPurchaseId;
  final int pausedByPlanCount;
  final String paymentProvider;
  final int carryOverDays;
  final String? manageUrl;
  final PlaySubInfo? play;
  final PlanHiddenModel hidden;
  final PlanUsageModel usage;
  final bool? canUpgradeField;
  final DateTime? paymentStartsOn;
  final bool plansStartedToday;
  // Server plan card state (FB-50); null on an older server.
  final String? state;

  const MyPlanModel({
    this.paymentEnabled = false,
    this.freeDays = 30,
    this.featureKey,
    this.planId,
    this.planName = 'Free',
    this.isDefault = true,
    this.isPaid = false,
    this.source,
    this.status,
    this.startsAt,
    this.endsAt,
    this.daysLeft,
    this.limits = const PlanLimitsModel(),
    this.trialAvailable = false,
    this.openPurchaseId,
    this.pausedByPlanCount = 0,
    this.paymentProvider = 'Play',
    this.carryOverDays = 0,
    this.manageUrl,
    this.play,
    this.hidden = const PlanHiddenModel(),
    this.usage = const PlanUsageModel(),
    this.canUpgradeField,
    this.paymentStartsOn,
    this.plansStartedToday = false,
    this.state,
  });

  bool get canUpgrade => canUpgradeField ?? (paymentEnabled && !isPaid);

  bool get isTrial => source == 'Trial';
  bool get hasPaidPlan => isPaid && !isDefault;

  factory MyPlanModel.fromJson(Map<String, dynamic> j) {
    final plan = BuddyJson.mapOrNull(j['plan']);
    final play = BuddyJson.mapOrNull(j['play']);
    return MyPlanModel(
      paymentEnabled: j['paymentEnabled'] == true,
      freeDays: BuddyJson.integer(j['freeDays'], 30),
      featureKey: BuddyJson.strOrNull(j['featureKey']),
      planId: BuddyJson.strOrNull(plan?['id']),
      planName: BuddyJson.strOrNull(plan?['name']) ?? 'Free',
      isDefault: plan?['isDefault'] != false,
      isPaid: j['isPaid'] == true,
      source: BuddyJson.strOrNull(j['source']),
      status: BuddyJson.strOrNull(j['status']),
      startsAt: BuddyJson.time(j['startsAt'])?.toLocal(),
      endsAt: BuddyJson.time(j['endsAt'])?.toLocal(),
      daysLeft: BuddyJson.intOrNull(j['daysLeft']),
      limits: PlanLimitsModel.fromJson(BuddyJson.map(j['limits'])),
      trialAvailable: j['trialAvailable'] == true,
      openPurchaseId: BuddyJson.strOrNull(j['openPurchaseId']),
      pausedByPlanCount: BuddyJson.integer(j['pausedByPlanCount']),
      paymentProvider: BuddyJson.strOrNull(j['paymentProvider']) ?? 'Play',
      carryOverDays: BuddyJson.integer(j['carryOverDays']),
      manageUrl: BuddyJson.strOrNull(j['manageUrl']),
      play: play == null ? null : PlaySubInfo.fromJson(play),
      hidden: PlanHiddenModel.fromJson(BuddyJson.map(j['hidden'])),
      usage: PlanUsageModel.fromJson(BuddyJson.map(j['usage'])),
      canUpgradeField: j['canUpgrade'] is bool ? j['canUpgrade'] as bool : null,
      paymentStartsOn: BuddyJson.date(j['paymentStartsOn']),
      plansStartedToday: j['plansStartedToday'] == true,
      state: BuddyJson.strOrNull(j['state']),
    );
  }
}
