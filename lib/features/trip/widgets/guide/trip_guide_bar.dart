import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';

class TripGuideBar extends StatelessWidget {
  const TripGuideBar({
    super.key,
    required this.canNext,
    required this.onPrevious,
    required this.primaryLabel,
    required this.onPrimary,
    this.loading = false,
    this.why = '',
    this.tone,
  });

  final bool canNext;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool loading;
  final VoidCallback onPrevious;
  final String why;
  final ListingTone? tone;

  @override
  Widget build(BuildContext context) => GuideButtons(
        tone: tone ?? ListingTone.indigo,
        primaryLabel: primaryLabel,
        onPrimary: onPrimary,
        loading: loading,
        enabled: loading || onPrimary != null,
        onSquare: onPrevious,
        squareIcon: Icons.chevron_left_rounded,
        squareSemantics: TripStringsGuide.previous,
        why: why,
      );
}
