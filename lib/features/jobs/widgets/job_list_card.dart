import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';

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
    this.metaIcon = Iconsax.location,
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

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: accentDark)),
      );

  Widget _action(JobListCardAction a) => InkWell(
        onTap: a.onTap,
        child: SizedBox(
          height: 36,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(a.icon, size: 14, color: a.color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: a.color)),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final topRight = topRightBadge ??
        (topRightText == null
            ? null
            : Text(topRightText!,
                maxLines: 1,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textHint)));
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: AppShadows.premium(accent, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      ),
                      if (topRight != null) ...[const SizedBox(width: 8), topRight],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(
                      child: Text(roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: accentDark)),
                    ),
                    if (experienceTag.isNotEmpty) ...[const SizedBox(width: 6), _tag(experienceTag)],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (metaIcon != null) ...[
                      Icon(metaIcon, size: 11, color: AppColors.textLight),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: salaryLabel),
                              if (salaryUnit.isNotEmpty)
                                TextSpan(
                                  text: ' $salaryUnit',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textLight),
                                ),
                            ]),
                            maxLines: 1,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold),
                          ),
                        ),
                      ),
                    ),
                    if (trailingChip != null && trailingChip!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 96), child: _tag(trailingChip!)),
                    ],
                  ]),
                ]),
              ),
            ),
            if (actions.isNotEmpty)
              DecoratedBox(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                child: Row(children: [
                  for (final a in actions) Expanded(child: _action(a)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
