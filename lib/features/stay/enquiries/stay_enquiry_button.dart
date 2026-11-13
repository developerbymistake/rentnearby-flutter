import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

enum StayEnquiryButtonKind { primary, positive, negative, plain }

class StayEnquiryButton extends StatelessWidget {
  const StayEnquiryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = StayEnquiryButtonKind.plain,
    this.icon,
    this.iconAsset,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final StayEnquiryButtonKind kind;
  final IconData? icon;
  final String? iconAsset;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tone = kind == StayEnquiryButtonKind.positive ? ListingTone.indigo : ListingTone.forest;
    final tap = busy ? null : onTap;
    return switch (kind) {
      StayEnquiryButtonKind.primary || StayEnquiryButtonKind.positive =>
        GradientPillButton(tone: tone, label: label, icon: icon, onTap: tap, loading: busy, height: 44, fontSize: 14, expand: false),
      StayEnquiryButtonKind.negative => WhitePillButton(tone: tone, label: label, icon: icon, onTap: tap, danger: true, height: 44, fontSize: 14, expand: false),
      StayEnquiryButtonKind.plain => WhitePillButton(tone: tone, label: label, icon: icon, onTap: tap, height: 44, fontSize: 14, expand: false),
    };
  }
}
