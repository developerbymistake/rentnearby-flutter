import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../look/owner_look.dart';
import '../strings/owner_shared_strings.dart';
import 'gate_keys.dart';
import 'plan_gate.dart';

class PlanLimitSheet extends StatelessWidget {
  const PlanLimitSheet({super.key, required this.spec});

  final GateSpec spec;

  static Future<void> show(BuildContext context, GateSpec spec) =>
      SheetFrame.show<void>(context, builder: (_) => PlanLimitSheet(spec: spec));

  OwnerLook get _look => spec.taxi ? OwnerLook.taxi : OwnerLook.stay;

  static final KitTone _stayButton = KitTone(
    accent: ListingTone.forest.g1,
    accentDark: ListingTone.forest.g2,
    tint: ListingTone.forest.tint,
    gradient: ListingTone.forest.gradient,
    glow: ListingTone.forest.g2,
  );

  Widget _kv(String label, String value, {String? sub, bool highlight = false}) => Padding(
        padding: DS.sym(v: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Ink3D.text(13, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value,
                      textAlign: TextAlign.end,
                      style: Ink3D.text(13, FontWeight.w700, highlight ? OwnerLook.plus : Ink3D.title, letterSpacing: 0)),
                  if (sub != null) Text(sub, textAlign: TextAlign.end, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: GateKeys.sheet,
      child: SheetFrame(
        tone: _look.tone,
        art: spec.art ?? ListingArt.locked,
        title: spec.title,
        subtitle: spec.body,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              key: GateKeys.seePlus,
              label: OwnerSharedStrings.seePlus,
              tone: spec.taxi ? _look.kit : _stayButton,
              onPressed: () {
                Navigator.of(context).pop();
                PlanGate.seePlus();
              },
            ),
            Gap.v(6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(OwnerSharedStrings.notNow, style: Ink3D.text(14, FontWeight.w600, Ink3D.grey)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap.v(12),
            Container(
              padding: DS.sym(h: 16, v: 4),
              decoration: BoxDecoration(color: OwnerLook.gateBox, borderRadius: DS.br(CardRadius.tile)),
              child: Column(
                children: [
                  for (final r in spec.rows) _kv(r.label, r.value, sub: r.sub, highlight: r.highlight),
                  _kv(OwnerSharedStrings.plusPrice, PlanGate.priceLine(taxi: spec.taxi)),
                ],
              ),
            ),
            if (spec.tip != null) ...[
              Gap.v(12),
              Text(spec.tip!, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, height: 1.45, letterSpacing: 0)),
            ],
            Gap.v(8),
          ],
        ),
      ),
    );
  }
}
