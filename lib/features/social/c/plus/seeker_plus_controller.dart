import 'package:get/get.dart';

import '../../../../controllers/plan_controller.dart';
import '../../../../design/tokens/listing_palette.dart';
import '../../../../models/my_plan_model.dart';
import '../../../../models/plan_model.dart';
import '../../../trip/widgets/hub/hub_art.dart';
import '../../../../widgets/plan_subscription_card.dart';
import '../../../owner_core/plan/plan_card_state.dart';
import '../../../buddy/shared/buddy_format.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../social_strings_c.dart';
import 'seeker_plan_keys.dart';

class PlusCycle {
  const PlusCycle({required this.months, required this.price, this.perMonth});

  final int months;
  final String price;
  final String? perMonth;
}

class PlusPerk {
  const PlusPerk({required this.art, required this.title, this.subtitle});

  final String art;
  final String title;
  final String? subtitle;
}

class SeekerPlusController extends GetxController {
  SeekerPlusController({PlanController? plans, this.from}) : _plans = plans;

  static const List<int> cycleOrder = [12, 3, 1];

  final String? from;
  final PlanController? _plans;
  final selected = 12.obs;

  PlanController get plans => _plans ?? Get.find<PlanController>();

  SocialLimits? get limits => SocialMeController.maybe?.me.value?.limits;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool force = false}) async {
    await Future.wait([plans.refreshPlan(force: force), plans.loadCatalog(force: force)]);
    _pickDefault();
  }

  PlanModel? get plusPlan => SeekerPlanKeys.plusPlan(plans.catalog.value);

  PlanModel? get freePlan {
    for (final p in SeekerPlanKeys.seekerPlans(plans.catalog.value)) {
      if (p.isDefault) return p;
    }
    return null;
  }

  bool get isPlus {
    final me = plans.myPlan.value;
    return (limits?.isPlus ?? false) || (me.featureKey == SeekerPlanKeys.featureKey && me.hasPaidPlan);
  }

  MyPlanModel? get seekerPlan {
    final me = plans.myPlan.value;
    return me.featureKey == SeekerPlanKeys.featureKey ? me : null;
  }

  PlanCardState get state {
    final me = seekerPlan;
    return me == null ? PlanCardState.free : PlanCardStates.ofPlan(me);
  }

  bool get holdBlocked {
    final me = seekerPlan;
    return me != null && PlanStateCopy.blocksPurchase(me);
  }

  int get pausedCount => isPlus ? 0 : limits?.pausedTotal ?? 0;

  bool get canBuy => !isPlus && plusPlan != null && plans.paymentEnabled && !holdBlocked;

  List<int> get cycles {
    final p = plusPlan;
    if (p == null) return const [];
    return [for (final m in cycleOrder) if (p.priceFor(m) != null) m];
  }

  void _pickDefault() {
    final c = cycles;
    if (c.isNotEmpty && !c.contains(selected.value)) selected.value = c.first;
  }

  void select(int months) {
    if (cycles.contains(months)) selected.value = months;
  }

  PlusCycle? cycle(int months) {
    final p = plusPlan;
    final price = p?.priceFor(months);
    if (p == null || price == null) return null;
    final store = plans.storePriceFor(p, months)?.formatted;
    final perMonth = months > 1 && price.priceInr > 0 ? BuddyFormat.rupees((price.priceInr / months).round()) : null;
    return PlusCycle(months: months, price: store ?? BuddyFormat.rupees(price.priceInr), perMonth: perMonth);
  }

  int plusValue(String key) => plusPlan?.feature(key) ?? 0;

  int? freeValue(String key, int? Function(SocialLimits l) live) {
    final f = freePlan;
    if (f != null && f.features.containsKey(key)) return f.feature(key);
    final l = limits;
    return l == null || l.isPlus ? null : live(l);
  }

  List<PlusPerk> perks() {
    final freeChats = freeValue(SeekerPlanKeys.newChats, (l) => l.newChats.limit);
    final freePub = freeValue(SeekerPlanKeys.publicTrips, (l) => l.publicTrips.limit);
    final freeAct = freeValue(SeekerPlanKeys.activeTrips, (l) => l.activeTrips.limit);
    final freeJoin = freeValue(SeekerPlanKeys.joinRequests, (l) => l.joinRequests.limit);
    final chats = plusValue(SeekerPlanKeys.newChats);
    final pub = plusValue(SeekerPlanKeys.publicTrips);
    final act = plusValue(SeekerPlanKeys.activeTrips);
    final join = plusValue(SeekerPlanKeys.joinRequests);
    return [
      if (chats > 0) PlusPerk(art: ListingArt.speechBalloon, title: SocialStringsC.chatPeople(chats), subtitle: freeChats == null ? null : SocialStringsC.chatPeopleSub(freeChats)),
      if (pub > 0) PlusPerk(art: ListingArt.luggage, title: SocialStringsC.publicTrips(pub), subtitle: freePub == null ? null : SocialStringsC.freeHas(freePub)),
      if (act > 0) PlusPerk(art: ListingArt.calendar, title: SocialStringsC.activeTrips(act), subtitle: freeAct == null ? null : SocialStringsC.freeHas(freeAct)),
      if (join > 0) PlusPerk(art: ListingArt.panda, title: SocialStringsC.joinRequests(join), subtitle: freeJoin == null ? null : SocialStringsC.freeHas(freeJoin)),
      if (plusValue(SeekerPlanKeys.genderOnly) > 0) const PlusPerk(art: HubArt.womanRaising, title: SocialStringsC.genderOnly, subtitle: SocialStringsC.genderOnlySub),
      if (plusValue(SeekerPlanKeys.nearMe) > 0) const PlusPerk(art: ListingArt.roundPushpin, title: SocialStringsC.nearMe, subtitle: SocialStringsC.nearMeSub),
    ];
  }

  Future<void> subscribe() async {
    final p = plusPlan;
    if (p == null || !canBuy || plans.isPurchasing.value) return;
    await plans.purchase(p, selected.value, null);
  }

  Future<void> afterPurchase() async {
    await plans.refreshPlan(force: true);
    await SocialMeController.maybe?.refreshQuiet();
  }

  Future<void> manage() => plans.openManageSubscription();

  Future<void> restore() => plans.restorePurchases(force: true, userInitiated: true);
}
