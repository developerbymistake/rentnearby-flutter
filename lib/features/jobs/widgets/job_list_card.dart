import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'jobs_ui.dart';

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
    this.metaIcon = Icons.place_outlined,
    required this.salaryLabel,
    this.salaryUnit = '',
    this.topRightText,
    this.topRightBadge,
    this.trailingChip,
    this.dimmed = false,
    this.onTap,
    this.actions = const [],
    required this.accent,
    required this.accentDark,
  });

  final String title;
  final String roleLabel;
  final String experienceTag;
  final String metaLine;
  final IconData? metaIcon;
  final String salaryLabel;
  final String salaryUnit;
  final String? topRightText;
  final Widget? topRightBadge;
  final String? trailingChip;
  final bool dimmed;
  final VoidCallback? onTap;
  final List<JobListCardAction> actions;
  final Color accent;
  final Color accentDark;

  Widget _action(JobListCardAction a) => InkWell(
        onTap: a.onTap,
        splashColor: DesignColors.tint(a.color, Alpha.soft),
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: KitMetrics.touch,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(a.icon, size: 18, color: a.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(12, FontWeight.w700, color: a.color, letterSpacing: 0.27)),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const tone = JobsUi.tone;
    final moneyColor = dimmed ? DesignColors.textMuted : DesignColors.gold;
    final topRight = topRightBadge ??
        (topRightText == null ? null : Text(topRightText!, maxLines: 1, style: TypeTokens.caption));
    return ListRow(
      title: title,
      tone: tone,
      dimmed: dimmed,
      onTap: onTap,
      showChevron: false,
      leading: JobsAvatar(
        seed: roleLabel.isEmpty ? title : roleLabel,
        initial: JobsUi.initialOf(roleLabel, title),
        dimmed: dimmed,
      ),
      trailing: topRight,
      trailingTop: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(12, FontWeight.w600,
                      color: dimmed ? DesignColors.textMuted : tone.accentDark)),
            ),
            if (experienceTag.isNotEmpty) KitTagChip(experienceTag, tone: tone),
          ],
        ),
        if (metaIcon != null || metaLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            if (metaIcon != null) ...[
              Icon(metaIcon, size: 14, color: DesignColors.textGrey),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(metaLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption)),
          ]),
        ],
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: salaryLabel),
                    if (salaryUnit.isNotEmpty) TextSpan(text: ' $salaryUnit', style: TypeTokens.caption),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(15, FontWeight.w800, color: moneyColor),
                ),
              ),
              if (trailingChip != null && trailingChip!.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: KitTagChip(trailingChip!, tone: tone, color: dimmed ? DesignColors.textMuted : null),
                ),
            ],
          ),
        ),
      ]),
      footer: actions.isEmpty ? null : Row(children: [for (final a in actions) Expanded(child: _action(a))]),
    );
  }
}
