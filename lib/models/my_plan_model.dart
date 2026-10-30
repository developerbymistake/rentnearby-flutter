class PlanLimitsModel {
  final int listingLimit;
  final int used;
  final int live;
  final int priority;
  final bool featured;
  final int jobsPosts;

  const PlanLimitsModel({
    this.listingLimit = 1,
    this.used = 0,
    this.live = 0,
    this.priority = 0,
    this.featured = false,
    this.jobsPosts = 0,
  });

  factory PlanLimitsModel.fromJson(Map<String, dynamic> j) => PlanLimitsModel(
        listingLimit: (j['listingLimit'] as num?)?.toInt() ?? 1,
        used: (j['used'] as num?)?.toInt() ?? 0,
        live: (j['live'] as num?)?.toInt() ?? 0,
        priority: (j['priority'] as num?)?.toInt() ?? 0,
        featured: j['featured'] == true,
        jobsPosts: (j['jobsPosts'] as num?)?.toInt() ?? 0,
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
        state: j['state'] as String? ?? '',
        autoRenewEnabled: j['autoRenewEnabled'] == true,
        expiryAt: _date(j['expiryAt']),
        trialEndsAt: _date(j['trialEndsAt']),
        productId: j['productId'] as String? ?? '',
        basePlanId: j['basePlanId'] as String?,
        offerId: j['offerId'] as String?,
        scheduledPlanName: j['scheduledPlanName'] as String?,
        scheduledAt: _date(j['scheduledAt']),
        isTest: j['isTest'] == true,
        acknowledged: j['acknowledged'] == true,
        pausedAutoResumeAt: _date(j['pausedAutoResumeAt']),
        cancelReason: j['cancelReason'] as String?,
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
  });

  bool get isTrial => source == 'Trial';
  bool get hasPaidPlan => isPaid && !isDefault;

  factory MyPlanModel.fromJson(Map<String, dynamic> j) {
    final plan = j['plan'] as Map<String, dynamic>?;
    return MyPlanModel(
      paymentEnabled: j['paymentEnabled'] == true,
      freeDays: (j['freeDays'] as num?)?.toInt() ?? 30,
      featureKey: j['featureKey'] as String?,
      planId: plan?['id'] as String?,
      planName: plan?['name'] as String? ?? 'Free',
      isDefault: plan?['isDefault'] != false,
      isPaid: j['isPaid'] == true,
      source: j['source'] as String?,
      status: j['status'] as String?,
      startsAt: j['startsAt'] != null ? DateTime.tryParse(j['startsAt'] as String)?.toLocal() : null,
      endsAt: j['endsAt'] != null ? DateTime.tryParse(j['endsAt'] as String)?.toLocal() : null,
      daysLeft: (j['daysLeft'] as num?)?.toInt(),
      limits: PlanLimitsModel.fromJson((j['limits'] as Map<String, dynamic>?) ?? const {}),
      trialAvailable: j['trialAvailable'] == true,
      openPurchaseId: j['openPurchaseId'] as String?,
      pausedByPlanCount: (j['pausedByPlanCount'] as num?)?.toInt() ?? 0,
      paymentProvider: j['paymentProvider'] as String? ?? 'Play',
      carryOverDays: (j['carryOverDays'] as num?)?.toInt() ?? 0,
      manageUrl: j['manageUrl'] as String?,
      play: j['play'] is Map<String, dynamic> ? PlaySubInfo.fromJson(j['play'] as Map<String, dynamic>) : null,
    );
  }
}
