import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../models/trip_plan_model.dart';
import '../../trip_strings_guide.dart';
import '../trip_ui.dart';

class TripGuideOption extends StatelessWidget {
  const TripGuideOption({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const tone = KitTone.trip;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: TripSurface(
        onTap: onTap,
        color: selected ? tone.tint : DesignColors.surface,
        borderColor: selected ? tone.accentDark : DesignColors.borderSoft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KitMetrics.touch),
          child: Row(
            children: [
              Icon(icon, size: 22, color: tone.accentDark),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TypeTokens.style(14, selected ? FontWeight.w700 : FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              _Radio(on: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: on ? KitTone.trip.accentDark : DesignColors.borderStrong, width: 2),
        ),
        child: on
            ? const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.lunchEnd),
                  child: SizedBox(width: 10, height: 10),
                ),
              )
            : null,
      );
}

class TripGuideOptions extends StatelessWidget {
  const TripGuideOptions({super.key, required this.choice, required this.onPick, this.skipNote = false});

  final TripGuideChoice? choice;
  final ValueChanged<TripGuideChoice> onPick;
  final bool skipNote;

  @override
  Widget build(BuildContext context) {
    Widget opt(TripGuideChoice c, String label, IconData icon) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TripGuideOption(label: label, icon: icon, selected: choice == c, onTap: () => onPick(c)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        opt(TripGuideChoice.find, TripStringsGuide.optFind, Icons.search_rounded),
        opt(TripGuideChoice.own, TripStringsGuide.optOwn, Icons.person_outline_rounded),
        opt(TripGuideChoice.skip, TripStringsGuide.optSkip, Icons.skip_next_rounded),
        if (skipNote && choice == TripGuideChoice.skip)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(TripStringsGuide.noTaxiNote, textAlign: TextAlign.center, style: TypeTokens.caption),
          ),
      ],
    );
  }
}
