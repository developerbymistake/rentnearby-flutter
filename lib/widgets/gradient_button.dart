import 'package:flutter/material.dart';
import '../design/design.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final double height;
  final Gradient gradient;
  final Color shadowColor;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.height = 52,
    this.gradient = TripEntryStyle.gradient,
    this.shadowColor = TravelPalette.skyEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GradientPillButton(
      tone: ListingTone.indigo,
      label: label,
      onTap: onPressed,
      loading: isLoading,
      danger: identical(gradient, TripEntryStyle.rose),
      height: height,
    );
  }
}
