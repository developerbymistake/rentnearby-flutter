import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/social/shared/data/social_me_api.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/plan_model.dart';

PlanModel seekerFree() => PlanModel.fromJson({
      'id': 'b1000000-0000-0000-0000-000000000501',
      'code': 'SEEKER_FREE',
      'name': 'Free',
      'isDefault': true,
      'features': {'SeekerActiveTrips': 1, 'SeekerPublicTrips': 1, 'SeekerJoinRequestsPerMonth': 1, 'SeekerNewChatsPerMonth': 3, 'SeekerGenderOnlyTrips': 0, 'SeekerNearMe': 0, 'SeekerGroupChat': 0},
      'prices': [],
    }, 'Seeker');

PlanModel seekerPlus() => PlanModel.fromJson({
      'id': 'b1000000-0000-0000-0000-000000000502',
      'code': 'SEEKER_PLUS',
      'name': 'Bakhli Plus',
      'tagline': 'Join more trips',
      'isDefault': false,
      'features': {'SeekerActiveTrips': 10, 'SeekerPublicTrips': 3, 'SeekerJoinRequestsPerMonth': 5, 'SeekerNewChatsPerMonth': 10, 'SeekerGenderOnlyTrips': 1, 'SeekerNearMe': 1, 'SeekerGroupChat': 1},
      'prices': [
        {'cycleMonths': 1, 'priceInr': 200, 'perMonthInr': 200, 'playBasePlanId': 'cycle-1m'},
        {'cycleMonths': 3, 'priceInr': 500, 'perMonthInr': 166, 'playBasePlanId': 'cycle-3m'},
        {'cycleMonths': 12, 'priceInr': 1800, 'perMonthInr': 150, 'playBasePlanId': 'cycle-12m'},
      ],
      'playProductId': 'seeker_plus',
    }, 'Seeker');

class FakePlanController extends PlanController {
  FakePlanController({bool paid = false, bool paymentEnabled = true}) {
    catalog.value = PlanCatalogModel({'Seeker': [seekerFree(), seekerPlus()]});
    myPlan.value = MyPlanModel(paymentEnabled: paymentEnabled, featureKey: 'Seeker', isPaid: paid, isDefault: !paid, planName: paid ? 'Bakhli Plus' : 'Free');
  }

  final List<(String, int)> bought = [];

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> refreshPlan({bool force = false}) async {}

  @override
  Future<void> loadCatalog({bool force = false}) async {}

  @override
  Future<void> purchase(PlanModel plan, int cycleMonths, String? couponCode, {bool useTrial = false}) async => bought.add((plan.id, cycleMonths));
}

class FakeSocialMeController extends SocialMeController {
  FakeSocialMeController(SocialLimits limits) : super(api: const SocialMeApi()) {
    me.value = SocialMe(limits: limits);
  }

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> refreshQuiet() async {}

  @override
  Future<void> load() async {}
}

SocialLimits freeLimits({bool canUpgrade = true}) => SocialLimits(
      isPlus: false,
      canUpgrade: canUpgrade,
      resetsAt: DateTime.utc(2026, 11, 30, 18, 30),
      activeTrips: const LimitUse(limit: 1, used: 0),
      publicTrips: const LimitUse(limit: 1, used: 1),
      joinRequests: const LimitUse(limit: 1, used: 1),
      newChats: const LimitUse(limit: 3, used: 1),
      genderOnlyTrips: false,
      nearMe: false,
    );

SocialLimits plusLimits() => const SocialLimits(
      isPlus: true,
      canUpgrade: false,
      activeTrips: LimitUse(limit: 10, used: 0),
      publicTrips: LimitUse(limit: 3, used: 0),
      joinRequests: LimitUse(limit: 5, used: 0),
      newChats: LimitUse(limit: 10, used: 0),
      genderOnlyTrips: true,
      nearMe: true,
    );
