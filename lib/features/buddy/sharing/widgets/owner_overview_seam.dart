import 'package:flutter/widgets.dart';

import '../../../trip/models/trip_model.dart';

class OverviewMenuItem {
  const OverviewMenuItem({required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class OwnerOverviewExtras {
  const OwnerOverviewExtras({
    this.subtitle,
    this.travellerCount,
    this.extraCards = const [],
    this.extraMenuItems = const [],
    this.compactCards = false,
    this.progressLine,
    this.showProgress = true,
  });

  static const OwnerOverviewExtras none = OwnerOverviewExtras();

  final String? subtitle;
  final int? travellerCount;
  final List<Widget> extraCards;
  final List<OverviewMenuItem> extraMenuItems;
  final bool compactCards;
  final String? progressLine;
  final bool showProgress;
}

abstract final class OwnerOverviewSeam {
  static OwnerOverviewExtras of(BuildContext context, TripModel trip) => OwnerOverviewExtras.none;
}
