import 'package:flutter/material.dart';
import '../../../design/design.dart';

class DashedAddRow extends StatelessWidget {
  final String label;
  final String counter;
  final bool enabled;
  final VoidCallback onTap;
  final Color accent;

  const DashedAddRow({
    super.key,
    required this.label,
    required this.counter,
    required this.enabled,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final radius = DS.br(TripKit.cardRadiusSmall);
    return PressScale(
      enabled: enabled,
      child: Container(
        decoration: BoxDecoration(
            color: enabled ? DesignColors.surface : DesignColors.surfaceMuted,
            borderRadius: radius,
            boxShadow: enabled ? DS.shadows(ShadowTokens.elev1) : const []),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(48)),
              child: Padding(
                padding: DS.insets(l: 12, t: 10, r: 16, b: 10),
                child: Row(children: [
                  Container(
                    width: DS.s(36),
                    height: DS.s(36),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: enabled ? PickKit.stayGradient : null,
                      color: enabled ? null : DesignColors.textMuted,
                      boxShadow: enabled ? DS.shadows(ShadowTokens.elev1) : const [],
                    ),
                    child: Icon(Icons.add_rounded, size: DS.s(20), color: DesignColors.onPrimary),
                  ),
                  Gap.h(12),
                  Expanded(
                    child: Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(14, color: enabled ? DesignColors.primary : DesignColors.textMuted).copyWith(letterSpacing: 0.2)),
                  ),
                  Gap.h(8),
                  Flexible(
                    child: Text(counter,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TripKit.text(11, color: TypeTokens.secondary)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
