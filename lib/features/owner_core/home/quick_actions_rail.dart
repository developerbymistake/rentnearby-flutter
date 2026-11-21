import 'package:flutter/material.dart';

import '../../../design/extra/art_3d.dart';
import '../../../design/extra/meals_card_v.dart';

class QuickAction {
  const QuickAction({required this.art, required this.tone, required this.label, required this.description, required this.onTap, this.add = false});

  final String art;
  final ListingTone tone;
  final String label;
  final String description;
  final VoidCallback? onTap;
  final bool add;
}

class QuickActionsRail extends StatelessWidget {
  const QuickActionsRail({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return MealsRail(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final a in actions)
          MealsCardV(
            tone: a.tone,
            art: a.art,
            title: a.label,
            description: a.description,
            goIcon: a.add ? Icons.add : Icons.arrow_forward,
            onTap: a.onTap,
            semanticsLabel: a.label,
          ),
      ],
    );
  }
}
