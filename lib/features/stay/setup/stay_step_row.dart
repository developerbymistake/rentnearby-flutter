import 'package:flutter/material.dart';
import '../../../design/design.dart';

enum StayStepState { locked, current, done }

class StayStepRow extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final StayStepState state;
  final VoidCallback? onTap;
  final Color accent;
  final IconData? icon;
  final String? trailing;
  final String? asset;
  final LinearGradient gradient;
  final ListingTone? tone;
  final String? eyebrow;
  final bool subtitleBad;

  const StayStepRow({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.onTap,
    required this.accent,
    this.icon,
    this.trailing,
    this.asset,
    this.gradient = SetupKit.sky,
    this.tone,
    this.eyebrow,
    this.subtitleBad = false,
  });

  bool get _optional => icon != null;

  ListingTone get _tone => tone ?? (accent == PickKit.taxi ? ListingTone.coral : ListingTone.forest);

  @override
  Widget build(BuildContext context) {
    final StepCardState s;
    final String label;
    if (_optional) {
      s = state == StayStepState.done ? StepCardState.done : StepCardState.current;
      label = '${trailing ?? 'Add'} ›';
    } else {
      s = switch (state) {
        StayStepState.locked => StepCardState.locked,
        StayStepState.current => StepCardState.current,
        StayStepState.done => StepCardState.done,
      };
      label = switch (state) {
        StayStepState.done => 'Edit',
        StayStepState.current => 'Start ›',
        StayStepState.locked => 'Locked',
      };
    }
    return StepCard3D(
      tone: _tone,
      art: asset ?? SetupAssets.hotel,
      eyebrow: eyebrow ?? (number > 0 ? 'Step $number' : null),
      title: title,
      subtitle: subtitle,
      subtitleBad: subtitleBad,
      trailingLabel: label,
      state: s,
      onTap: s == StepCardState.locked ? null : onTap,
    );
  }
}
