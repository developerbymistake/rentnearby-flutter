import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';
import '../config/app_routes.dart';
import '../controllers/plan_controller.dart';
import '../features/owner_core/plan/plan_card_state.dart';
import '../models/my_plan_model.dart';
import 'plan_words.dart';

class PlanStateCopy {
  const PlanStateCopy._();

  static String date(DateTime d) => PlanWords.date(d);

  static bool autoRenews(MyPlanModel me) {
    final p = me.play;
    return p != null && p.ownsActivePlan && p.renewsAutomatically;
  }

  static bool blocksPurchase(MyPlanModel me) {
    final p = me.play;
    return p != null && (p.onHold || p.paused);
  }

  static bool opensManage(MyPlanModel me) {
    final p = me.play;
    if (p == null) return false;
    return p.needsFix || p.ownsActivePlan;
  }

  static String? status(MyPlanModel me) {
    final p = me.play;
    final at = p?.expiryAt ?? me.endsAt;
    switch (PlanCardStates.ofPlan(me)) {
      case PlanCardState.grace:
        return PlanWords.paymentIssue;
      case PlanCardState.onHold:
        return PlanWords.paymentOnHold;
      case PlanCardState.trial:
        final t = p?.trialEndsAt ?? at;
        return t == null ? null : PlanWords.trialEndsOn(t);
      case PlanCardState.plus:
        if (p != null && p.ownsActivePlan) return at == null ? null : PlanWords.renewsOn(at);
        return me.daysLeft != null ? '${me.daysLeft} days left' : null;
      case PlanCardState.cancelled:
        return at == null ? null : PlanWords.plusTill(at);
      case PlanCardState.ended:
        return PlanWords.subscriptionEnded;
      default:
        return null;
    }
  }

  static String action(MyPlanModel me) => switch (PlanCardStates.ofPlan(me)) {
        PlanCardState.grace || PlanCardState.onHold => PlanWords.fix,
        PlanCardState.trial || PlanCardState.plus || PlanCardState.cancelled || PlanCardState.adminGrant => 'Manage',
        PlanCardState.ended => PlanWords.subscribeAgain,
        _ => PlanWords.seePlus,
      };

  static void openFor(MyPlanModel me) {
    if (opensManage(me)) {
      Get.find<PlanController>().openManageSubscription();
    } else {
      Get.toNamed(AppRoutes.plansBilling);
    }
  }
}

class PlanSubscriptionCard extends StatelessWidget {
  final MyPlanModel me;
  final Color accent;
  final PlanCardState? state;
  final String? note;
  final String? onHoldBody;
  final String? chooseLabel;
  final VoidCallback? onChoose;
  final VoidCallback? onSubscribeAgain;

  const PlanSubscriptionCard({
    super.key,
    required this.me,
    required this.accent,
    this.state,
    this.note,
    this.onHoldBody,
    this.chooseLabel,
    this.onChoose,
    this.onSubscribeAgain,
  });

  @override
  Widget build(BuildContext context) {
    final p = me.play;
    if (p == null) return const SizedBox.shrink();
    final s = state ?? PlanCardStates.ofPlan(me);
    final view = _view(p, s);
    if (view == null) return const SizedBox.shrink();
    final plans = Get.find<PlanController>();
    final warn = s == PlanCardState.grace || s == PlanCardState.onHold;
    final scheduled = p.scheduledPlanName != null && p.scheduledAt != null
        ? 'Changes to ${p.scheduledPlanName} on ${PlanStateCopy.date(p.scheduledAt!)}'
        : null;
    final n = note;
    final manage = PlanSubAction(PlanWords.manageInPlay, plans.openManageSubscription);
    final fix = PlanSubAction(PlanWords.fix, plans.openManageSubscription);
    final action = switch (s) {
      PlanCardState.grace || PlanCardState.onHold => fix,
      PlanCardState.ended => PlanSubAction(PlanWords.subscribeAgain, onSubscribeAgain),
      PlanCardState.cancelled => PlanSubAction(PlanWords.resubscribe, plans.openManageSubscription),
      _ => manage,
    };
    final choose = chooseLabel != null && onChoose != null ? PlanSubAction(chooseLabel!, onChoose) : null;
    return PlanSubscriptionCard3D(
      tone: warn ? PlanLook.warmTone : PlanLook.toneOf(me.featureKey),
      art: _art(s),
      eyebrow: s == PlanCardState.onHold || s == PlanCardState.ended ? PlanWords.subscription : PlanWords.plus,
      pills: [if (s == PlanCardState.trial) PlanWords.trial],
      testPill: p.isTest ? 'Test' : null,
      title: view.$1,
      body: view.$2,
      notes: [
        if (n != null && n.isNotEmpty) (s == PlanCardState.grace ? ListingArt.star : ListingArt.worldMap, n),
        if (scheduled != null) (ListingArt.calendar, scheduled),
        if (me.carryOverDays > 0 && s != PlanCardState.onHold) (ListingArt.moneyBag, '+${me.carryOverDays} days after subscription'),
      ],
      action: action,
      secondary: choose,
      footer: PlanWords.useSameAccount,
      footerArt: ListingArt.key,
    );
  }

  static String _art(PlanCardState s) => switch (s) {
        PlanCardState.grace || PlanCardState.onHold => ListingArt.clipboard,
        PlanCardState.trial => ListingArt.star,
        PlanCardState.cancelled => ListingArt.pushpin,
        _ => ListingArt.calendar,
      };

  (String, String?)? _view(PlaySubInfo p, PlanCardState s) {
    final at = p.expiryAt ?? me.endsAt;
    switch (s) {
      case PlanCardState.grace:
        return (PlanWords.paymentIssue, PlanWords.updatePayment);
      case PlanCardState.onHold:
        final carry = me.carryOverDays > 0 && me.hasPaidPlan && me.endsAt != null;
        return (carry ? PlanWords.plusTill(me.endsAt!) : PlanWords.paymentOnHold, onHoldBody ?? PlanWords.fixToContinue);
      case PlanCardState.trial:
        final t = p.trialEndsAt?.toLocal() ?? at;
        return (t == null ? PlanWords.plus : PlanWords.trialEndsOn(t), PlanWords.thenRenews);
      case PlanCardState.plus:
        return (at == null ? PlanWords.plus : PlanWords.renewsOn(at), null);
      case PlanCardState.cancelled:
        return (at == null ? PlanWords.plus : PlanWords.plusTill(at), PlanWords.autoRenewOffDot);
      case PlanCardState.ended:
        return (PlanWords.subscriptionEnded, at == null ? null : PlanWords.endedOn(at));
      default:
        return null;
    }
  }
}
