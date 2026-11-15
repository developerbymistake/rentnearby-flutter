import 'package:flutter/material.dart';
import '../config/module_palette.dart';
import '../design/design.dart';

class NearestControlBar extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCancel;
  final ModulePalette palette;

  const NearestControlBar({
    super.key,
    required this.current,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onCancel,
    this.palette = templateModulePalette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.sym(h: 8, v: 10),
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: DS.circular(16),
        boxShadow: DS.shadows(GateKit.barShadow),
      ),
      child: Row(
        children: [
          _NavButton(
              icon: Icons.chevron_left_rounded,
              label: 'Prev',
              iconLeading: true,
              enabled: current > 0,
              onTap: onPrev),
          Gap.h(6),
          _NavButton(
              icon: Icons.chevron_right_rounded,
              label: 'Next',
              iconLeading: false,
              enabled: current < total - 1,
              onTap: onNext),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(total, (i) {
                  final active = i == current;
                  return AnimatedContainer(
                    duration: templateTransitionDuration,
                    margin: EdgeInsets.symmetric(horizontal: DS.gh(2)),
                    width: DS.s(active ? 16 : 6),
                    height: DS.s(6),
                    decoration: BoxDecoration(
                      gradient: active ? TripEntryStyle.gradient : null,
                      color: active ? null : FitnessAppTheme.spacer,
                      borderRadius: DS.circular(32),
                    ),
                  );
                }),
              ),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Container(
              height: DS.s(36),
              padding: DS.sym(h: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: TripEntryStyle.rose,
                borderRadius: DS.circular(16),
              ),
              child: Text('Cancel',
                  style: FitnessAppTheme.body2.copyWith(
                      fontSize: DS.f(13),
                      fontWeight: FontWeight.w600,
                      color: FitnessAppTheme.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool iconLeading;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.iconLeading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? FitnessAppTheme.white : FitnessAppTheme.deactivatedText;
    final iconWidget = Icon(icon, size: DS.s(18), color: color);
    final textWidget = Text(label,
        style: FitnessAppTheme.body2
            .copyWith(fontSize: DS.f(13), fontWeight: FontWeight.w600, color: color));
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: DS.s(36),
        padding: DS.sym(h: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? TripEntryStyle.gradient : null,
          color: enabled ? null : FitnessAppTheme.spacer,
          borderRadius: DS.circular(16),
          boxShadow: enabled
              ? DS.shadows([
                  ShadowTokens.tint(TravelPalette.skyEnd, ShadowSpec.glowSpec),
                ])
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconLeading
              ? [iconWidget, SizedBox(width: DS.s(3)), textWidget]
              : [textWidget, SizedBox(width: DS.s(3)), iconWidget],
        ),
      ),
    );
  }
}
