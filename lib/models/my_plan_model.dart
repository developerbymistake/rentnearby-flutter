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
    );
  }
}
