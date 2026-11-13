import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';

import 'plan_compare_table.dart';

class PlanCycleOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? price;
  final String? perMonth;
  final bool best;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final String? unavailableText;
  final VoidCallback? onRetry;
  final int index;
  final String? featureKey;

  const PlanCycleOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.perMonth,
    required this.best,
    required this.selected,
    required this.onTap,
    required this.accent,
    this.unavailableText,
    this.onRetry,
    this.index = 0,
    this.featureKey,
  });

  static String artFor(int index) => [ListingArt.calendar, ListingArt.moneyBag, ListingArt.star][index % 3];

  String? get _key {
    if (featureKey != null) return featureKey;
    if (accent == PlanAccent.of('Taxi')) return 'Taxi';
    return 'Stay';
  }

  @override
  Widget build(BuildContext context) {
    return PlanCycleCard3D(
      tone: PlanLook.cycleTone(_key, index),
      art: artFor(index),
      title: title,
      subtitle: subtitle,
      price: price,
      perMonth: perMonth,
      best: best,
      selected: selected,
      onTap: onTap,
      unavailableText: unavailableText,
      onRetry: onRetry,
      subtitleLoading: price == null && unavailableText == null && subtitle.isEmpty,
    );
  }
}
