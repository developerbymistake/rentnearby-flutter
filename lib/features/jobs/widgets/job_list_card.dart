import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';

class JobListCardAction {
  const JobListCardAction({required this.icon, required this.label, required this.color, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
}

class JobListCard extends StatelessWidget {
  const JobListCard({
    super.key,
    required this.title,
    required this.roleLabel,
    required this.experienceTag,
    required this.metaLine,
    required this.salaryLabel,
    this.salaryUnit = '',
    this.topRightText,
    this.trailingChip,
    this.dimmed = false,
    this.onTap,
    this.actions = const [],
    required this.accent,
    required this.accentDark,
    this.tone,
    this.label,
    this.labelNote,
    this.badgeLabel,
    this.salaryShort,
  });

  final String title;
  final String roleLabel;
  final String experienceTag;
  final String metaLine;
  final String salaryLabel;
  final String salaryUnit;
  final String? topRightText;
  final String? trailingChip;
  final bool dimmed;
  final VoidCallback? onTap;
  final List<JobListCardAction> actions;
  final Color accent;
  final Color accentDark;
  final ListingTone? tone;
  final String? label;
  final String? labelNote;
  final String? badgeLabel;
  final String? salaryShort;

  @override
  Widget build(BuildContext context) {
    final t = dimmed ? JobsLook.closed : (tone ?? JobsLook.card(0));
    final chip = trailingChip;
    final short = salaryShort;
    final salary = short != null && MediaQuery.sizeOf(context).width < 340 ? short : salaryLabel;
    return WideCard(
      tone: t,
      art: ListingArt.luggage,
      tag: roleLabel,
      badge: badgeLabel ?? topRightText,
      badgeSolid: true,
      title: title,
      subtitle: metaLine,
      chips: [if (experienceTag.isNotEmpty) experienceTag, if (chip != null && chip.isNotEmpty) chip],
      number: salary,
      unit: salaryUnit,
      label: label,
      labelNote: labelNote,
      onGo: actions.isEmpty ? onTap : null,
      actions: [for (final a in actions) WideAction(icon: a.icon, label: a.label, onTap: a.onTap)],
      onTap: onTap,
    );
  }
}
