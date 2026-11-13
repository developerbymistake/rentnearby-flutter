import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
import '../models/job_summary_model.dart';
import '../models/my_job_model.dart';
import 'job_list_card.dart';
import 'jobs_ui.dart';

class MyJobCard extends StatelessWidget {
  final MyJobModel job;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final int index;

  const MyJobCard({
    super.key,
    required this.job,
    required this.onTap,
    required this.onClose,
    this.index = 0,
  });

  static Future<bool> confirmClose(BuildContext context) => showJobsConfirm(
        context,
        title: 'Close this job?',
        content: "It will stop showing. You can't reopen it.",
        cancelLabel: 'Cancel',
        confirmLabel: 'Close job',
      );

  @override
  Widget build(BuildContext context) {
    final active = job.isActive;
    const tone = JobsUi.tone;
    return JobListCard(
      tone: JobsLook.card(index),
      title: job.title,
      roleLabel: job.roleName,
      experienceTag: job.experienceLabel,
      metaLine: job.metaLabel,
      salaryLabel: job.salaryLabel,
      salaryShort: jobSalaryCompact(job.minSalary, job.maxSalary),
      salaryUnit: job.salaryUnit,
      badgeLabel: active ? 'ACTIVE' : 'CLOSED',
      dimmed: !active,
      onTap: onTap,
      accent: tone.accent,
      accentDark: tone.accentDark,
      actions: [
        JobListCardAction(icon: Icons.visibility_rounded, label: 'View', color: tone.accentDark, onTap: onTap),
        active
            ? JobListCardAction(icon: Icons.close_rounded, label: 'Close', color: tone.accentDark, onTap: onClose)
            : JobListCardAction(icon: Icons.close_rounded, label: 'Closed', color: tone.accentDark),
      ],
    );
  }
}
