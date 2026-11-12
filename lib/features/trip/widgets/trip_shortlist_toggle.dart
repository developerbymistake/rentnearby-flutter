import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../trip_strings_shortlist.dart';

class TripShortlistToggle extends StatelessWidget {
  const TripShortlistToggle({
    super.key,
    required this.selected,
    required this.onTap,
    this.busy = false,
    this.tone = KitTone.stay,
    this.height = 44,
  });

  final bool selected;
  final bool busy;
  final VoidCallback? onTap;
  final KitTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final action = busy ? null : onTap;
    if (selected) {
      return SecondaryButton(
        label: TripStringsShortlist.shortlisted,
        onPressed: action,
        tone: tone,
        height: height,
        icon: Icon(Icons.check_circle_rounded, size: 18, color: tone.accentDark),
      );
    }
    return PrimaryButton(
      label: TripStringsShortlist.shortlist,
      onPressed: action,
      tone: tone,
      height: height,
      icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: DesignColors.onPrimary),
    );
  }
}
