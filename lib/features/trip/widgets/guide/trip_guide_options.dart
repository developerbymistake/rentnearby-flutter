import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../models/trip_plan_model.dart';
import '../../trip_strings_guide.dart';

class TripGuideOption extends StatelessWidget {
  const TripGuideOption({
    super.key,
    required this.label,
    required this.art,
    required this.tone,
    required this.selected,
    required this.onTap,
    this.anyChosen = false,
  });

  final String label;
  final String art;
  final ListingTone tone;
  final bool selected;
  final bool anyChosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: OptionCard(
          tone: tone,
          art: art,
          label: label,
          state: selected
              ? OptionState.on
              : anyChosen
                  ? OptionState.off
                  : OptionState.idle,
          onTap: onTap,
        ),
      );
}

class TripGuideOptions extends StatelessWidget {
  const TripGuideOptions({super.key, required this.choice, required this.onPick, this.skipNote = false});

  final TripGuideChoice? choice;
  final ValueChanged<TripGuideChoice> onPick;
  final bool skipNote;

  @override
  Widget build(BuildContext context) {
    Widget opt(TripGuideChoice c, String label, String art, ListingTone tone) => TripGuideOption(
          label: label,
          art: art,
          tone: tone,
          selected: choice == c,
          anyChosen: choice != null,
          onTap: () => onPick(c),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        opt(TripGuideChoice.find, TripStringsGuide.optFind, ListingArt.compass, ListingTone.cB),
        opt(TripGuideChoice.own, TripStringsGuide.optOwn, ListingArt.backpack, ListingTone.cA),
        opt(TripGuideChoice.skip, TripStringsGuide.optSkip, ListingArt.airplane, ListingTone.cC),
      ],
    );
  }
}
