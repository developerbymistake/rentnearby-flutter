import '../../../design/design.dart';
import '../../../design/extra/ext_plans.dart';
import '../../../models/my_plan_model.dart';
import '../../../models/plan_model.dart';
import '../home/owner_home_models.dart';
import '../json/owner_json.dart';
import '../../../widgets/plan_words.dart';
import 'plan_keys.dart';

enum PlanCardState { free, trial, plus, cancelled, grace, onHold, ended, adminGrant, paymentOff, unknown }

abstract final class PlanCardStates {
  static const Map<String, PlanCardState> wire = {
    'Free': PlanCardState.free,
    'Trial': PlanCardState.trial,
    'Plus': PlanCardState.plus,
    'Cancelled': PlanCardState.cancelled,
    'Grace': PlanCardState.grace,
    'OnHold': PlanCardState.onHold,
    'Ended': PlanCardState.ended,
    'AdminGrant': PlanCardState.adminGrant,
    'PaymentOff': PlanCardState.paymentOff,
  };

  static PlanCardState parse(Object? raw) => OwnerJson.pick(raw, wire, PlanCardState.unknown);

  static const int endedWindowDays = 30;

  /// The Plans page state from /plans/me. A cancelled trial reads as Cancelled (o_pl_3); on hold wins over carried-over days (o_pl_7).
  static PlanCardState ofPlan(MyPlanModel me, {DateTime? now}) {
    if (!me.paymentEnabled) return PlanCardState.paymentOff;
    final p = me.play;
    if (me.hasPaidPlan && me.source == 'AdminGrant') return PlanCardState.adminGrant;
    if (p != null && (p.onHold || p.paused)) return PlanCardState.onHold;
    if (p != null && p.inGrace) return PlanCardState.grace;
    if (me.hasPaidPlan) {
      if (p != null && p.ownsActivePlan && !p.renewsAutomatically) return PlanCardState.cancelled;
      if (me.isTrial || (p?.inTrial ?? false)) return PlanCardState.trial;
      return PlanCardState.plus;
    }
    if (p != null && p.ended) {
      final at = p.expiryAt ?? me.endsAt;
      final today = now ?? DateTime.now();
      if (at == null || today.difference(at).inDays < endedWindowDays) return PlanCardState.ended;
    }
    return PlanCardState.free;
  }

  /// Home card data when the Home feed has no planCard (old server): built from /plans/me, never a guessed number.
  static OwnerPlanCard fromPlan(MyPlanModel me) => OwnerPlanCard(
        state: ofPlan(me),
        paymentEnabled: me.paymentEnabled,
        isPaid: me.isPaid,
        source: me.source,
        endsAt: me.play?.expiryAt ?? me.endsAt,
        renewsOn: me.play?.renewsAutomatically == true ? me.play?.expiryAt : null,
        trialAvailable: me.trialAvailable,
        hidden: {'photos': me.hidden.photos, 'roomTypes': me.hidden.roomTypes, 'routes': me.hidden.routes},
        limits: {'photos': me.limits.photos, 'roomTypes': me.limits.roomTypes, 'routes': me.limits.routes},
        paymentStartsOn: me.paymentStartsOn,
        plansStartedToday: me.plansStartedToday,
      );

  static bool plusValues(PlanCardState s) =>
      s == PlanCardState.trial || s == PlanCardState.plus || s == PlanCardState.cancelled || s == PlanCardState.grace || s == PlanCardState.adminGrant;

  static bool showsCycles(PlanCardState s) => s != PlanCardState.cancelled && s != PlanCardState.paymentOff && s != PlanCardState.unknown;

  static bool showsCompare(PlanCardState s) => s == PlanCardState.free || s == PlanCardState.onHold || s == PlanCardState.ended;

  static bool blocksPurchase(PlanCardState s) => s == PlanCardState.onHold;
}

/// Plan values for the compare table: the free plan and the first paid plan of the catalog, else the seed values.
class PlanValues {
  const PlanValues({this.freeFeatures = const {}, this.plusFeatures = const {}});

  final Map<String, int> freeFeatures;
  final Map<String, int> plusFeatures;

  factory PlanValues.fromCatalog(List<PlanModel> plans) {
    PlanModel? free;
    PlanModel? plus;
    for (final p in plans) {
      if (p.isDefault) {
        free ??= p;
      } else {
        plus ??= p;
      }
    }
    return PlanValues(freeFeatures: free?.features ?? const {}, plusFeatures: plus?.features ?? const {});
  }

  int free(PlanKey k) => freeFeatures[k.wire] ?? PlanKeys.freeSeed[k] ?? 0;
  int plus(PlanKey k) => plusFeatures[k.wire] ?? PlanKeys.plusSeed[k] ?? 0;
  bool freeFlag(String wire) => (freeFeatures[wire] ?? 0) > 0;
  bool plusFlag(String wire) => (plusFeatures[wire] ?? 1) > 0;
}

abstract final class CompareCellData {
  static PlanCellData text(String t) => PlanCellData(t, PlanCellKind.number);

  static String spoken(PlanCellData c) => switch (c.kind) {
        PlanCellKind.yes => PlanWords.included,
        PlanCellKind.no => PlanWords.notIncluded,
        PlanCellKind.number => c.text,
      };
}

abstract final class PlanCardLimits {
  static int plus(OwnerPlanCard? card, String jsonKey, PlanKey key) =>
      OwnerJson.intOrNull(card?.limits[jsonKey]) ?? PlanKeys.plusSeed[key] ?? 0;

  static int hidden(OwnerPlanCard? card, String jsonKey) => OwnerJson.intOrNull(card?.hidden[jsonKey]) ?? 0;
}

enum PlanHomeAction { none, tryFree, seePlus, manage, fix, subscribeAgain }

enum PlanHomeLook { plus, warn, ended, off }

class PlanHomeView {
  const PlanHomeView({required this.state, required this.title, this.pill, this.line, this.action = PlanHomeAction.none, this.look = PlanHomeLook.plus, this.art = ListingArt.crown});

  final PlanCardState state;
  final String title;
  final String? pill;
  final String? line;
  final PlanHomeAction action;
  final PlanHomeLook look;
  final String art;
}

/// Role wording of the Plans page and the Home plan card. Each role module implements it and registers it in [PlanCopies].
abstract class PlanRoleCopy {
  const PlanRoleCopy();

  String get featureKey;
  String get subtitle;
  ListingTone get homeTone;
  String get offLine;
  String get onHoldBody;
  bool get showsWeek;
  String? get chooseLabel;
  void openChoose();

  String heroSubtitle(PlanCardState s, MyPlanModel me);
  List<PlanHeroLine> heroLines(PlanCardState s, MyPlanModel me, PlanValues v);
  PlanHeroMeter? heroMeter(PlanCardState s, MyPlanModel me, PlanValues v);
  String? subNote(PlanCardState s, MyPlanModel me, PlanValues v);
  List<PlanRowData> compareRows(PlanValues v);
  List<(String, String)> weekCells(OwnerWeekly w);
  PlanHomeView homeCard(OwnerPlanCard? card, {String? city, PlanValues v = const PlanValues()});
  String profileLine(MyPlanModel me);
}

abstract final class PlanCopies {
  static PlanRoleCopy? stay;
  static PlanRoleCopy? taxi;

  static PlanRoleCopy? of(String? featureKey) => switch (featureKey) {
        'Stay' => stay,
        'Taxi' => taxi,
        _ => null,
      };

  static void reset() {
    stay = null;
    taxi = null;
  }
}
