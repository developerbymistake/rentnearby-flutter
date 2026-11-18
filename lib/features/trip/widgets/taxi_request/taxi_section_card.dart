import 'package:bakhli/design/design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TaxiSectionCard extends StatelessWidget {
  const TaxiSectionCard({
    super.key,
    required this.art,
    required this.title,
    required this.sub,
    required this.child,
    this.number,
    this.on = true,
    this.onChanged,
    this.switchKey,
  });

  final String art;
  final String title;
  final String sub;
  final Widget child;
  final int? number;
  final bool on;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final open = on || onChanged == null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DS.br(CardRadius.hero),
        boxShadow: DS.shadows(Ink3D.softShadow),
      ),
      child: ClipRRect(
        borderRadius: DS.br(CardRadius.hero),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(gradient: tone.gradient),
              padding: DS.sym(h: 14, v: 12),
              child: Row(
                children: [
                  if (number != null) ...[
                    Container(
                      width: DS.s(28),
                      height: DS.s(28),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Text('$number', style: Ink3D.text(12, FontWeight.w700, tone.text)),
                    ),
                    Gap.h(10),
                  ],
                  Art3D(asset: art, size: 40, shadowBlur: 4, shadowOffset: const Offset(2, 3)),
                  Gap.h(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, DesignColors.textInverse)),
                        Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, DesignColors.textInverse)),
                      ],
                    ),
                  ),
                  if (onChanged != null) ...[
                    Gap.h(8),
                    Semantics(
                      toggled: on,
                      label: title,
                      child: CupertinoSwitch(
                        key: switchKey,
                        value: on,
                        onChanged: onChanged,
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: DesignColors.whiteSoft,
                        thumbColor: on ? tone.text : Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (open) Padding(padding: DS.sym(h: 14, v: 14), child: child),
          ],
        ),
      ),
    );
  }
}
