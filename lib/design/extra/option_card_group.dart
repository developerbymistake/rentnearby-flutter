import 'package:flutter/material.dart';
import 'art_3d.dart';
import 'guide_kit_3d.dart';

class OptionChoice<T> {
  const OptionChoice({required this.value, required this.label, required this.art, required this.tone});

  final T value;
  final String label;
  final String art;
  final ListingTone tone;
}

// The coloured choice cards of the old trip question page, kept as a reusable picker.
class OptionCardGroup<T> extends StatelessWidget {
  const OptionCardGroup({super.key, required this.options, required this.selected, required this.onPick});

  final List<OptionChoice<T>> options;
  final T? selected;
  final ValueChanged<T>? onPick;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            Semantics(
              button: true,
              selected: selected == o.value,
              label: o.label,
              excludeSemantics: true,
              child: OptionCard(
                key: ValueKey('option_card_${o.value}'),
                tone: o.tone,
                art: o.art,
                label: o.label,
                state: selected == o.value
                    ? OptionState.on
                    : selected != null
                        ? OptionState.off
                        : OptionState.idle,
                onTap: onPick == null ? null : () => onPick!(o.value),
              ),
            ),
        ],
      );
}
