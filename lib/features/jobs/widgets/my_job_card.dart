import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/my_job_model.dart';
import 'job_list_card.dart';
import 'jobs_ui.dart';

class MyJobCard extends StatelessWidget {
  final MyJobModel job;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const MyJobCard({
    super.key,
    required this.job,
    required this.onTap,
    required this.onClose,
  });

  static Future<bool> confirmClose(BuildContext context) => showJobsConfirm(
        context,
        title: 'Close this job?',
        content: "It will stop showing. You can't reopen it.",
        cancelLabel: 'Cancel',
        confirmLabel: 'Close job',
      );

  @override
  Widget build(BuildContext context) {
    final active = job.isActive;
    const tone = JobsUi.tone;
    return JobListCard(
      title: job.title,
      roleLabel: job.roleName,
      experienceTag: job.experienceLabel,
      metaLine: job.metaLabel,
      metaIcon: null,
      salaryLabel: job.salaryLabel,
      salaryUnit: job.salaryUnit,
      topRightBadge: active
          ? const KitTagChip('ACTIVE', color: DesignColors.primary)
          : const KitTagChip('CLOSED', color: DesignColors.textGrey),
      dimmed: !active,
      onTap: onTap,
      accent: tone.accent,
      accentDark: tone.accentDark,
      actions: [
        JobListCardAction(icon: Icons.visibility_outlined, label: 'View', color: tone.accentDark, onTap: onTap),
        active
            ? JobListCardAction(icon: Icons.close_rounded, label: 'Close', color: DesignColors.error, onTap: onClose)
            : const JobListCardAction(icon: Icons.close_rounded, label: 'Closed', color: DesignColors.textMuted),
      ],
    );
  }
}
