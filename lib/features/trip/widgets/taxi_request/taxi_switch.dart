import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import 'taxi_request_look.dart';

class TaxiSwitch extends StatelessWidget {
  const TaxiSwitch({super.key, required this.value, required this.onChanged, this.onGradient = false, this.semanticsLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool onGradient;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final enabled = onChanged != null;
    final Color track;
    final Color thumb;
    if (onGradient) {
      track = value ? DesignColors.surface : DesignColors.tint(DesignColors.surface, Alpha.v40);
      thumb = value ? tone.g2 : DesignColors.surface;
    } else {
      track = value ? tone.g2 : ListingPalette.indigo.line;
      thumb = DesignColors.surface;
    }
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: SizedBox(
            width: DS.s(52),
            height: DS.s(40),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: DS.s(44),
                height: DS.s(24),
                padding: DS.all(2),
                decoration: BoxDecoration(color: track, borderRadius: DS.circular(12)),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: DS.s(20),
                    height: DS.s(20),
                    decoration: BoxDecoration(color: thumb, shape: BoxShape.circle, boxShadow: DS.shadows(TaxiRequestLook.thumb)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
