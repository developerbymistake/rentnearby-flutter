import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/money_format.dart';
import '../calendar/models/calendar_models.dart';
import '../look/owner_look.dart';
import '../plan/gate_keys.dart';
import '../plan/plan_gate.dart';
import '../plan/soft_lock.dart';

class MoneySummaryWords {
  const MoneySummaryWords({
    required this.title,
    required this.sub,
    required this.booked,
    required this.received,
    required this.toCollect,
    required this.lockedLine,
    required this.hiddenAmount,
  });

  final String title;
  final String sub;
  final String booked;
  final String received;
  final String toCollect;
  final String lockedLine;
  final String hiddenAmount;
}

class MoneySummaryCard extends StatelessWidget {
  const MoneySummaryCard({super.key, required this.words, required this.look, this.summary, required this.allowed, this.onOpen, this.taxi = false});

  final MoneySummaryWords words;
  final OwnerLook look;
  final MoneySummary? summary;
  final bool allowed;
  final VoidCallback? onOpen;
  final bool taxi;

  @override
  Widget build(BuildContext context) {
    final locked = !allowed && PlanGate.canUpgrade;
    final s = summary;
    String amount(int? v) => locked || v == null ? words.hiddenAmount : Money.exact(v);
    final card = Container(
      key: locked ? GateKeys.softCard : null,
      padding: DS.all(16),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.hero), boxShadow: DS.shadows(ShadowTokens.elev1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Art3D(asset: ListingArt.moneyBag, size: 32),
              Gap.h(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(words.title, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                    Text(words.sub, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
              if (locked) SeePlusButton(taxi: taxi),
            ],
          ),
          Gap.v(12),
          Row(
            children: [
              Expanded(child: _Cell(label: words.booked, value: amount(s?.booked))),
              Expanded(child: _Cell(label: words.received, value: amount(s?.received))),
              Expanded(child: _Cell(label: words.toCollect, value: amount(s?.toCollect))),
            ],
          ),
          if (locked) ...[
            Gap.v(10),
            Text(words.lockedLine, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0)),
          ],
        ],
      ),
    );
    if (locked || onOpen == null) return card;
    return InkWell(onTap: onOpen, borderRadius: DS.br(CardRadius.hero), child: card);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          ),
        ],
      );
}
