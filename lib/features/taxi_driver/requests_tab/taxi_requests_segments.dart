import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../strings/taxi_work_strings.dart';

class TaxiRequestsSegments extends StatelessWidget {
  const TaxiRequestsSegments({super.key, required this.selected, required this.leadsBadge, required this.onSelect});

  final int selected;
  final int leadsBadge;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('requests_segments'),
      padding: DS.all(4),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(24), boxShadow: DS.shadows(Ink3D.whiteBtn)),
      child: Row(
        children: [
          Expanded(child: _Segment(label: TaxiWorkStrings.requests, on: selected == 0, onTap: () => onSelect(0))),
          Expanded(child: _Segment(label: TaxiWorkStrings.tripLeads, on: selected == 1, badge: leadsBadge, onTap: () => onSelect(1))),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.on, required this.onTap, this.badge = 0});

  final String label;
  final bool on;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.coral;
    return Tap3D(
      onTap: onTap,
      label: badge > 0 ? '$label, $badge' : label,
      selected: on,
      exclude: true,
      child: Container(
        height: DS.s(36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: on ? tone.gradient : null,
          borderRadius: DS.circular(18),
          boxShadow: on ? DS.shadows(Form3D.glow(tone)) : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, on ? Colors.white : Ink3D.title, letterSpacing: 0)),
              if (badge > 0) ...[
                Gap.h(6),
                Container(
                  key: const ValueKey('requests_leads_badge'),
                  constraints: BoxConstraints(minWidth: DS.s(18)),
                  height: DS.s(18),
                  padding: DS.sym(h: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: on ? Colors.white : DesignColors.error, borderRadius: DS.circular(9)),
                  child: Text('$badge',
                      style: Ink3D.text(10.5, FontWeight.w700, on ? DesignColors.error : Colors.white, letterSpacing: 0)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
