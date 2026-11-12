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
    const radius = TripKit.cardRadiusSmall;
    return PressScale(
      enabled: enabled,
      child: Container(
        decoration: BoxDecoration(
            color: enabled ? DesignColors.surface : DesignColors.surfaceMuted,
            borderRadius: radius,
            boxShadow: enabled ? ShadowTokens.elev1 : const []),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: enabled ? PickKit.stayGradient : null,
                      color: enabled ? null : DesignColors.textMuted,
                      boxShadow: enabled ? ShadowTokens.elev1 : const [],
                    ),
                    child: const Icon(Icons.add_rounded, size: 20, color: DesignColors.onPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(14, color: enabled ? DesignColors.primary : DesignColors.textMuted).copyWith(letterSpacing: 0.2)),
                  ),
                  const SizedBox(width: 8),
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
