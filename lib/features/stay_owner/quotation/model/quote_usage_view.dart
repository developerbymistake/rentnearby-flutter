import '../../../../models/my_plan_model.dart';
import '../../../owner_core/plan/plan_card_state.dart';
import '../../strings/stay_quote_strings.dart';
import '../data/quote_models.dart' show QuoteTime;

class QuoteUsageView {
  const QuoteUsageView({required this.used, required this.limit, this.top, required this.line1, this.line2, this.seePlus = false});

  final int used;
  final int limit;
  final String? top;
  final String line1;
  final String? line2;
  final bool seePlus;

  bool get full => used >= limit;
  double get fraction => limit <= 0 ? 1 : (used / limit).clamp(0, 1).toDouble();

  // Usage line table (ARCHITECTURE 10.4); never "7 of 2".
  static QuoteUsageView of({
    required PlanCardState state,
    required int used,
    required int limit,
    DateTime? resetsAt,
    DateTime? endsAt,
  }) {
    // The server resets at 1st 00:00 IST: read the month in IST, never in the phone's zone.
    final reset = resetsAt == null ? StayQuoteStrings.resetsSoon : StayQuoteStrings.resetsFree(QuoteTime.toIst(resetsAt));
    final fullLine = resetsAt == null ? StayQuoteStrings.resetsSoon : StayQuoteStrings.resetsFull(QuoteTime.toIst(resetsAt));
    switch (state) {
      case PlanCardState.paymentOff:
        return QuoteUsageView(used: used, limit: limit, line1: StayQuoteStrings.offLine(used, limit));
      case PlanCardState.plus:
      case PlanCardState.grace:
      case PlanCardState.adminGrant:
      case PlanCardState.trial:
        return QuoteUsageView(
          used: used,
          limit: limit,
          line1: StayQuoteStrings.plusLine(used, limit),
          line2: used >= limit ? fullLine : (endsAt == null ? null : StayQuoteStrings.plusTill(limit, endsAt.toLocal())),
        );
      case PlanCardState.cancelled:
        return QuoteUsageView(
          used: used,
          limit: limit,
          line1: StayQuoteStrings.plusLine(used, limit),
          line2: used >= limit ? fullLine : (endsAt == null ? null : StayQuoteStrings.plusEndsOn(limit, endsAt.toLocal())),
        );
      case PlanCardState.ended:
      case PlanCardState.onHold:
        return QuoteUsageView(
          used: used,
          limit: limit,
          top: endsAt == null ? StayQuoteStrings.plusEndedNoDate : StayQuoteStrings.plusEnded(endsAt.toLocal()),
          line1: StayQuoteStrings.freeLine(used, limit),
          line2: StayQuoteStrings.freeMakes(limit),
          seePlus: true,
        );
      case PlanCardState.free:
      case PlanCardState.unknown:
        return QuoteUsageView(used: used, limit: limit, line1: StayQuoteStrings.freeLine(used, limit), line2: reset);
    }
  }

  static QuoteUsageView fromPlan(MyPlanModel me, {int? usedOverride, DateTime? now}) {
    final l = me.limits;
    final ends = me.play?.expiryAt ?? me.endsAt;
    return of(
      state: PlanCardStates.ofPlan(me, now: now),
      used: usedOverride ?? l.quotationsUsed,
      limit: l.quotationsPerMonth,
      resetsAt: l.quotationsResetsAt,
      endsAt: ends,
    );
  }

  String get countLine => StayQuoteStrings.ofUsed(used, limit);
}
