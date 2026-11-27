import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/plan_controller.dart';
import '../../../../design/design.dart';
import '../../../owner_core/plan/plan_card_state.dart';
import '../../../owner_core/plan/plan_gate.dart';
import '../../../owner_core/plan/plan_keys.dart';
import '../../../owner_core/plan/plan_limit_sheet.dart';
import '../../calendar/widgets/stay_calendar_widgets.dart';
import '../../strings/stay_quote_strings.dart';
import 'quote_line_card.dart';

abstract final class QuoteLimitSheets {
  static PlanValues _values() => Get.isRegistered<PlanController>() ? PlanValues.fromCatalog(Get.find<PlanController>().plans) : const PlanValues();

  // canUpgrade -> the Plus sheet built from the plan values; otherwise the calm sheet (no upsell).
  static GateSpec gate({required int used, required int limit, DateTime? resetsAt, PlanValues? values}) {
    final v = values ?? _values();
    final free = v.free(PlanKey.quotationsPerMonth);
    final plus = v.plus(PlanKey.quotationsPerMonth);
    return GateSpec(
      id: 'quotations',
      title: StayQuoteStrings.limitTitle(used, limit),
      body: StayQuoteStrings.limitBody(free, plus),
      taxi: false,
      art: ListingArt.memo,
      rows: [
        GateRow(label: StayQuoteStrings.freePlan, value: StayQuoteStrings.perMonth(free)),
        GateRow(label: StayQuoteStrings.plusLabel, value: StayQuoteStrings.perMonth(plus), highlight: true),
      ],
      tip: resetsAt == null ? StayQuoteStrings.limitTipNoDate : StayQuoteStrings.limitTip(resetsAt.toLocal()),
    );
  }

  static Future<void> show(BuildContext context, {required int used, required int limit, required bool canUpgrade, DateTime? resetsAt}) {
    if (canUpgrade && PlanGate.canUpgrade) return PlanLimitSheet.show(context, gate(used: used, limit: limit, resetsAt: resetsAt));
    return SheetFrame.show<void>(context, builder: (_) => QuoteCalmLimitSheet(limit: limit, resetsAt: resetsAt));
  }
}

class QuoteCalmLimitSheet extends StatelessWidget {
  const QuoteCalmLimitSheet({super.key, required this.limit, this.resetsAt});

  final int limit;
  final DateTime? resetsAt;

  @override
  Widget build(BuildContext context) {
    final r = resetsAt;
    return SheetFrame(
      tone: ListingTone.forest,
      art: ListingArt.calendar,
      title: StayQuoteStrings.allUsed(limit),
      subtitle: r == null ? StayQuoteStrings.calmBodyNoDate(limit) : StayQuoteStrings.calmBody(limit, r.toLocal()),
      footer: PrimaryButton(label: StayQuoteStrings.ok, tone: StayCalKit.green, onPressed: () => Navigator.of(context).pop()),
      child: Padding(
        padding: DS.insets(t: 10, b: 8),
        child: Text(StayQuoteStrings.calmNote, style: QuoteText.hint),
      ),
    );
  }
}
