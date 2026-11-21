import 'package:flutter/material.dart';

import '../../../design/design.dart';
import 'models/calendar_models.dart';

abstract final class MeterText {
  static String count(Meter m) => '${m.used} of ${m.limit}';
}

class MeterTile extends StatelessWidget {
  const MeterTile({super.key, required this.meter, required this.label});

  final Meter meter;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.sym(h: 14, v: 10),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(CardRadius.hero),
        boxShadow: DS.shadows(ShadowTokens.elev1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(MeterText.count(meter), style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
        ],
      ),
    );
  }
}

class MeterRow extends StatelessWidget {
  const MeterRow({super.key, required this.meters, required this.labelOf});

  final List<Meter> meters;
  final String Function(String key) labelOf;

  @override
  Widget build(BuildContext context) {
    if (meters.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < meters.length; i++) ...[
          if (i > 0) Gap.h(10),
          Expanded(child: MeterTile(meter: meters[i], label: labelOf(meters[i].key))),
        ],
      ],
    );
  }
}
